"""Background Gmail cleanup via IMAP — safe trash only (no permanent delete).

Stdlib only (imaplib + email). No GCP project, no Gmail API.
Defaults to dry-run; --execute requires --confirm-yes.
"""
import argparse
import email
import email.header
import imaplib
import json
import os
import sys
import time
from datetime import datetime, timezone

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

HOST = "imap.gmail.com"
PORT = 993
MAILBOX = "INBOX"
LOG_PATH = "imap_trash_log.jsonl"

QUERIES = {
    "promos": "category:promotions older_than:30d -is:starred -is:important",
    "social": "category:social older_than:30d -is:starred -is:important",
    "updates_auto": "category:updates older_than:90d -is:starred -is:important",
}

TRASH_CANDIDATES = ("[Gmail]/Trash", "[Gmail]/\ud734\uc9c0\ud1b5", "[Google Mail]/Trash")


def load_dotenv(path):
    """Parse KEY=VALUE lines (ignore comments/blanks) into os.environ without overwriting."""
    try:
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, _, value = line.partition("=")
                key = key.strip()
                value = value.strip().strip("'").strip('"')
                if key and key not in os.environ:
                    os.environ[key] = value
    except FileNotFoundError:
        pass


def get_creds():
    here = os.path.dirname(os.path.abspath(__file__))
    load_dotenv(os.path.join(here, ".env"))
    user = os.environ.get("GMAIL_ADDRESS", "").strip()
    password = os.environ.get("GMAIL_APP_PASSWORD", "").strip().replace(" ", "")
    if len(password) != 16:
        alt = os.environ.get("Python-IMAP", "").strip().replace(" ", "")
        if len(alt) == 16:
            password = alt
    if not user or not password:
        print(
            "ERROR: Missing GMAIL_ADDRESS and/or GMAIL_APP_PASSWORD. "
            "Set them as env vars or in .env (same dir as this script).",
            file=sys.stderr,
        )
        sys.exit(2)
    return user, password


def decode_header_value(raw):
    try:
        parts = email.header.decode_header(raw)
        out = []
        for text, charset in parts:
            if isinstance(text, bytes):
                out.append(text.decode(charset or "utf-8", errors="replace"))
            else:
                out.append(text)
        return "".join(out)
    except Exception:
        return raw


def search_uids(mail, query):
    """Search via X-GM-RAW; on failure abort that query (never trash blindly)."""
    try:
        typ, data = mail.uid("search", None, "X-GM-RAW", '"%s"' % query)
    except (imaplib.IMAP4.error, OSError) as e:
        print("  [abort-query] X-GM-RAW failed for query: %s" % e)
        return None
    if typ != "OK":
        print("  [abort-query] X-GM-RAW search not OK (aborting this query).")
        return None
    raw = data[0] if data else b""
    if isinstance(raw, bytes):
        raw = raw.decode("ascii", errors="ignore")
    return raw.split() if raw.strip() else []


def get_flags(mail, uid):
    typ, data = mail.uid("fetch", uid, "(FLAGS)")
    if typ != "OK" or not data or data[0] is None:
        return set()
    raw = data[0]
    if isinstance(raw, bytes):
        raw = raw.decode("utf-8", errors="ignore")
    else:
        raw = str(raw)
    flags = set()
    start = raw.find("(")
    end = raw.find(")", start)
    if start != -1 and end != -1:
        for tok in raw[start + 1:end].split():
            flags.add(tok)
    return flags


def get_sample(mail, uid):
    try:
        typ, data = mail.uid(
            "fetch", uid, "(BODY.PEEK[HEADER.FIELDS (FROM SUBJECT DATE)])"
        )
        if typ != "OK" or not data or data[0] is None:
            return "(unavailable)"
        payload = data[0]
        raw_bytes = payload[1] if isinstance(payload, tuple) else payload
        if isinstance(raw_bytes, bytes):
            msg = email.message_from_bytes(raw_bytes)
        else:
            msg = email.message_from_string(str(raw_bytes))
        subj = msg.get("Subject", "(no subject)")
        frm = msg.get("From", "?")
        date = msg.get("Date", "?")
        return "%s | %s | %s" % (decode_header_value(subj), frm, date)
    except Exception:
        return "(unavailable)"


def find_trash(mail):
    try:
        typ, data = mail.list()
        if typ != "OK" or not data:
            return None
        for row in data:
            if isinstance(row, bytes):
                s = row.decode("utf-8", errors="replace")
            else:
                s = str(row)
            if "\\Trash" in s:
                parts = s.split('"')
                if len(parts) >= 3:
                    return parts[-2]
    except Exception:
        return None
    return None


def move_to_trash(mail, uid, trash_cache={}):
    last_err = None
    dests = []
    found = trash_cache.get("dest")
    if found is None:
        found = find_trash(mail)
        trash_cache["dest"] = found
    if found:
        dests.append(found)
    for d in TRASH_CANDIDATES:
        if d not in dests:
            dests.append(d)
    for dest in dests:
        try:
            typ, _ = mail.uid("copy", uid, dest)
            if typ == "OK":
                return dest
            last_err = "copy -> %s: %s" % (dest, typ)
        except Exception as e:
            last_err = "copy -> %s: %s" % (dest, e)
    try:
        typ, _ = mail.uid("store", uid, "+X-GM-LABELS", "(\\Trash)")
        if typ == "OK":
            return "X-GM-LABELS-\\Trash"
        last_err = "x-gm-labels: %s" % (typ,)
    except Exception as e:
        last_err = "x-gm-labels: %s" % (e,)
    print("  [skip] %s: no Trash mailbox worked (%s)" % (uid, last_err))
    return None


def connect_with_retry(host=HOST, port=PORT, attempts=5):
    last = None
    for i in range(attempts):
        try:
            return imaplib.IMAP4_SSL(host, port)
        except (imaplib.IMAP4.error, OSError, EOFError) as e:
            last = e
            time.sleep(2 ** i)
    raise last


def main():
    parser = argparse.ArgumentParser(
        description="Safe Gmail IMAP trash cleanup (no permanent delete)."
    )
    parser.add_argument("--dry-run", action="store_true",
                        help="Count + sample only (default).")
    parser.add_argument("--execute", action="store_true",
                        help="Actually move messages to Trash.")
    parser.add_argument("--confirm-yes", action="store_true",
                        help="Required with --execute.")
    args = parser.parse_args()

    if args.execute and not args.confirm_yes:
        parser.error("--execute requires --confirm-yes (aborting for safety).")
    do_execute = bool(args.execute)

    user, password = get_creds()

    mail = connect_with_retry()
    try:
        mail.login(user, password)
    except imaplib.IMAP4.error as e:
        print("ERROR: IMAP login failed: %s" % e, file=sys.stderr)
        sys.exit(1)
    typ, _ = mail.select(MAILBOX)
    if typ != "OK":
        print("ERROR: Cannot select %s" % MAILBOX, file=sys.stderr)
        try:
            mail.logout()
        except Exception:
            pass
        sys.exit(1)

    seen = set()
    total_found = 0
    total_trashed = 0
    total_skipped = 0

    for name, query in QUERIES.items():
        uids = search_uids(mail, query)
        if uids is None:
            continue  # aborted query, do not trash blindly
        fresh = [u for u in uids if u not in seen]
        for u in fresh:
            seen.add(u)
        total_found += len(fresh)
        print("[%s] candidates: %d" % (name, len(fresh)))

        if not do_execute:
            for uid in fresh[:5]:
                print("  sample %s: %s" % (uid, get_sample(mail, uid)))
            continue

        trashed = 0
        skipped = 0
        with open(LOG_PATH, "a", encoding="utf-8") as log:
            for uid in fresh:
                try:
                    flags = get_flags(mail, uid)
                except (imaplib.IMAP4.error, OSError) as e:
                    print("  [skip] flag-check %s: %s" % (uid, e))
                    skipped += 1
                    continue
                if "\\Starred" in flags or "\\Important" in flags:
                    skipped += 1
                    continue
                # Recovery log BEFORE mutate.
                log.write(json.dumps({
                    "uid": uid,
                    "query": name,
                    "ts": datetime.now(timezone.utc).isoformat(),
                }) + "\n")
                log.flush()
                dest = move_to_trash(mail, uid)
                if dest is None:
                    skipped += 1
                    continue
                try:
                    mail.uid("store", uid, "+FLAGS", "(\\Deleted)")
                except (imaplib.IMAP4.error, OSError) as e:
                    print("  [skip] store Deleted %s: %s" % (uid, e))
                    skipped += 1
                    continue
                trashed += 1
                time.sleep(0.05)
        try:
            mail.expunge()  # selected mailbox (INBOX) ONLY
        except (imaplib.IMAP4.error, OSError) as e:
            print("  [warn] expunge failed: %s" % e)
        total_trashed += trashed
        total_skipped += skipped
        print("[%s] trashed: %d, skipped: %d" % (name, trashed, skipped))

    try:
        mail.close()
    except Exception:
        pass
    try:
        mail.logout()
    except Exception:
        pass

    print("SUMMARY found=%d trashed=%d skipped=%d"
          % (total_found, total_trashed, total_skipped))
    if not do_execute:
        print("Dry run only \u2014 no messages trashed. "
              "Use --execute --confirm-yes to trash.")


if __name__ == "__main__":
    main()

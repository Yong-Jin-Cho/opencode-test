"""Background Gmail cleanup script — safe trash only (no permanent delete)."""
import argparse
import json
import time
from datetime import datetime, timezone

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

SCOPES = ["https://www.googleapis.com/auth/gmail.modify"]

QUERIES = {
    "promos": "category:promotions older_than:30d -is:starred -is:important -in:spam -in:trash in:inbox",
    "social": "category:social older_than:30d -is:starred -is:important -in:spam -in:trash in:inbox",
    "updates_auto": "category:updates older_than:90d -is:starred -is:important -in:spam -in:trash in:inbox",
}

RETRY_STATUS = {403, 429, 500, 502, 503, 504}
LOG_PATH = "trash_log.jsonl"


def get_service():
    creds = None
    try:
        with open("token.json", "r", encoding="utf-8") as f:
            creds = Credentials.from_authorized_user_info(json.load(f), SCOPES)
    except FileNotFoundError:
        creds = None
    if creds and creds.expired and creds.refresh_token:
        creds.refresh(Request())
    if not creds or not creds.valid:
        flow = InstalledAppFlow.from_client_secrets_file("credentials.json", SCOPES)
        creds = flow.run_local_server(port=0)
        with open("token.json", "w", encoding="utf-8") as f:
            f.write(creds.to_json())
    return build("gmail", "v1", credentials=creds)


def list_all_ids(service, query):
    ids = []
    page_token = None
    while True:
        kwargs = {
            "userId": "me",
            "q": query,
            "maxResults": 500,
            "includeSpamTrash": False,
        }
        if page_token:
            kwargs["pageToken"] = page_token
        resp = service.users().messages().list(**kwargs).execute()
        for m in resp.get("messages", []):
            ids.append(m["id"])
        page_token = resp.get("nextPageToken")
        if not page_token:
            break
    return ids


def is_protected(service, mid):
    msg = service.users().messages().get(
        userId="me", id=mid, format="metadata", metadataHeaders=[]
    ).execute()
    labels = set(msg.get("labelIds", []))
    return bool(labels & {"STARRED", "IMPORTANT"})


def trash_with_retry(service, mid, max_attempts=5):
    delay = 1.0
    for attempt in range(max_attempts):
        try:
            service.users().messages().trash(userId="me", id=mid).execute()
            return True
        except HttpError as e:
            status = getattr(e.resp, "status", None)
            if status in RETRY_STATUS and attempt < max_attempts - 1:
                time.sleep(delay)
                delay *= 2
                continue
            print(f"  [skip] {mid}: HttpError {status}: {e}")
            return False


def get_subject(service, mid):
    try:
        msg = service.users().messages().get(
            userId="me", id=mid, format="metadata", metadataHeaders=["Subject"]
        ).execute()
        for h in msg.get("payload", {}).get("headers", []):
            if h.get("name", "").lower() == "subject":
                return h.get("value", "(no subject)")
        return "(no subject)"
    except HttpError:
        return "(unavailable)"


def main():
    parser = argparse.ArgumentParser(description="Safe Gmail trash cleanup (no permanent delete).")
    parser.add_argument("--dry-run", action="store_true", help="List + count only (default).")
    parser.add_argument("--execute", action="store_true", help="Actually trash messages.")
    parser.add_argument("--confirm-yes", action="store_true", help="Required with --execute.")
    args = parser.parse_args()

    if args.execute and not args.confirm_yes:
        parser.error("--execute requires --confirm-yes (aborting for safety).")
    do_execute = bool(args.execute)

    service = get_service()
    total_found = 0
    total_trashed = 0
    total_skipped = 0

    for name, query in QUERIES.items():
        ids = list_all_ids(service, query)
        total_found += len(ids)
        print(f"[{name}] candidates: {len(ids)}")

        if not do_execute:
            for mid in ids[:5]:
                print(f"  sample {mid}: {get_subject(service, mid)}")
            continue

        trashed = 0
        skipped = 0
        with open(LOG_PATH, "a", encoding="utf-8") as log:
            for mid in ids:
                try:
                    if is_protected(service, mid):
                        skipped += 1
                        continue
                except HttpError as e:
                    print(f"  [skip] protect-check {mid}: {e}")
                    skipped += 1
                    continue
                log.write(json.dumps({
                    "id": mid,
                    "query": name,
                    "ts": datetime.now(timezone.utc).isoformat(),
                }) + "\n")
                log.flush()
                if trash_with_retry(service, mid):
                    trashed += 1
                else:
                    skipped += 1
                time.sleep(0.05)
        total_trashed += trashed
        total_skipped += skipped
        print(f"[{name}] trashed: {trashed}, skipped: {skipped}")

    print(f"SUMMARY found={total_found} trashed={total_trashed} skipped={total_skipped}")
    if not do_execute:
        print("Dry run only — no messages trashed. Use --execute --confirm-yes to trash.")


if __name__ == "__main__":
    main()

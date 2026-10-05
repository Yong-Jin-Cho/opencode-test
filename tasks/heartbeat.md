# Heartbeat (unattended automation definition)
# agent-task.bat attaches this file to every run. Keep it small and idempotent.

1. `git status --short` 대신 작업 폴더 파일 목록만 확인 (git repo 아님).
2. `.venv\Scripts\python.exe --version`, `python -m uv --version` 동작 확인.
3. `.env` 존재 여부만 확인 (값 출력 금지).
4. 이상 있으면 로그에 `[WARN]` 한 줄로 요약, 없으면 `OK` 한 줄.
5. 파일 변경 없이 읽기 전용으로 수행.

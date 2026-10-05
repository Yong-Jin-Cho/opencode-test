# AGENTS.md

## 0. 보안 최상위 원칙 (최우선 준수)
- `.env`는 존재 여부만 참조합니다. 값을 열람하거나 출력하지 않습니다.
- `.env` 값을 git, GitHub, 온라인에 업로드하지 않습니다.
- 터미널, 로그, 응답에 비밀값을 노출하지 않습니다.
- 비가역 작업은 사전 확인 또는 안전 플래그 적용 후 수행합니다.

## 프로젝트 개요
- **프로젝트명**: OpenCode 개인 자동화 도구 모음
- **환경**: Windows 11, PowerShell, Python 3.14 (.venv), uv

## 주요 구성 요소: 무인 자동화 에이전트 및 태스크
- [agent-task.bat](file:///c:/Users/yj77c/opencode%20test/agent-task.bat): 단발성 자동화 실행기
- [tasks/heartbeat.md](file:///c:/Users/yj77c/opencode%20test/tasks/heartbeat.md): 읽기 전용 기본 자동화 헬스체크 정의
- [Register-AgentTask.ps1](file:///c:/Users/yj77c/opencode%20test/Register-AgentTask.ps1): 매일 09:00 자동화 스케줄러 등록, 해제
- [agent-serve.bat](file:///c:/Users/yj77c/opencode%20test/agent-serve.bat): 백그라운드 상시 대기 서버 (127.0.0.1:4096)

## 에이전트 행동 지침 및 규칙
1. **답변 스타일**
   - 한국어 존댓말로 간결하고 명확하게 작성합니다.
   - 핵심 결과와 표, 불릿 요약을 우선합니다.
2. **코드 및 환경 원칙**
   - Windows 환경(`powershell`)과 UTF-8 인코딩을 준수합니다.
   - 수정 전 관련 파일 2개 이상을 확인해 문맥을 파악합니다.
   - 완료 후 동작 여부를 검증합니다.

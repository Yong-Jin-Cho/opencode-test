# AGENTS.md

## 프로젝트 개요
- **프로젝트명**: OpenCode 개인 자동화 및 유틸리티 도구 모음
- **환경**: Windows 11, PowerShell, Python 3.14 (.venv), uv

## 주요 구성 요소
1. **Gmail 정리 유틸리티**
   - [imap_trash.py](file:///c:/Users/yj77c/opencode%20test/imap_trash.py): IMAP 프로토콜을 사용한 메일 정리 (기본 드라이런, `--execute --confirm-yes`로 안전 휴지통 이동)
   - [imap_trash_log.jsonl](file:///c:/Users/yj77c/opencode%20test/imap_trash_log.jsonl): 처리 내역 복구/추적 로그
2. **당근마켓 RAM 시세 모니터링**
   - [Watch-KarrotRam.ps1](file:///c:/Users/yj77c/opencode%20test/Watch-KarrotRam.ps1): 분당/수원 지역 DDR4 노트북용 16GB 램 매물 모니터링
   - [Register-KarrotWatch.ps1](file:///c:/Users/yj77c/opencode%20test/Register-KarrotWatch.ps1): 1시간 주기 작업 스케줄러 등록 스크립트
   - [alert-ram16.txt](file:///c:/Users/yj77c/opencode%20test/alert-ram16.txt): 추출된 매물 목록
3. **무인 에이전트 & 점검 태스크**
   - [agent-task.bat](file:///c:/Users/yj77c/opencode%20test/agent-task.bat): 단발성 자동 점검 실행기
   - [tasks/heartbeat.md](file:///c:/Users/yj77c/opencode%20test/tasks/heartbeat.md): 읽기 전용 기본 점검 체크리스트
   - [Register-AgentTask.ps1](file:///c:/Users/yj77c/opencode%20test/Register-AgentTask.ps1): 매일 09:00 일일 점검 스케줄러 등록/해제
   - [agent-serve.bat](file:///c:/Users/yj77c/opencode%20test/agent-serve.bat): 백그라운드 상시 대기 서버 (127.0.0.1:4096)

## 에이전트 행동 지침 및 규칙
1. **답변 스타일**
   - 모든 답변은 한국어 존댓말로 간결하고 명확하게 작성합니다.
   - 장황한 설명 대신 핵심 결과와 표/불릿 요약을 우선합니다.
2. **보안 및 안전 원칙**
   - `.env` 파일의 민감 정보(API 키, 계정 비밀번호)는 절대 출력하거나 유출하지 않습니다.
   - 메일 영구 삭제 등 비가역적 파괴 작업은 지양하며, 사전 확인 또는 안전 플래그를 필수로 둡니다.
3. **코드 및 환경 원칙**
   - Windows 환경(`powershell`)과 UTF-8 인코딩을 기본으로 준수합니다.
   - 파일 수정 전 관련 파일을 최소 2개 이상 확인하여 문맥을 파악합니다.
   - 작업 완료 후 동작 여부를 검증합니다.

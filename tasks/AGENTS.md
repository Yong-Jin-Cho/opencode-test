# tasks/AGENTS.md

## 역할
- 무인 자동화 및 주기적 자동화 작업 명세(Task Definition) 보관 폴더입니다.

## 파일 목록
- [heartbeat.md](file:///c:/Users/yj77c/opencode%20test/tasks/heartbeat.md): 가상환경, 필수 도구(uv), `.env` 존재 여부 및 파일 목록을 확인하는 무인 자동화 헬스체크 규칙

## 규칙 및 주의사항
1. 새 태스크 정의 파일 추가 시 상단에 목적과 멱등성(idempotent) 유지 지침을 명시합니다.
2. 무인 자동화 파일은 읽기 전용(Read-only)으로 작성하며 임의의 파일 변경이나 민감 정보 조회를 수행하지 않습니다.
3. `.env` 파일 내부의 값(API 키 등)은 절대 출력하거나 로그에 기록하지 않습니다.

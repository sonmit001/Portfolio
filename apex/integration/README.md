## OAuth Authentication Service

- External OAuth 2.0 인증 처리
- Custom Metadata 기반 설정 관리
- Access Token 캐싱 및 만료 제어
## OAuthAuthResponse
- 인증 결과를 표준화된 Response 객체로 반환하여
  서비스 레이어와 호출부의 결합도를 최소화
## SFMCJourneyService

### Purpose
- 외부 마케팅/워크플로우 시스템의 정의(JSON)를 Salesforce Apex에서 관리
- 기존 워크플로우를 안전하게 복제 및 재구성

### Key Features
- REST API 기반 Workflow 조회 / 생성 / 수정 / 삭제
- 대규모 JSON Deep Copy 및 ID 재매핑
- Activity / Transition 참조 무결성 사전 검증
- Callout Timeout, Pagination, Error Handling 고려

### Technical Highlights
- Recursive JSON traversal & transformation
- GUID 기반 ID 재생성 전략
- Read-only 필드 자동 제거
- Salesforce Callout Governor Limit 대응

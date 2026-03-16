## Slack 화면
<img width="822" height="403" alt="Image" src="https://github.com/user-attachments/assets/bf68b727-ecb6-4c36-83cb-71956db3dd39" />

## SlackIntegration.cls
- Slack 메시지 전송
- payload 작성 https://docs.slack.dev/reference/interaction-payloads/block_actions-payload/
- 기본 구조
  
  <img width="775" height="1120" alt="Image" src="https://github.com/user-attachments/assets/7a5be410-ec7b-403c-ab8b-35be596d4fe6" />

## SlackIntegration.cls
- Slack Interactivity에 설정한 Requst URL 로 @POST 로 수신
- payload에 있는 데이터로 관련 Function 실행

## SlackInteractionHandler.cls
- lead 담당자 할당
- Slack에 담당자 할당 완료 알림
- messageTs를 처음 메시지와 동일시 하여 기존 메시지를 업데이트

## SlackUserSearchEndpoint.cls
- slack app > select menus에 설정한 Options load URL @POST 수신 클래스
- 담당자 할당을 위해 user 실시간 검색

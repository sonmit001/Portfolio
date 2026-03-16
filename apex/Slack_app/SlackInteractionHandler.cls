public class SlackInteractionHandler {

    @future(callout=true)
    public static void handleAsync(String payloadJson) {

        Map<String, Object> payload =
            (Map<String, Object>) JSON.deserializeUntyped(payloadJson);

        if ((String) payload.get('type') != 'block_actions') return;

        List<Object> actions = (List<Object>) payload.get('actions');
        Map<String, Object> action = (Map<String, Object>) actions[0];
        String actionId = (String) action.get('action_id');

        Map<String, Object> container =
            (Map<String, Object>) payload.get('container');
        String channelId = (String) container.get('channel_id');
        String messageTs = (String) container.get('message_ts');

        if (actionId == 'select_lead_owner') {

            Map<String, Object> selectedOption =
                (Map<String, Object>) action.get('selected_option');
            String selectedUserId = (String) selectedOption.get('value');

            String blockId = (String) action.get('block_id');
            String leadId  = blockId.replace('assign_block_', '');

            System.debug('### Lead ID: ' + leadId);
            System.debug('### Selected User ID: ' + selectedUserId);

            // ✅ 핵심 변경
            // DML 먼저 실행
            String ownerName = updateLeadOwner(leadId, selectedUserId);

            // Callout은 별도 @future로 분리
            if (String.isNotBlank(ownerName)) {
                sendSlackUpdate(channelId, messageTs, ownerName, leadId);
            }
        }
    }

    // ── DML만 처리 (Callout 없음) ─────────────────────
    private static String updateLeadOwner( String leadId, String selectedUserId ) {
        List<User> users = [
            SELECT Id, Name
            FROM User
            WHERE Id = :selectedUserId   AND IsActive = true     LIMIT 1 ];

        if (users.isEmpty()) {
            System.debug('### User 없음: ' + selectedUserId);
            return null;
        }

        User sfUser = users[0];
        System.debug('### 배정할 User: ' + sfUser.Name);

        Lead lead = [
            SELECT Id, Name
            FROM Lead
            WHERE Id = :leadId     LIMIT 1 ];

        lead.OwnerId     = sfUser.Id;

        update lead;
        System.debug('### Lead Owner 업데이트 완료: ' + sfUser.Name);
        return sfUser.Name;
    }
    
    // ── Callout만 처리 (DML 없음) ─────────────────────
    // @future(callout=true) 로 분리해서 DML 트랜잭션과 분리
    @future(callout=true)
    public static void sendSlackUpdate( String channelId, String messageTs, String ownerName, String leadId) {
        System.debug('### Slack 메시지 업데이트 시작');
        
        SlackConfig__mdt config = SlackIntegrationTemp.getConfig();
        Lead lead = [  SELECT Id, Name
                     FROM Lead
                     WHERE Id = :leadId
                     LIMIT 1
        ];
        String doneText =
             '🔥 *[핫 리드 감지]* 리드: *' + lead.Name + '*\n' +
            '✅ *담당자 배정 완료*\n'
            + '담당자: *' + ownerName + '*\n'
            + '배정시각: '
            + System.now().format('yyyy-MM-dd HH:mm', 'Asia/Seoul');

        Map<String, Object> payload = new Map<String, Object>{
            'channel' => channelId,
            'ts'      => messageTs,
            'blocks'  => new List<Object>{
                new Map<String, Object>{
                    'type' => 'section',
                    'text' => new Map<String, Object>{
                        'type' => 'mrkdwn',
                        'text' => doneText
                    }
                }
            }
        };

            HttpRequest req = new HttpRequest();
        //req.setEndpoint('callout:Slack_Bot/chat.update');
        // ✅ callout:Slack_Bot → 직접 URL로 변경
        req.setEndpoint('https://slack.com/api/chat.update');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json; charset=UTF-8');
        req.setHeader('Authorization', 'Bearer ' + config.BotToken__c);
        req.setBody(JSON.serialize(payload));

        HttpResponse res = new Http().send(req);
        System.debug('### Slack 응답: ' + res.getStatusCode()
                     + ' ' + res.getBody());
    }
}

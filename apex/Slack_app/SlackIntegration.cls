public class SlackIntegration {

  // Slack 채널 전송 함
  @future(callout=true)
  public static void sendMessage(String channel, String message) {
        SlackConfig__mdt config = getConfig();
        Map<String, Object> payload = new Map<String, Object>{
            'channel' => channel,
            'text'    => message
        };
        send('chat.postMessage', payload, config.BotToken__c);
    }

    //
    @future(callout=true)
    public static void sendHotLeadAlert(Id leadId, String channel, String message) {

    SlackConfig__mdt config = getConfig();
      
    Lead lead = [
        SELECT Id, Name, TotalScore__c FROM Lead
        WHERE Id = :leadId
        LIMIT 1
    ];
      
    String leadUrl  = URL.getOrgDomainUrl().toExternalForm() + '/' + lead.Id;
    String score    = lead.TotalScore__c != null ? String.valueOf(lead.TotalScore__c.intValue()) : '0';

    Map<String, Object> payload = new Map<String, Object>{
    'channel' => channel,
          'blocks'  => buildBlocks(lead, score, leadUrl, message)
      };
      send('chat.postMessage', payload, config.BotToken__c);

    }

  // payload 구조화
   private static List<Object> buildBlocks(Lead lead, String score, String leadUrl, String message) {
        return new List<Object>{
            new Map<String, Object>{
                'type' => 'header',
                'text' => new Map<String, Object>{
                    'type' => 'plain_text',
                    'text' => '🔥 [핫 리드 감지] 리드: ' + lead.Name + ' (점수: ' + score + ')'
                }
            },
            new Map<String, Object>{ 'type' => 'divider' },
            new Map<String, Object>{
                'type'   => 'section',
                'fields' => new List<Object>{
                    new Map<String, Object>{
                        'type' => 'mrkdwn',
                        'text' => '*내용:*\n' + message
                    }
                }
            },
            new Map<String, Object>{ 'type' => 'divider' },
            new Map<String, Object>{
                'type'     => 'section',
                'text'     => new Map<String, Object>{
                    'type' => 'mrkdwn',
                    'text' => '*담당자를 선택하세요*'
                },
                'block_id' => 'assign_block_' + lead.Id,
                'accessory' => new Map<String, Object>{
                    'type'        => 'external_select',
                    'action_id'   => 'select_lead_owner',
                    'placeholder' => new Map<String, Object>{
                        'type' => 'plain_text',
                        'text' => '🔍 담당자 이름 검색...'
                    },
                    'min_query_length' => 0
                }
            },
            new Map<String, Object>{
                'type' => 'section',
                'text' => new Map<String, Object>{
                    'type' => 'mrkdwn',
                    'text' => '*🔗 Salesforce 레코드:*\n' + leadUrl
                }
            }
        };
    }

    // ── 공통 HTTP 전송 ─────────────────────────────────────
    public static void send(
        String apiMethod,
        Map<String, Object> payload,
        String botToken
    ) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Slack_Bot/' + apiMethod);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json; charset=UTF-8');
        req.setHeader('Authorization', 'Bearer ' + botToken);
        req.setBody(JSON.serialize(payload));

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            System.debug('Slack 오류: ' + res.getBody());
        }
    }

    public static SlackConfig__mdt getConfig() {
        return [
            SELECT BotToken__c, SigningSecret__c, ChannelId__c
            FROM SlackConfig__mdt
            LIMIT 1
        ];
    }
}

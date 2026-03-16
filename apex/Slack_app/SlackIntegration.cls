public class SlackIntegration {
    @future(callout=true)
    public static void sendMessage(String channel, String message) {
        SlackConfig__mdt config = getConfig();
        Map<String, Object> payload = new Map<String, Object>{
            //'channel' => config.ChannelId__c,
            'channel' => channel,
                'text' => message
                };
                    send('chat.postMessage', payload, config.BotToken__c);
    }
    
    @future(callout=true)
    public static void sendHotLeadAlert(
        String leadId,
        String channel,
        String message
    ) {
        SlackConfig__mdt config = getConfig();
        
        Lead lead = [
            SELECT Id, Name, Lead_Score_Value__c
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];
        
        String leadUrl = URL.getOrgDomainUrl().toExternalForm() + '/' + lead.Id;
        String score = lead.Lead_Score_Value__c != null
            ? String.valueOf(lead.Lead_Score_Value__c.intValue())
            : '0';
        system.debug('##leadUrl = ' + leadUrl);
        system.debug('##lead = ' + lead);
        
        // 메시지 발송 시 Lead ID를 block_id에 심어서
        // 나중에 선택 이벤트에서 꺼내 쓸 수 있게 함
        Map<String, Object> payload = new Map<String, Object>{
            //'channel' => config.ChannelId__c,
            'channel' => channel,
                'blocks' => buildBlocks(lead, score, leadUrl, message)
                };
                    send('chat.postMessage', payload, config.BotToken__c);
    }
    
    private static List<Object> buildBlocks(
        Lead lead,
        String score,
        String leadUrl,
        String message
    ) {
        // User 검색 엔드포인트 URL
        // Slack이 검색어 입력할 때마다 이 URL로 쿼리를 날림
        String orgUrl = URL.getOrgDomainUrl().toExternalForm();
        String searchUrl = orgUrl + '/services/apexrest/slack/usersearch';
        // String leadUrl = 'https://chanyeonki-250220-891-demo.lightning.force.com/lightning/r/Lead/'+00QKd000014ldEgMAI+'/view';
        
        return new List<Object>{
            // ── 헤더 ──────────────────────────────────────────
            new Map<String, Object>{
                'type' => 'header',
                    'text' => new Map<String, Object>{
                        'type' => 'plain_text',
                            'text' => '🔥 [핫 리드 감지] 리드: ' +
                            lead.Name +
                            ' (점수: ' +
                            score +
                            ')'
                            }
            },
                new Map<String, Object>{ 'type' => 'divider' },
                    // ── 요약 + 상태 ───────────────────────────────────
                    new Map<String, Object>{
                        'type' => 'section',
                            'fields' => new List<Object>{
                                new Map<String, Object>{
                                    'type' => 'mrkdwn',
                                        'text' => '*내용:*\n' + message
                                        }
                            }
                    },
                        new Map<String, Object>{ 'type' => 'divider' },
                            // ── External Select 드롭다운 ──────────────────────
                            new Map<String, Object>{
                                'type' => 'section',
                                    'text' => new Map<String, Object>{
                                        'type' => 'mrkdwn',
                                            'text' => '*담당자를 선택하세요*'
                                            },
                                                // block_id에 Lead ID를 심어둠
                                                // 선택 이벤트에서 어떤 Lead인지 식별하는 데 사용
                                                'block_id' => 'assign_block_' + lead.Id,
                                                'accessory' => new Map<String, Object>{
                                                    'type' => 'external_select',
                                                        'action_id' => 'select_lead_owner',
                                                        'placeholder' => new Map<String, Object>{
                                                            'type' => 'plain_text',
                                                                'text' => '🔍 담당자 이름 검색...'
                                                                },
                                                                    // 최소 입력 글자 수 (0이면 클릭 즉시 전체 목록 표시)
                                                                    'min_query_length' => 0
                                                                    }
                            },
                                // ── Salesforce에서 보기 버튼 ──────────────────────
                                /*
new Map<String, Object>{
'type'     => 'actions',
'elements' => new List<Object>{
new Map<String, Object>{
'type'      => 'button',
'action_id' => 'view_in_sf',
'url'       => leadUrl,
'text'      => new Map<String, Object>{
'type' => 'plain_text',
'text' => 'Salesforce에서 보기'
}
}
}
},
*/
                                new Map<String, Object>{
                                    'type' => 'section',
                                        'text' => new Map<String, Object>{
                                            'type' => 'mrkdwn',
                                                'text' => '*🔗 Salesforce 레코드:*\n' +
                                                leadUrl // URL 텍스트로 포함
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
        //req.setEndpoint('callout:Slack_Bot/' + apiMethod);
        //✅ callout:Slack_Bot 대신 직접 URL 사용
        req.setEndpoint('https://slack.com/api/' + apiMethod);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json; charset=UTF-8');
        req.setHeader('Authorization', 'Bearer ' + botToken);
        req.setBody(JSON.serialize(payload));
        
        HttpResponse res = new Http().send(req);
        System.debug(
            '### Slack 응답: ' + res.getStatusCode() + ' ' + res.getBody()
        );
        if (res.getStatusCode() != 200) {
            System.debug('Slack 오류: ' + res.getBody());
        }
    }
    
    public static SlackConfig__mdt getConfig() {
        return [
            SELECT BotToken__c, SigningSecret__c
            FROM SlackConfig__mdt
            LIMIT 1
        ];
    }
}

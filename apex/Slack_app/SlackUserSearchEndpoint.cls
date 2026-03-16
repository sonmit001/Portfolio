@RestResource(urlMapping='/slack/usersearch/*')
global class SlackUserSearchEndpoint {
    @HttpPost
    global static void handlePost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        
        String searchQuery = '';
        
        // Slack은 payload 파라미터에 JSON을 담아서 보냄
        // params에서 payload 꺼내서 파싱
        if (req.params != null && req.params.containsKey('payload')) {
            try {
                String payloadJson = req.params.get('payload');
                System.debug('### PAYLOAD JSON: ' + payloadJson);
                
                Map<String, Object> payloadMap = (Map<String, Object>) JSON.deserializeUntyped(
                    payloadJson
                );
                
                // 검색어는 최상위 "value" 키에 있음
                Object val = payloadMap.get('value');
                System.debug('### VALUE OBJECT: ' + val);
                
                if (val != null) {
                    searchQuery = String.valueOf(val);
                }
            } catch (Exception e) {
                System.debug('### 파싱 오류: ' + e.getMessage());
            }
        }
        
        System.debug('### 최종 검색어: [' + searchQuery + ']');
        
        // SF User 검색
        String likeQuery = '%' + searchQuery + '%';
        List<User> users = [
            SELECT Id, Name, Email, SmallPhotoUrl
            FROM User
            WHERE
            IsActive = TRUE
            AND (Name LIKE :likeQuery
                 OR Email LIKE :likeQuery)
            AND Profileid = '00eKa000001ofw0IAA'
            ORDER BY Name DESC
            LIMIT 30
        ];
        
        System.debug('### 검색 결과 수: ' + users.size());
        
        List<Map<String, Object>> options = new List<Map<String, Object>>();
        for (User u : users) {
            options.add(
                new Map<String, Object>{
                    'text' => new Map<String, Object>{
                        'type' => 'plain_text',
                            'text' => u.Name +
                            '  (' +
                            u.Email +
                            ')'
                            },
                                'value' => u.Id
                                }
            );
        }
        
        res.statusCode = 200;
        res.addHeader('Content-Type', 'application/json');
        res.responseBody = Blob.valueOf(
            JSON.serialize(new Map<String, Object>{ 'options' => options })
        );
    }
}

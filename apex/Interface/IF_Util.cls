/**
 * @description       : REST API 공통 호출 유틸
 *                      IF_System_Info__mdt (시스템 접속 정보) 와
 *                      IF_Table__c (인터페이스별 설정) 를 조합하여 HTTP 요청을 처리합니다.
 *
 * [호출 흐름]
 *   IF_CalloutUtil.doCallout()
 *       └─ IF_Util(sysNm, ifId)   : 생성자 - 시스템 정보 및 인터페이스 정보 로드
 *       └─ getCallout(param)      : HTTP 요청 실행
 *
 * [인증 방식 - IF_System_Info__mdt.GrantType__c]
 *   - password           : Basic 인증 (LoginId:LoginPassword → Base64)
 *   - client_credentials : OAuth 2.0 (SEND_TYPE=LOGIN 으로 토큰 발급 → SEND_TYPE=CALL 로 API 호출)
 *   - 그 외              : GrantType__c 를 헤더명으로, SecretKey__c 를 헤더값으로 세팅
 *
 * [HTTP Method - IF_Table__c.Method__c]
 *   - POST : param → req.setBody(param)
 *   - GET  : param → endpoint + '?' + param
 *
 * [반환 Map 키]
 *   - statusCode   : Integer (HTTP 상태코드, Exception 시 999)
 *   - ResponseBody : String  (응답 Body)
 *   - Response     : HttpResponse 객체
 *   - Error        : String  (Exception 발생 시 StackTrace + Message)
 **/
public without sharing class IF_Util {

    private IF_System_Info__mdt sysInfo = null;
    private IF_Table__c         ifTable = null;

    private final Integer REPEAT_COUNT = 2;           // 오류 시 최대 재시도 횟수
    private final Integer REST_TIMEOUT = 1000 * 60 * 2; // 타임아웃 2분

    private final String REST_METHOD_GET  = 'GET';
    private final String REST_METHOD_POST = 'POST';

    public IF_Util() {}

    /**
     * @description 시스템명과 인터페이스 ID로 접속 정보를 초기화합니다.
     * @param sysNm  IF_System_Info__mdt.Name__c 값 (ex. API_CRM_ZENT_KR)
     * @param ifId   IF_Table__c.Name 값 (ex. IF_SFDC_BRICS_0011)
     **/
    public IF_Util(String sysNm, String ifId) {
        List<IF_System_Info__mdt> sysInfoList = getQuerySystemInfo(sysNm);
        List<IF_Table__c>         ifTableList = getQueryIfTable(ifId);

        if (sysInfoList != null && sysInfoList.size() > 0) sysInfo = sysInfoList.get(0);
        if (ifTableList != null && ifTableList.size() > 0) ifTable = ifTableList.get(0);
    }

    /**
     * @description 현재 Org 환경(Sandbox/Production)에 맞는 시스템 정보를 조회합니다.
     * @param sysNm 시스템명
     * @return List<IF_System_Info__mdt>
     **/
    public List<IF_System_Info__mdt> getQuerySystemInfo(String sysNm) {
        Organization org    = [SELECT Id, IsSandBox FROM Organization LIMIT 1];
        String       orgType = org?.IsSandbox ? 'Sandbox' : 'Production';

        return [
            SELECT Id, Name__c, Url__c, ClientId__c, SecretKey__c,
                   OrgType__c, LoginId__c, LoginPassword__c, CompanyId__c, GrantType__c
            FROM   IF_System_Info__mdt
            WHERE  Name__c   = :sysNm
            AND    OrgType__c = :orgType
        ];
    }

    /**
     * @description 인터페이스 ID에 해당하는 IF_Table__c 레코드를 조회합니다.
     *              Method__c, Path__c, ContentType__c, AddHeader__c 를 포함합니다.
     * @param ifId 인터페이스 ID
     * @return List<IF_Table__c>
     * sample: contenttype:application/json	path:/v1/test methos:POST name:ZENT_IF_TEST
     **/
    private List<IF_Table__c> getQueryIfTable(String ifId) {
        return [
            SELECT Id, ContentType__c, AddHeader__c, Path__c, Method__c
            FROM   IF_Table__c
            WHERE  Name = :ifId
        ];
    }

    public IF_System_Info__mdt getSystemInfo() {
        return sysInfo;
    }

    public IF_System_Info__mdt getSystemInfo(String sysNm) {
        IF_System_Info__mdt       result      = null;
        List<IF_System_Info__mdt> sysInfoList = getQuerySystemInfo(sysNm);
        if (sysInfoList != null && sysInfoList.size() > 0) result = sysInfoList.get(0);
        return result;
    }

    public IF_Table__c getIfTableInfo() {
        return ifTable;
    }

    /**
     * @description HTTP 요청을 실행하고 결과를 반환합니다.
     *
     *   [반환 Map]
     *   - statusCode   : Integer - HTTP 상태코드 (Exception 시 999)
     *   - ResponseBody : String  - 응답 Body
     *   - Response     : HttpResponse - HttpResponse 객체
     *   - Error        : String  - Exception 발생 시 StackTrace\nMessage
     *
     * @param param
     *   - POST : JSON 직렬화된 문자열
     *   - GET  : QueryString (key=value&key=value 형식)
     * @return Map<String, Object>
     **/
    public Map<String, Object> getCallout(String param) {

        System.debug('[IF_Util] param : ' + param);

        Map<String, Object> rtnMap = new Map<String, Object>();
        HttpResponse        res    = null;

        try {
            Http        http     = new Http();
            HttpRequest req      = new HttpRequest();
            String      endPoint = sysInfo.Url__c + ifTable.Path__c;

            // ── 인증 방식 세팅 ──────────────────────────────────────────
            if (sysInfo.GrantType__c == 'password') {
                // Basic 인증 : LoginId:LoginPassword → Base64 인코딩
                Blob   headerValue = Blob.valueOf(sysInfo.LoginId__c + ':' + sysInfo.LoginPassword__c);
                String auth        = 'BASIC ' + EncodingUtil.base64Encode(headerValue);
                req.setHeader('Authorization', auth);

            } else if (sysInfo.GrantType__c == 'client_credentials') {
                // OAuth 2.0
                // SEND_TYPE=LOGIN : 토큰 발급 요청
                // SEND_TYPE=CALL  : 실제 API 호출 (토큰을 Authorization 헤더에 세팅)
                Map<String, Object> paramMap = (Map<String, Object>) JSON.deserializeUntyped(param);
                String sendType = Util_Common.nvlStr(paramMap.get('SEND_TYPE') + '');

                if (sendType == 'LOGIN') {
                    Map<String, Object> oAuthMap = new Map<String, Object>{
                        'grant_type'    => sysInfo.GrantType__c,
                        'client_id'     => sysInfo.ClientId__c,
                        'client_secret' => sysInfo.SecretKey__c
                    };
                    param = Util_Common.convertMapToQueryString(oAuthMap);

                } else if (sendType == 'CALL') {
                    req.setHeader('Authorization',
                        paramMap.get('token_type') + ' ' + paramMap.get('access_token'));
                    paramMap.remove('token_type');
                    paramMap.remove('access_token');
                    param = JSON.serialize(paramMap);
                }

            } else {
                // 그 외 : GrantType__c 를 헤더명, SecretKey__c 를 헤더값으로 세팅
                // ex) GrantType__c = 'ApiKey' → req.setHeader('ApiKey', SecretKey__c)
                req.setHeader(sysInfo.GrantType__c, sysInfo.SecretKey__c);
            }

            // ── HTTP Method 및 파라미터 세팅 ────────────────────────────
            if (ifTable.Method__c == REST_METHOD_POST) {
                if (String.isNotBlank(param)) req.setBody(param);

            } else if (ifTable.Method__c == REST_METHOD_GET) {
                if (String.isNotBlank(param)) endPoint = endPoint + '?' + param;
            }

            req.setMethod(ifTable.Method__c);
            req.setTimeout(REST_TIMEOUT);
            req.setEndpoint(endPoint);

            // ── Content-Type 세팅 ────────────────────────────────────────
            // IF_Table__c.ContentType__c 에 값이 있어야 합니다.
            // GET 방식이라도 반드시 입력 필요 (ex. application/json)
            req.setHeader('Content-Type', ifTable.ContentType__c);

            // ── 추가 헤더 세팅 (IF_Table__c.AddHeader__c) ───────────────
            // JSON 형식으로 저장된 추가 헤더를 파싱하여 세팅
            // ex) {"X-Api-Key": "abc123", "X-Custom-Header": "value"}
            if (String.isNotBlank(ifTable.AddHeader__c)) {
                Map<String, Object> hdMap = (Map<String, Object>) JSON.deserializeUntyped(ifTable.AddHeader__c);
                for (String key : hdMap.keySet()) {
                    req.setHeader(key, hdMap.get(key) + '');
                }
            }

            // ── HTTP 요청 실행 (오류 시 최대 REPEAT_COUNT 회 재시도) ────
            Integer statusCode = 0;
            Integer repeatIdx  = 0;
            do {
                res        = http.send(req);
                statusCode = res.getStatusCode();
                if (statusCode == 200) break;
            } while (repeatIdx++ < REPEAT_COUNT);

            rtnMap.put('statusCode',   statusCode);
            rtnMap.put('ResponseBody', res.getBody());
            rtnMap.put('Response',     res);

        } catch (Exception e) {
            System.debug('[IF_Util] Exception : ' + e.getStackTraceString());
            System.debug('[IF_Util] Exception : ' + e);

            rtnMap.put('statusCode',   999);
            rtnMap.put('ResponseBody', '');
            rtnMap.put('Response',     null);
            rtnMap.put('Error',        e.getStackTraceString() + '\n' + e.getMessage());
        }

        return rtnMap;
    }
}

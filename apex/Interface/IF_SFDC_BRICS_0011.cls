/**
 * @description       : 메시지 이력 조회 인터페이스
 *                      Salesforce → BRICS : GET /v1/message
 *                      수신자 전화번호 / 기간으로 메시지 발송 이력을 조회합니다.
 *
 *                      [IF_Table__c 설정값]
 *                        Name          : IF_SFDC_BRICS_0011
 *                        Method__c     : GET
 *                        Path__c       : /v1/message
 *                        ContentType__c: application/json  ← GET 이라도 반드시 입력
 *
 *                      [Anonymous Apex 테스트]
 *                        docs/INTERFACE_GUIDE.md > Step 6 참고

 **/
public with sharing class IF_SFDC_BRICS_0011 {

    private final String APEX_CLASS    = 'IF_SFDC_BRICS_0011';
    private final String LOG_TYPE      = 'Interface';
    private final String TARGET_SYSTEM = 'API_CRM_ZENT_KR';
    private final String INTERFACE_ID  = 'IF_SFDC_BRICS_0011';

    // ══════════════════════════════════════════════════════════════════════
    // Inner Classes - Request / Response
    // ══════════════════════════════════════════════════════════════════════

    /**
     * @description 요청 파라미터 (GET Query String)
     *              ⚠️ 'limit' 은 Apex 예약어이므로 limitCount 로 선언
     *                  buildQueryString() 에서 'limit' 으로 변환하여 전송
     **/
    public class MessageHistoryRequest {
        public String recipientPhoneNumber; // 수신자 전화번호
        public String startDate;            // 조회 시작일 (ex. 2026-01-01)
        public String endDate;              // 조회 종료일 (ex. 2026-04-30)
        public String nextCursor;           // 페이징 커서 (첫 조회 시 빈값)
        public String limitCount;           // 조회 건수 ※ API 전송 시 'limit' 으로 변환
    }

    /**
     * @description 응답 최상위 구조
     **/
    public class MessageHistoryResponse {
        public Integer     code; // 비즈니스 결과코드 (200 = 정상)
        public ResponseData data;
    }

    /**
     * @description 응답 data 객체
     **/
    public class ResponseData {
        public List<MessageItem> messages;   // 메시지 목록
        public String            nextCursor; // 다음 페이징 커서
        public Boolean           hasMore;    // 추가 데이터 존재 여부
    }

    /**
     * @description 메시지 이력 단건
     **/
    public class MessageItem {
        public String messageId;            // 메시지 ID
        public String content;              // 메시지 내용
        public String messageType;          // 메시지 유형
        public String recipientPhoneNumber; // 수신자 전화번호
        public String requestTime;          // 요청 시각
        public String resultTime;           // 결과 시각
        public String resultCode;           // 발송 결과 코드
        public String senderInfo;           // 발신자 정보
    }

    // ══════════════════════════════════════════════════════════════════════
    // Main Method
    // ══════════════════════════════════════════════════════════════════════

    /**
     * @description BRICS 에 메시지 이력 조회를 요청하고 결과를 반환합니다.
     *
     *   [반환 Map 키]
     *   - STATUS_CODE : Integer               - HTTP 상태코드
     *   - ERROR_MSG   : String                - 오류 메세지 (정상 시 null)
     *   - LOG_OBJ     : IF_Log                - 로그 객체
     *   - RESULT_DATA : MessageHistoryResponse - 파싱된 응답 데이터
     *
     * @param reqPayload 요청 파라미터
     * @return Map<String, Object>
     **/
    public Map<String, Object> sendRequest(MessageHistoryRequest reqPayload) {

        Map<String, Object>    resultMap = new Map<String, Object>();
        MessageHistoryResponse resData   = null;
        IF_Log log = new IF_Log(LOG_TYPE, INTERFACE_ID, APEX_CLASS);
        log.apexMethod = 'sendRequest';
        Integer status = 0;

        try {
            if (reqPayload == null) {
                log.requestData = 'No Data';
                log.totalCount  = 0;
                throw new IllegalArgumentException('No Parameter');
            }

            // GET 방식 : Query String 으로 변환
            // IF_Util 내부에서 endpoint + '?' + queryString 으로 조합
            String queryString  = buildQueryString(reqPayload);
            log.requestData     = queryString;

            Map<String, Object> response = (Map<String, Object>) IF_CalloutUtil.doCallout(
                TARGET_SYSTEM, INTERFACE_ID, queryString
            );

            if (response != null && response.containsKey('statusCode')) {
                status = Integer.valueOf(String.valueOf(response.get('statusCode')));
                // ⚠️ IF_CalloutUtil.doCallout 반환 키는 'resBody' (IF_Util 의 'ResponseBody' 와 다름)
                String resBody   = (String) response.get('resBody');
                log.responseData = resBody;

                if (status / 100 == 2) {
                    if (String.isNotBlank(resBody)) {
                        resData = (MessageHistoryResponse) JSON.deserialize(
                            resBody, MessageHistoryResponse.class
                        );

                        if (resData != null && resData.code == 200) {
                            log.resultType   = 'Success';
                            log.successCount = (resData.data != null && resData.data.messages != null)
                                               ? resData.data.messages.size() : 0;
                        } else {
                            log.resultType   = 'Fail';
                            log.errorMessage = 'Business Logic Error: '
                                + (resData != null ? String.valueOf(resData.code) : 'No Code');
                            log.failCount    = 1;
                        }
                    }
                } else {
                    // statusCode 999 : IF_Util 내부 Exception 발생 케이스
                    log.resultType   = 'Fail';
                    log.failCount    = 1;
                    log.errorMessage = 'HTTP Error: ' + status + ' / '
                        + (String) response.get('error');
                }
            }

            log.totalCount = 1;

        } catch (Exception e) {
            log.resultType   = 'Fail';
            log.failCount    = 1;
            log.errorMessage = e.getMessage() + '/' + e.getStackTraceString();
        } finally {
            resultMap.put('STATUS_CODE', status);
            resultMap.put('ERROR_MSG',   log.errorMessage);
            resultMap.put('LOG_OBJ',     log);
            resultMap.put('RESULT_DATA', resData);
            log.createLog();
        }

        return resultMap;
    }

    // ══════════════════════════════════════════════════════════════════════
    // Helper
    // ══════════════════════════════════════════════════════════════════════

    /**
     * @description Request 객체를 GET Query String 으로 변환합니다.
     *              값이 없는 파라미터는 제외합니다.
     *              ⚠️ 'limitCount' → API 파라미터명 'limit' 으로 변환하여 전송
     * @param req 요청 파라미터
     * @return String ex) recipientPhoneNumber=01012345678&startDate=2026-01-01&limit=10
     **/
    private String buildQueryString(MessageHistoryRequest req) {
        List<String> params = new List<String>();

        if (String.isNotBlank(req.recipientPhoneNumber)) {
            params.add('recipientPhoneNumber=' + EncodingUtil.urlEncode(req.recipientPhoneNumber, 'UTF-8'));
        }
        if (String.isNotBlank(req.startDate)) {
            params.add('startDate=' + EncodingUtil.urlEncode(req.startDate, 'UTF-8'));
        }
        if (String.isNotBlank(req.endDate)) {
            params.add('endDate=' + EncodingUtil.urlEncode(req.endDate, 'UTF-8'));
        }
        if (String.isNotBlank(req.nextCursor)) {
            params.add('nextCursor=' + EncodingUtil.urlEncode(req.nextCursor, 'UTF-8'));
        }
        if (String.isNotBlank(req.limitCount)) {
            // API 파라미터명은 'limit' 으로 전송 (Apex 예약어 우회)
            params.add('limit=' + EncodingUtil.urlEncode(req.limitCount, 'UTF-8'));
        }

        return String.join(params, '&');
    }
}

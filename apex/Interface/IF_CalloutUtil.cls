/**
 * @description       : IF_Util 의 래퍼 클래스.
 *                      인터페이스 구현체(IF_SFDC_BRICS_XXXX)에서 호출하는 진입점입니다.
 *
 *                      [메서드 구분]
 *                      - doCallout()    : 로그 기록 없이 호출만 수행 (구현체에서 직접 로그 관리 시 사용)
 *                      - doCalloutLog() : 호출 + 로그 기록을 한 번에 처리
**/
public with sharing class IF_CalloutUtil {

    /**
     * @description 인터페이스 호출만 수행합니다. (로그 기록 없음)
     *              로그는 호출한 구현체(IF_SFDC_BRICS_XXXX)에서 직접 관리합니다.
     *
     *   [반환 Map 키]
     *   - statusCode : String  - HTTP 상태코드 (ex. "200", "999")
     *   - resBody    : Object  - 응답 Body 문자열
     *   - error      : Object  - Exception 발생 시 오류 내용 (statusCode=999 일 때 유효)
     *
     *   ⚠️ IF_Util.getCallout() 의 키('ResponseBody')와 다르므로 주의
     *
     * @param targetSystem  IF_System_Info__mdt.Name__c (ex. API_CRM_ZENT_KR)
     * @param ifId          IF_Table__c.Name (ex. IF_SFDC_BRICS_0011)
     * @param param         요청 파라미터
     *                        POST : JSON.serialize(reqObj)
     *                        GET  : buildQueryString(reqObj) → key=value&key=value
     * @return Object  Map<String, Object> { statusCode, resBody, error }
     **/
    @AuraEnabled
    public static Object doCallout(String targetSystem, String ifId, String param) {

        IF_Util             ifUtil = new IF_Util(targetSystem, ifId);
        Map<String, Object> resMap = ifUtil.getCallout(param);

        return new Map<String, Object>{
            'statusCode' => resMap.get('statusCode') + '',
            'resBody'    => resMap.get('ResponseBody'),
            'error'      => resMap.get('Error')
        };
    }

    /**
     * @description 인터페이스 호출과 로그 기록을 함께 처리합니다.
     *              단순 호출 결과를 Map 형태로 반환하며, 로그는 내부에서 자동 생성됩니다.
     *
     * @param targetSystem  IF_System_Info__mdt.Name__c
     * @param ifId          IF_Table__c.Name
     * @param logType       IF_Log 레코드 타입 (ex. 'Interface')
     * @param apexClass     호출한 Apex 클래스명
     * @param method        호출한 메서드명
     * @param paramObj      요청 파라미터 객체 (내부에서 JSON.serialize 처리)
     * @return Object       응답 Body를 JSON.deserializeUntyped 한 결과
     *                      오류 시 { resultCode: 'EE', resultMessage: 오류내용 }
     **/
    @AuraEnabled
    public static Object doCalloutLog(String targetSystem, String ifId, String logType,
                                       String apexClass, String method, Object paramObj) {
        Object              rtnObj = null;
        IF_Log              ifLog  = new IF_Log(logType, ifId, apexClass);
        String              param  = null;
        Map<String, Object> resMap = null;

        try {
            param          = JSON.serialize(paramObj);
            IF_Util ifUtil = new IF_Util(targetSystem, ifId);
            resMap         = ifUtil.getCallout(param);

            Object resBody    = resMap.get('ResponseBody');
            String statusCode = resMap.get('statusCode') + '';
            rtnObj = JSON.deserializeUntyped(resBody + '');

            if (statusCode == '200') {
                ifLog.setLog(logType, apexClass, method, ifLog.RESULT_TYPE_SUCCESS,
                             paramObj, rtnObj, null, 1, 1, 0);
            } else {
                ifLog.setLog(logType, apexClass, method, ifLog.RESULT_TYPE_FAIL,
                             paramObj, rtnObj, null, 1, 0, 1);
            }

        } catch (Exception e) {
            rtnObj = new Map<String, Object>{
                'resultCode'    => 'EE',
                'resultMessage' => e + ''
            };
            ifLog.setLog(logType, apexClass, method, ifLog.RESULT_TYPE_FAIL,
                         param, resMap, e, 1, 0, 1);
        } finally {
            ifLog.createLog();
        }

        return rtnObj;
    }
}

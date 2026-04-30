/**
 * @description       : 인터페이스 / 배치 로그 기록 클래스
 *                      IF_Log__c 오브젝트에 실행 결과를 기록하고,
 *                      요청/응답 데이터는 Attachment 로 저장합니다.
 *
 *                      [기본 사용 패턴]
 *                        IF_Log log = new IF_Log('Interface', 'IF_SFDC_BRICS_0011', 'IF_SFDC_BRICS_0011');
 *                        log.apexMethod  = 'sendRequest';
 *                        log.requestData = queryString;
 *                        log.resultType  = 'Success';
 *                        log.successCount = 1;
 *                        log.totalCount   = 1;
 *                        log.createLog(); // IF_Log__c 레코드 생성
 *
 * @author            : kilhwan.an@samhwa.com
 * @group             : Interface Common
 * @last modified on  : 2026-03-12
 * @last modified by  : kilhwan.an@samhwa.com
 **/
public without sharing class IF_Log {

    // ── 내부 필드 ────────────────────────────────────────────────────────
    private Id     recordTypeId;
    private String processId;
    private String apexClass;
    private Id     ifTableId;

    // ── 외부에서 직접 세팅하는 필드 ─────────────────────────────────────
    public String  message      { get; set; }  // 추가 기록할 로그 메세지
    public String  apexMethod   { get; set; }  // 실행 메서드명
    public String  requestData  { get; set; }  // 요청 데이터 (문자열)
    public String  responseData { get; set; }  // 응답 데이터 (문자열)
    public String  resultType   { get; set; }  // 처리 결과 : 'Success' / 'Fail'
    public String  errorMessage { get; set; }  // 오류 메세지
    public Integer successCount { get; set; }  // 성공 건수
    public Integer failCount    { get; set; }  // 실패 건수
    public Integer totalCount   { get; set; }  // 전체 건수

    public List<IF_Log> ifLogList;
    public String transactionNo;
    public String exceptionMessage;
    public String result;

    // resultType 상수
    public String RESULT_TYPE_SUCCESS = 'Success';
    public String RESULT_TYPE_FAIL    = 'fail';

    /**
     * @description 로그 객체를 초기화합니다.
     * @param rdName     IF_Log__c 레코드 타입명 (ex. 'Interface', 'Batch')
     * @param processId  인터페이스 ID 또는 배치 ID (IF_Table__c.Name 과 매핑)
     * @param apexClass  실행 중인 Apex 클래스명
     **/
    public IF_Log(String rdName, String processId, String apexClass) {
        this.recordTypeId = getIFLogRecordTypeId(rdName);

        for (IF_Table__c ifTable : [SELECT Id FROM IF_Table__c WHERE Name = :processId]) {
            this.ifTableId = ifTable.Id;
        }

        if (String.isBlank(processId)) processId = apexClass;
        this.processId    = processId;
        this.apexClass    = apexClass;
        this.totalCount   = 0;
        this.successCount = 0;
        this.failCount    = 0;
    }

    /**
     * @description 레코드 타입 ID를 조회합니다.
     * @param rdName 레코드 타입명
     * @return Id
     **/
    private Id getIFLogRecordTypeId(String rdName) {
        return IF_Log__c.SObjectType.getDescribe()
               .getRecordTypeInfosByName().get(rdName).getRecordTypeId();
    }

    /**
     * @description Attachment 객체를 생성합니다. (insert 는 하지 않음)
     * @param parentId 상위 레코드 ID
     * @param fileName 파일명 (ex. RequestData.json)
     * @param body     저장할 문자열 (6MB 초과 시 자동 절삭)
     * @return Attachment
     **/
    private Attachment getAttachment(Id parentId, String fileName, String body) {
        Attachment attach = new Attachment();
        attach.Name       = fileName;
        attach.ParentId   = parentId;
        if (body != null && body.length() > 6000000) {
            body = body.substring(0, 6000000);
        }
        attach.Body = Blob.valueOf(body);
        return attach;
    }

    private void setAttachment(Id parentId, String fileName, String body) {
        insert getAttachment(parentId, fileName, body);
    }

    /**
     * @description IF_Log 객체로부터 IF_Log__c SObject 를 생성합니다.
     *              130,000자 초과 시 자동 절삭합니다.
     * @param ifLog IF_Log 객체
     * @return IF_Log__c
     **/
    private IF_Log__c getIFLog(IF_Log ifLog) {
        IF_Log__c log            = new IF_Log__c();
        log.Name                 = ifLog.processId;
        log.IF_Table__c          = ifLog.ifTableId;
        log.RecordTypeId         = ifLog.recordTypeId;
        log.ApexClass__c         = ifLog.apexClass;
        log.ApexMethod__c        = ifLog.apexMethod;
        log.SuccessCount__c      = ifLog.successCount;
        log.FailCount__c         = ifLog.failCount;
        log.TotalCount__c        = ifLog.totalCount;
        log.ResultType__c        = ifLog.resultType;
        log.TransactionNo__c     = ifLog.transactionNo;
        log.ExceptionMessage__c  = ifLog.exceptionMessage;

        String req = ifLog.requestData;
        String res = ifLog.responseData;
        String err = ifLog.errorMessage;

        log.RequestData__c  = (String.isNotBlank(req) && req.length()  >= 130000) ? req.substring(0, 130000) : req;
        log.ResponseData__c = (String.isNotBlank(res) && res.length()  >= 130000) ? res.substring(0, 130000) : res;
        log.ErrorMessage__c = (String.isNotBlank(err) && err.length()  >= 130000) ? err.substring(0, 130000) : err;

        return log;
    }

    public IF_Log__c getIFLog() {
        return getIFLog(this);
    }

    /**
     * @description 복수 로그를 일괄 저장할 때 사용합니다.
     *              addLog() 로 누적 후 createListLog() 를 호출합니다.
     * @param log 추가할 IF_Log 객체
     **/
    public void addLog(IF_Log log) {
        if (ifLogList == null) ifLogList = new List<IF_Log>();
        ifLogList.add(log);
    }

    /**
     * @description addLog() 로 누적된 로그를 일괄 insert 합니다.
     *              요청/응답 데이터는 Attachment 로 저장됩니다.
     **/
    public void createListLog() {
        if (ifLogList == null) return;

        Map<String, IF_Log__c>  logMap    = new Map<String, IF_Log__c>();
        Map<String, Attachment> reqAttMap = new Map<String, Attachment>();
        Map<String, Attachment> resAttMap = new Map<String, Attachment>();

        for (IF_Log ifLog : ifLogList) {
            String uuId = UUID.randomUUID() + '';
            logMap.put(uuId, getIFLog(ifLog));
            reqAttMap.put(uuId, getAttachment(null, 'RequestData.json',  ifLog.requestData));
            resAttMap.put(uuId, getAttachment(null, 'ResponseData.json', ifLog.responseData));
        }

        insert logMap.values();

        List<Attachment> attList = new List<Attachment>();
        for (String key : logMap.keySet()) {
            Attachment reqAtt = reqAttMap.get(key);
            Attachment resAtt = resAttMap.get(key);
            reqAtt.ParentId   = logMap.get(key).Id;
            resAtt.ParentId   = logMap.get(key).Id;
            attList.add(reqAtt);
            attList.add(resAtt);
        }
        insert attList;
    }

    /**
     * @description 단건 로그를 생성하고 IF_Log__c 레코드를 insert 합니다.
     *              요청/응답 데이터는 Attachment 로 저장됩니다.
     **/
    public void createLog() {
        IF_Log__c log = getIFLog();
        insert log;

        if (log.ResponseData__c != null) setAttachment(log.Id, 'RequestData.json',  requestData);
        if (log.ResponseData__c != null) setAttachment(log.Id, 'ResponseData.json', responseData);
    }

    // ── setLog 오버로드 ─────────────────────────────────────────────────

    public IF_Log setIFLog(String apexMethod, Object reqData, List<Object> resData) {
        this.apexMethod   = apexMethod;
        this.requestData  = JSON.serialize(reqData);
        this.responseData = JSON.serialize(resData);
        this.successCount = resData.size();
        return this;
    }

    public IF_Log setIFLog(String apexMethod, Object reqData, Map<String, Object> resData, String resKey) {
        this.apexMethod   = apexMethod;
        this.requestData  = JSON.serialize(reqData);
        this.responseData = JSON.serialize(resData);
        String status     = resData.get('status') + '';

        if (status == '200') {
            Object resObj        = resData.get(resKey);
            this.resultType      = RESULT_TYPE_SUCCESS;
            this.successCount    = (resObj != null) ? ((List<Object>) resObj).size() : 0;
        } else {
            this.resultType   = RESULT_TYPE_FAIL;
            this.errorMessage = resData.get('ERROR') + '';
        }
        return this;
    }

    public void setLog(String rdName, String apexClass, String apexMethod, String resultType,
                       Object requestData, Object responseData, Exception ex,
                       Integer totalCount, Integer successCount, Integer failCount) {
        this.recordTypeId = getIFLogRecordTypeId(rdName);
        this.apexClass    = apexClass;
        this.apexMethod   = apexMethod;
        this.requestData  = JSON.serialize(requestData);
        this.responseData = JSON.serialize(responseData);
        this.resultType   = resultType;
        this.successCount = successCount;
        this.failCount    = failCount;
        this.totalCount   = totalCount;
        this.errorMessage = (ex == null) ? '' : ex + '';
    }

    public void setLog(String transactionNo, String rdName, String apexClass, String apexMethod,
                       String resultType, Object requestData, Object responseData, Exception ex,
                       Integer totalCount, Integer successCount, Integer failCount) {
        this.transactionNo = transactionNo;
        this.recordTypeId  = getIFLogRecordTypeId(rdName);
        this.apexClass     = apexClass;
        this.apexMethod    = apexMethod;
        this.requestData   = JSON.serialize(requestData);
        this.responseData  = JSON.serialize(responseData);
        this.resultType    = resultType;
        this.successCount  = successCount;
        this.failCount     = failCount;
        this.totalCount    = totalCount;
        this.errorMessage  = (ex == null) ? '' : ex.getStackTraceString();
    }
}

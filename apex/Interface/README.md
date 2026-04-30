# 신규 인터페이스 작성 가이드

## Step 1. IF_Table__c 레코드 생성

Salesforce Setup > Custom Objects > IF_Table__c 에서 신규 레코드를 생성합니다.

| 필드 | 입력값 |
|---|---|
| `Name` | `IF_SFDC_BRICS_XXXX` (인터페이스 ID) |
| `Method__c` | `GET` 또는 `POST` |
| `Path__c` | `/v1/your-path` |
| `ContentType__c` | `application/json` ← **GET이라도 반드시 입력** |
| `AddHeader__c` | 추가 헤더 필요 시 JSON 형식으로 입력 (선택) |

---

## Step 2. 인터페이스 클래스 작성

`IF_SFDC_BRICS_0011.cls`를 복사하여 클래스명과 상수만 변경합니다.

```apex
private final String APEX_CLASS    = 'IF_SFDC_BRICS_XXXX'; // ← 변경
private final String INTERFACE_ID  = 'IF_SFDC_BRICS_XXXX'; // ← 변경
private final String TARGET_SYSTEM = 'API_CRM_ZENT_KR';     // 시스템명 (변경 불필요 시 유지)
private final String LOG_TYPE      = 'Interface';            // 변경 불필요
```

---

## Step 3. Request / Response Inner Class 정의

### GET 방식 (Query String)
```apex
public class XxxRequest {
    public String paramA;
    public String paramB;
    // ⚠️ 'limit', 'select', 'from' 등 Apex 예약어는 사용 불가
    //    ex) limit → limitCount 로 대체 후 buildQueryString 에서 'limit' 으로 변환
}
```

### POST 방식 (JSON Body)
```apex
public class XxxRequest {
    public String paramA;
    public String paramB;
}
// → JSON.serialize(req) 로 Body 구성
```

---

## Step 4. GET vs POST 파라미터 구성

### GET - buildQueryString 사용
```apex
// IF_Util 이 내부적으로 endpoint + '?' + param 으로 URL 조합
String queryString = buildQueryString(reqPayload);
Map<String, Object> response = (Map<String, Object>) IF_CalloutUtil.doCallout(
    TARGET_SYSTEM, INTERFACE_ID, queryString
);
```

### POST - JSON.serialize 사용
```apex
// IF_Util 이 내부적으로 req.setBody(param) 으로 Body 세팅
String reqBody = JSON.serialize(reqPayload);
Map<String, Object> response = (Map<String, Object>) IF_CalloutUtil.doCallout(
    TARGET_SYSTEM, INTERFACE_ID, reqBody
);
```

---

## Step 5. 응답 처리

```apex
Integer status = Integer.valueOf(String.valueOf(response.get('statusCode')));
String resBody = (String) response.get('resBody'); // 'ResponseBody' 아님 주의

if (status / 100 == 2) {
    XxxResponse resData = (XxxResponse) JSON.deserialize(resBody, XxxResponse.class);
    if (resData.code == 200) {
        // 성공 처리
    }
} else if (status == 999) {
    // IF_Util 내부 Exception 발생 케이스
    String errDetail = (String) response.get('error');
}
```

---

## Step 6. Anonymous Apex 테스트

```apex
IF_SFDC_BRICS_XXXX ifClass = new IF_SFDC_BRICS_XXXX();
IF_SFDC_BRICS_XXXX.XxxRequest req = new IF_SFDC_BRICS_XXXX.XxxRequest();
req.paramA = 'testValue';

Map<String, Object> result = ifClass.sendRequest(req);
System.debug('STATUS : ' + result.get('STATUS_CODE'));
System.debug('ERROR  : ' + result.get('ERROR_MSG'));
System.debug('DATA   : ' + result.get('RESULT_DATA'));
```

---

## ⚠️ 자주 실수하는 포인트

| 항목 | 잘못된 예 | 올바른 예 |
|---|---|---|
| 응답 Body 키 | `response.get('ResponseBody')` | `response.get('resBody')` |
| Apex 예약어 필드 | `public String limit` | `public String limitCount` |
| ContentType 누락 | IF_Table__c 에 값 없음 | `application/json` 입력 필수 |
| GET 파라미터 방식 | `JSON.serialize(req)` | `buildQueryString(req)` |

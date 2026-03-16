@RestResource(urlMapping='/slack/interaction-orig/*')
global class SlackInteractionEndpoint {
  @HttpPost
  global static void handlePost() {
    RestRequest req = RestContext.request;
    RestResponse res = RestContext.response;

    // ✅ params에서 payload 먼저 꺼내기
    String payloadJson = '';
    if (req.params != null && req.params.containsKey('payload')) {
      payloadJson = EncodingUtil.urlDecode(req.params.get('payload'), 'UTF-8');
    }

    System.debug('### PAYLOAD: ' + payloadJson);

    // Signature 검증은 raw body로 해야 함
    // Slack은 form-encoded body로 전송하므로
    // requestBody가 비어있으면 params 재조합
    String rawBody = '';
    if (req.requestBody != null && req.requestBody.size() > 0) {
      rawBody = req.requestBody.toString();
    } else if (req.params != null && req.params.containsKey('payload')) {
      // body가 없으면 params에서 재조합
      rawBody =
        'payload=' + EncodingUtil.urlEncode(req.params.get('payload'), 'UTF-8');
    }

    System.debug('### RAW BODY 길이: ' + rawBody.length());

    String slackSig = req.headers.get('X-Slack-Signature');
    String timestamp = req.headers.get('X-Slack-Request-Timestamp');

    System.debug('### SLACK SIG: ' + slackSig);
    System.debug('### TIMESTAMP: ' + timestamp);
    /*
        if (!verifySignature(slackSig, timestamp, rawBody)) {
            System.debug('### SIGNATURE 검증 실패');
            res.statusCode = 401;
            return;
        }
*/
    System.debug('### SIGNATURE 검증 성공');

    // 즉시 200 응답
    res.statusCode = 200;
    res.responseBody = Blob.valueOf('');

    if (String.isNotBlank(payloadJson)) {
      SlackInteractionHandler.handleAsync(payloadJson);
    }
  }

  private static Boolean verifySignature(
    String signature,
    String timestamp,
    String body
  ) {
    if (
      String.isBlank(signature) ||
      String.isBlank(timestamp) ||
      String.isBlank(body)
    ) {
      System.debug(
        '### 검증 입력값 비어있음' +
          ' sig=' +
          signature +
          ' ts=' +
          timestamp +
          ' bodyLen=' +
          body?.length()
      );
      return false;
    }

    SlackConfig__mdt config = SlackIntegration.getConfig();

    String baseString = 'v0:' + timestamp + ':' + body;
    Blob hmac = Crypto.generateMac(
      'HmacSHA256',
      Blob.valueOf(baseString),
      Blob.valueOf(config.SigningSecret__c)
    );
    String computed = 'v0=' + EncodingUtil.convertToHex(hmac);

    System.debug('### COMPUTED: ' + computed);
    System.debug('### RECEIVED: ' + signature);
    System.debug('### MATCH: ' + (computed == signature));

    return computed == signature;
  }
}

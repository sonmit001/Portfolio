public with sharing class SampleFormController {

    /* ===============================
     * ENUM
     * =============================== */
    public enum RequestType {
        PHOTO,
        MAIL,
        MAIL_SIMPLE,
        APARTMENT,
        DOCUMENT
    }

    /* ===============================
     * REMOTE ACTIONS
     * =============================== */

    /**
     * Uploads a single file to a Case record
     */
    @RemoteAction
    public static String uploadFile(
        Id caseId,
        String base64Content,
        String typeValue,
        Integer sequence
    ) {
        validateUpload(caseId, base64Content, typeValue);

        RequestType typeEnum = RequestType.valueOf(typeValue);

        ContentVersion cv = new ContentVersion(
            Title = buildFileTitle(typeEnum, sequence),
            PathOnClient = buildFileName(typeEnum, sequence),
            VersionData = EncodingUtil.base64Decode(base64Content),
            IsMajorVersion = true,
            Origin = 'H',
            FirstPublishLocationId = caseId
        );

        insert cv;
        return 'SUCCESS';
    }

    /**
     * Updates Case description with structured message
     */
    @RemoteAction
    public static String updateCase(
        Id caseId,
        String jsonPayload,
        String typeValue
    ) {
        Case target = [
            SELECT Id, Description
            FROM Case
            WHERE Id = :caseId
            LIMIT 1
        ];

        String message = buildMessage(
            RequestType.valueOf(typeValue),
            jsonPayload
        );

        if (String.isNotBlank(message)) {
            target.Description =
                String.isBlank(target.Description)
                ? message
                : target.Description + '\n\n' + message;
            update target;
        }

        sendNotification(caseId, typeValue);
        return 'SUCCESS';
    }

    /* ===============================
     * PRIVATE HELPERS
     * =============================== */

    private static void validateUpload(
        Id caseId,
        String content,
        String typeValue
    ) {
        if (caseId == null)
            throw new AuraHandledException('Missing Case Id');
        if (String.isBlank(content))
            throw new AuraHandledException('Empty file content');
        if (String.isBlank(typeValue))
            throw new AuraHandledException('Missing request type');
    }

    private static String buildFileTitle(
        RequestType typeEnum,
        Integer seq
    ) {
        return typeEnum.name() + '_' +
               DateTime.now().format('yyyyMMddHHmmss') +
               '_' + seq;
    }

    private static String buildFileName(
        RequestType typeEnum,
        Integer seq
    ) {
        return buildFileTitle(typeEnum, seq) + '.jpg';
    }

    private static String buildMessage(
        RequestType typeEnum,
        String jsonPayload
    ) {
        String timestamp =
            '[' + DateTime.now().format('yyyy-MM-dd HH:mm:ss') + ']';

        if (String.isBlank(jsonPayload))
            return timestamp + ' Request submitted';

        Map<String, Object> data =
            (Map<String, Object>) JSON.deserializeUntyped(jsonPayload);

        List<String> lines = new List<String>();
        lines.add(timestamp + ' ' + typeEnum.name() + ' Request');

        for (String key : data.keySet()) {
            lines.add(key + ': ' + String.valueOf(data.get(key)));
        }

        return String.join(lines, '\n');
    }

    private static void sendNotification(
        Id caseId,
        String typeValue
    ) {
        try {
            Messaging.CustomNotification noti =
                new Messaging.CustomNotification();
            noti.setTitle('New Request Submitted');
            noti.setBody(typeValue + ' request received');
            noti.setTargetId(caseId);
            noti.send(new Set<String>{UserInfo.getUserId()});
        } catch (Exception e) {
            // Notification failure should not break transaction
        }
    }
}

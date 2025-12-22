/**
 * @description External OAuth 2.0 Authentication Service (Portfolio Version)
 * @author Portfolio
 * @last update 2025-11-25
 * @tester class OAuthAuthServiceTest
 */
public with sharing class OAuthAuthService {

    private static final Boolean IS_DEBUG_MODE = true;
    private static final String GRANT_TYPE = 'client_credentials';
    private static final Integer TIMEOUT_MS = 120000;
    private static final String TOKEN_ENDPOINT = '/oauth/token';

    @TestVisible
    private static Map<String, OAuthConnection__mdt> testConnectionInfoMap;

    @TestVisible
    private static Map<String, CachedToken> tokenCache = new Map<String, CachedToken>();

    private static final Integer DEFAULT_CACHE_TTL_SECONDS = 3600;

    @TestVisible
    private static String lastAccessToken;

    @TestVisible
    private static Integer lastAccessTokenExpiresIn;

    /* ================================
     * Public Entry
     * ================================ */

    public static OAuthAuthResponse authenticate(String configName) {
        if (String.isBlank(configName)) {
            throw new OAuthAuthException('Configuration name is required');
        }

        CachedToken cached = getValidCachedToken(configName);
        if (cached != null) {
            debug(LoggingLevel.INFO, 'Using cached access token');
            return cached.response;
        }

        OAuthConnection__mdt connInfo = getConnectionInfo(configName);
        if (connInfo == null) {
            throw new OAuthAuthException('OAuth configuration not found');
        }

        return requestAccessToken(configName, connInfo);
    }

    /* ================================
     * Metadata Access
     * ================================ */

    @TestVisible
    private static OAuthConnection__mdt getConnectionInfo(String configName) {
        if (testConnectionInfoMap != null && testConnectionInfoMap.containsKey(configName)) {
            return testConnectionInfoMap.get(configName);
        }

        List<OAuthConnection__mdt> results = [
            SELECT
                clientKey__c,
                clientSecret__c,
                authDomain__c,
                apiBaseUrl__c,
                DeveloperName
            FROM OAuthConnection__mdt
            WHERE DeveloperName = :configName
            LIMIT 1
        ];

        return results.isEmpty() ? null : results[0];
    }

    /* ================================
     * OAuth Token Request
     * ================================ */

    @TestVisible
    private static OAuthAuthResponse requestAccessToken(
        String configName,
        OAuthConnection__mdt connInfo
    ) {
        String endpoint = buildAuthUrl(connInfo.authDomain__c);

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(TIMEOUT_MS);

        Map<String, String> body = new Map<String, String>{
            'grant_type' => GRANT_TYPE,
            'client_id' => connInfo.clientKey__c,
            'client_secret' => connInfo.clientSecret__c
        };
        req.setBody(JSON.serialize(body));

        Http http = new Http();
        HttpResponse res;

        try {
            res = http.send(req);
        } catch (Exception e) {
            throw new OAuthAuthException('OAuth HTTP request failed', e);
        }

        return handleResponse(configName, res, connInfo);
    }

    /* ================================
     * URL Builders
     * ================================ */

    private static String buildAuthUrl(String authDomain) {
        if (String.isBlank(authDomain)) {
            throw new OAuthAuthException('Auth domain is required');
        }
        return 'https://' + authDomain + TOKEN_ENDPOINT;
    }

    /* ================================
     * Response Handling
     * ================================ */

    @TestVisible
    private static OAuthAuthResponse handleResponse(
        String configName,
        HttpResponse res,
        OAuthConnection__mdt connInfo
    ) {
        if (res.getStatusCode() != 200) {
            throw new OAuthAuthException(
                'OAuth authentication failed: ' + res.getStatusCode()
            );
        }

        Map<String, Object> payload =
            (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        String accessToken = (String) payload.get('access_token');
        Integer expiresIn = (Integer) payload.get('expires_in');

        OAuthAuthResponse response = new OAuthAuthResponse(
            true,
            accessToken,
            expiresIn,
            connInfo.apiBaseUrl__c,
            'Authentication successful'
        );

        cacheToken(configName, response);
        lastAccessToken = accessToken;
        lastAccessTokenExpiresIn = expiresIn;

        return response;
    }

    /* ================================
     * Token Cache
     * ================================ */

    private static CachedToken getValidCachedToken(String key) {
        CachedToken cached = tokenCache.get(key);
        if (cached != null && cached.isValid()) {
            return cached;
        }
        tokenCache.remove(key);
        return null;
    }

    private static void cacheToken(String key, OAuthAuthResponse response) {
        if (response == null || String.isBlank(response.accessToken)) {
            return;
        }

        Integer ttl = response.expiresIn != null
            ? Math.max(0, response.expiresIn)
            : DEFAULT_CACHE_TTL_SECONDS;

        tokenCache.put(
            key,
            new CachedToken(response, Datetime.now().addSeconds(ttl))
        );
    }

    /* ================================
     * Inner Classes
     * ================================ */

    private class CachedToken {
        private OAuthAuthResponse response;
        private Datetime expiresAt;

        CachedToken(OAuthAuthResponse response, Datetime expiresAt) {
            this.response = response;
            this.expiresAt = expiresAt;
        }

        Boolean isValid() {
            return response != null
                && !String.isBlank(response.accessToken)
                && expiresAt != null
                && expiresAt >= Datetime.now();
        }
    }

    private static void debug(LoggingLevel level, String msg) {
        if (IS_DEBUG_MODE) {
            System.debug(level, msg);
        }
    }

    public class OAuthAuthException extends Exception {}
}

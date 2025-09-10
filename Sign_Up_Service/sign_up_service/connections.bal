import ballerinax/salesforce;

// Salesforce Client
final salesforce:Client salesforceClient = check new ({
    baseUrl: salesforceBaseUrl,
    auth: {
        refreshUrl: salesforceRefreshUrl,
        refreshToken: salesforceRefreshToken,
        clientId: salesforceClientId,
        clientSecret: salesforceClientSecret
    }
});

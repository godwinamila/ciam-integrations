import ballerina/http;

// HTTP client for Microsoft Graph API
http:Client graphClient = check new ("https://graph.microsoft.com/v1.0", 
    config = {
        timeout: 30
    }
);

// HTTP client for OAuth2 token endpoint
http:Client tokenClient = check new (string `https://login.microsoftonline.com/${tenantId}`, 
    config = {
        timeout: 30
    }
);
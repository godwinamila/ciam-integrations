import ballerina/log;
import ballerina/lang.value;

// Function to get current access token using client credentials
function getRootAccessToken() returns string|error {
    string credentials = string `${asgardeoClientId}:${asgardeoClientSecret}`;
    string encodedCredentials = credentials.toBytes().toBase64();

    map<string|string[]> headers = {
        "Authorization": string `Basic ${encodedCredentials}`,
        "Content-Type": "application/x-www-form-urlencoded"
    };

    string requestBody = string `grant_type=client_credentials&scope=${asgardeoScopes}`;

    TokenResponse|error response = asgardeoClient->post("/oauth2/token", requestBody, headers = headers);

    if response is error {
        log:printError(string`Error getting current access token: - ${response.detail().toString()}`);
        return response;
    }

    log:printDebug("API Response - getCurrentAccessToken: " + value:toJsonString(response));
    return response.access_token;
}

// Function to switch token to organization context
function switchToOrganizationToken(string organizationId) returns string|error {
    // Get current access token
    string|error currentToken = getRootAccessToken();
    if currentToken is error {
        return currentToken;
    }

    string credentials = string `${asgardeoClientId}:${asgardeoClientSecret}`;
    string encodedCredentials = credentials.toBytes().toBase64();

    map<string|string[]> headers = {
        "Authorization": string `Basic ${encodedCredentials}`,
        "Content-Type": "application/x-www-form-urlencoded"
    };

    string requestBody = string `grant_type=organization_switch&token=${currentToken}&scope=${orgSwitchScopes}&switching_organization=${organizationId}`;

    TokenResponse|error response = asgardeoClient->post("/oauth2/token", requestBody, headers = headers);

    if response is error {
        log:printError(string`Error switching to organization token: - ${response.detail().toString()}`);
        return response;
    }

    log:printDebug("API Response - switchToOrganizationToken: " + value:toJsonString(response));
    log:printInfo("Successfully switched to organization token for org: " + organizationId);
    return response.access_token;
}
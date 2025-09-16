import ballerina/http;
import ballerina/log;

// Function to get OAuth2 access token using client credentials
public function getAccessToken() returns string|error {
    string tokenRequestBody = string `grant_type=client_credentials&client_id=${clientId}&client_secret=${clientSecret}&scope=https://graph.microsoft.com/.default`;

    http:Response|error tokenResponse = tokenClient->post(path = "/oauth2/v2.0/token",
        message = tokenRequestBody,
        headers = {"Content-Type": "application/x-www-form-urlencoded"}
    );

    if tokenResponse is error {
        log:printError(string `Failed to get access token: ${tokenResponse.message()}`);
        return tokenResponse;
    }

    json|error tokenJson = tokenResponse.getJsonPayload();
    if tokenJson is error {
        log:printError(string `Failed to parse token response: ${tokenJson.message()}`);
        return tokenJson;
    }

    TokenResponse|error tokenData = tokenJson.cloneWithType();
    if tokenData is error {
        log:printError(string `Failed to convert token data: ${tokenData.message()}`);
        return tokenData;
    }

    log:printInfo("Successfully obtained access token");
    return tokenData.access_token;
}

// Function to create Azure AD user
public function createAzureUser(AzureUserData userData, string accessToken) returns AzureUserResponse|error {

    AzureUserRequest userRequest = {
        accountEnabled: userData.accountEnabled,
        displayName: userData.displayName,
        userPrincipalName: userData.userPrincipalName,
        mail: userData.mail,
        mailNickname: userData.mailNickname,
        passwordProfile: {
            password: "Test@123",
            forceChangePasswordNextSignIn: true
        }
    };

    log:printInfo(string `Creating Azure user: ${userData.displayName} (${userData.mail})`);

    http:Response|error response = graphClient->post(path = "/users",
        message = userRequest,
        headers = {
        "Authorization": string `Bearer ${accessToken}`,
        "Content-Type": "application/json"
    }
    );

    if response is error {
        log:printError(string `HTTP error creating user ${userData.displayName}: ${response.message()}`);
        return response;
    }

    if response.statusCode != 201 {
        json|error errorPayload = response.getJsonPayload();
        string errorMessage = errorPayload is json ? errorPayload.toString() : "Unknown error";
        string logMessage = string `Failed to create user ${userData.displayName}. Status: ${response.statusCode}, Error: ${errorMessage}`;
        log:printError(logMessage);
        return error(logMessage);
    }

    json|error userJson = response.getJsonPayload();
    if userJson is error {
        log:printError(string `Failed to parse user creation response for ${userData.displayName}: ${userJson.message()}`);
        return userJson;
    }

    AzureUserResponse|error createdUser = userJson.cloneWithType();
    if createdUser is error {
        log:printError(string `Failed to convert user response for ${userData.displayName}: ${createdUser.message()}`);
        return createdUser;
    }

    string userId = createdUser.id ?: "Unknown ID";
    log:printInfo(string `Successfully created user: ${userData.displayName} with ID: ${userId}`);
    return createdUser;
}
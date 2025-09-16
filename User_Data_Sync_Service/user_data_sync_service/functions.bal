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

// Function to get Azure AD user object ID by UPN
public function getAzureUserObjectId(string userPrincipalName, string accessToken) returns string|error {
    
    log:printInfo(string `Looking up Azure user object ID for UPN: ${userPrincipalName}`);

    // Use $filter to find user by userPrincipalName
    string filterQuery = string `userPrincipalName eq '${userPrincipalName}'`;
    string encodedFilter = filterQuery; // In a real implementation, you might need URL encoding
    
    http:Response|error response = graphClient->get(path = string `/users?$filter=${encodedFilter}&$select=id,userPrincipalName`,
        headers = {
            "Authorization": string `Bearer ${accessToken}`,
            "Content-Type": "application/json"
        }
    );

    if response is error {
        log:printError(string `HTTP error looking up user ${userPrincipalName}: ${response.message()}`);
        return response;
    }

    if response.statusCode != 200 {
        json|error errorPayload = response.getJsonPayload();
        string errorMessage = errorPayload is json ? errorPayload.toString() : "Unknown error";
        string logMessage = string `Failed to lookup user ${userPrincipalName}. Status: ${response.statusCode}, Error: ${errorMessage}`;
        log:printError(logMessage);
        return error(logMessage);
    }

    json|error userJson = response.getJsonPayload();
    if userJson is error {
        log:printError(string `Failed to parse user lookup response for ${userPrincipalName}: ${userJson.message()}`);
        return userJson;
    }

    AzureUserSearchResponse|error searchResponse = userJson.cloneWithType();
    if searchResponse is error {
        log:printError(string `Failed to convert user search response for ${userPrincipalName}: ${searchResponse.message()}`);
        return searchResponse;
    }

    // Check if user was found
    AzureUserInfo[]? users = searchResponse.value;
    if users is () || users.length() == 0 {
        string notFoundMessage = string `User not found in Azure AD: ${userPrincipalName}`;
        log:printError(notFoundMessage);
        return error(notFoundMessage);
    }

    AzureUserInfo userInfo = users[0];
    string? objectId = userInfo.id;
    if objectId is () {
        string noIdMessage = string `User found but no object ID returned for: ${userPrincipalName}`;
        log:printError(noIdMessage);
        return error(noIdMessage);
    }

    log:printInfo(string `Found Azure user object ID: ${objectId} for UPN: ${userPrincipalName}`);
    return objectId;
}

// Function to create Azure AD user
public function createAzureUser(AzureUserData userData, string accessToken) returns AzureUserResponse|error {

    // Conditionally create user request with country field only if it exists in userData
    AzureUserRequest userRequest;
    string? userCountry = userData.country;
    if userCountry is string {
        userRequest = {
            accountEnabled: userData.accountEnabled,
            displayName: userData.givenName + " " + userData.surname,
            userPrincipalName: userData.userPrincipalName,
            mail: userData.mail,
            mailNickname: userData.mailNickname,
            passwordProfile: {
                password: "Test@123",
                forceChangePasswordNextSignIn: true
            },
            country: userCountry
        };
    } else {
        userRequest = {
            accountEnabled: userData.accountEnabled,
            displayName: userData.givenName + " " + userData.surname,
            userPrincipalName: userData.userPrincipalName,
            mail: userData.mail,
            mailNickname: userData.mailNickname,
            passwordProfile: {
                password: "Test@123",
                forceChangePasswordNextSignIn: true
            }
        };
    }

    log:printInfo(string `Creating Azure user: ${userData.givenName} (${userData.mail})`);

    http:Response|error response = graphClient->post(path = "/users",
        message = userRequest,
        headers = {
        "Authorization": string `Bearer ${accessToken}`,
        "Content-Type": "application/json"
    }
    );

    if response is error {
        log:printError(string `HTTP error creating user ${userData.mail}: ${response.message()}`);
        return response;
    }

    if response.statusCode != 201 {
        json|error errorPayload = response.getJsonPayload();
        string errorMessage = errorPayload is json ? errorPayload.toString() : "Unknown error";
        string logMessage = string `Failed to create user ${userData.mail}. Status: ${response.statusCode}, Error: ${errorMessage}`;
        log:printError(logMessage);
        return error(logMessage);
    }

    json|error userJson = response.getJsonPayload();
    if userJson is error {
        log:printError(string `Failed to parse user creation response for ${userData.mail}: ${userJson.message()}`);
        return userJson;
    }

    AzureUserResponse|error createdUser = userJson.cloneWithType();
    if createdUser is error {
        log:printError(string `Failed to convert user response for ${userData.mail}: ${createdUser.message()}`);
        return createdUser;
    }

    string userId = createdUser.id ?: "Unknown ID";
    log:printInfo(string `Successfully created user: ${userData.mail} with ID: ${userId}`);
    return createdUser;
}

// Function to update Azure AD user profile using object ID
public function updateAzureUserProfile(string asgardeoUserId, AzureUserUpdateRequest updateRequest, string accessToken) returns error? {
    
    // Construct Azure UPN from Asgardeo user ID
    string azureUpn = asgardeoUserId + "#EXT#@" + issuerDomain;
    
    // Get the Azure AD object ID for the user
    string|error objectId = getAzureUserObjectId(userPrincipalName = azureUpn, accessToken = accessToken);
    if objectId is error {
        log:printError(string `Failed to get object ID for user ${azureUpn}: ${objectId.message()}`);
        return objectId;
    }
    
    log:printInfo(string `Updating Azure user profile using object ID: ${objectId}`);

    http:Response|error response = graphClient->patch(path = string `/users/${objectId}`,
        message = updateRequest,
        headers = {
            "Authorization": string `Bearer ${accessToken}`,
            "Content-Type": "application/json"
        }
    );

    if response is error {
        log:printError(string `HTTP error updating user ${objectId}: ${response.message()}`);
        return response;
    }

    if response.statusCode != 204 {
        json|error errorPayload = response.getJsonPayload();
        string errorMessage = errorPayload is json ? errorPayload.toString() : "Unknown error";
        string logMessage = string `Failed to update user ${objectId}. Status: ${response.statusCode}, Error: ${errorMessage}`;
        log:printError(logMessage);
        return error(logMessage);
    }

    log:printInfo(string `Successfully updated profile for user with object ID: ${objectId}`);
    return;
}

// Function to delete Azure AD user using object ID
public function deleteAzureUser(string asgardeoUserId, string accessToken) returns error? {
    
    // Construct Azure UPN from Asgardeo user ID
    string azureUpn = asgardeoUserId + "#EXT#@" + issuerDomain;
    
    // Get the Azure AD object ID for the user
    string|error objectId = getAzureUserObjectId(userPrincipalName = azureUpn, accessToken = accessToken);
    if objectId is error {
        log:printError(string `Failed to get object ID for user ${azureUpn}: ${objectId.message()}`);
        return objectId;
    }
    
    log:printInfo(string `Deleting Azure user using object ID: ${objectId}`);

    http:Response|error response = graphClient->delete(path = string `/users/${objectId}`,
        headers = {
            "Authorization": string `Bearer ${accessToken}`,
            "Content-Type": "application/json"
        }
    );

    if response is error {
        log:printError(string `HTTP error deleting user ${objectId}: ${response.message()}`);
        return response;
    }

    if response.statusCode != 204 {
        json|error errorPayload = response.getJsonPayload();
        string errorMessage = errorPayload is json ? errorPayload.toString() : "Unknown error";
        string logMessage = string `Failed to delete user ${objectId}. Status: ${response.statusCode}, Error: ${errorMessage}`;
        log:printError(logMessage);
        return error(logMessage);
    }

    log:printInfo(string `Successfully deleted user with object ID: ${objectId}`);
    return;
}
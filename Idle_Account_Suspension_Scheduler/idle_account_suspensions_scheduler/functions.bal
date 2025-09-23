import ballerina/http;
import ballerina/log;
import ballerina/lang.value;
import ballerina/time;
import ballerina/io;

// Function to check if a user should be skipped for disable operation
function shouldSkipUserForDisable(InactiveUser user) returns boolean {
    // Skip users with 'abb.com' in their username
    boolean hasAbbDomain = user.username.includes("abb.com");
    
    if hasAbbDomain {
        log:printInfo("Skipping user with abb.com domain: " + user.username);
        return true;
    }
    
    return false;
}

// Function to get current access token using client credentials
function getCurrentAccessToken() returns string|error {
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

// Function to calculate inactive after date
function calculateInactiveAfterDate() returns string {
    time:Utc currentTime = time:utcNow();
    int thresholdTimestamp = currentTime[0] - (inactiveDaysThreshold * 24 * 60 * 60);
    time:Utc thresholdTime = [thresholdTimestamp, currentTime[1]];
    
    // Convert to string format YYYY-MM-DD
    string thresholdDateString = time:utcToString(thresholdTime);
    // Extract date part (first 10 characters: YYYY-MM-DD)
    string inactiveAfterDate = thresholdDateString.substring(startIndex = 0, endIndex = 10);
    
    // Log the specific message requested
    log:printInfo("Obtaining inactive users after date: " + inactiveAfterDate);
    
    return inactiveAfterDate;
}

// Function to get inactive users
function getInactiveUsers() returns InactiveUsersResponse|error {
    // Get access token
    string|error accessToken = getCurrentAccessToken();
    if accessToken is error {
        return error("Failed to get access token: " + accessToken.message());
    }

    // Calculate inactive after date
    string inactiveAfterDate = calculateInactiveAfterDate();
    
    // Prepare headers
    map<string|string[]> headers = {
        "Authorization": "Bearer " + accessToken,
        "Content-Type": "application/json"
    };
    
    // Make API call
    string requestPath = inactiveUsersApiPath + "?inactiveAfter=" + inactiveAfterDate;
    http:Response|error response = asgardeoClient->get(path = requestPath, headers = headers);
    
    if response is error {
        log:printError(string`Failed to call inactive users API: - ${response.detail().toString()}`);
        return error("Failed to call inactive users API: " + response.message());
    }
    
    // Parse response
    json|error jsonPayload = response.getJsonPayload();
    if jsonPayload is error {
        log:printError("Failed to parse API response: " + jsonPayload.message());
        return error("Failed to parse API response: " + jsonPayload.message());
    }
    
    log:printDebug("API Response - getInactiveUsers: " + value:toJsonString(jsonPayload));
    
    // Convert JSON to typed record
    InactiveUsersResponse|error inactiveUsers = value:cloneWithType(jsonPayload, InactiveUsersResponse);
    if inactiveUsers is error {
        log:printError("Failed to convert response to InactiveUsersResponse: " + inactiveUsers.message());
        return error("Failed to convert response to InactiveUsersResponse: " + inactiveUsers.message());
    }
    
    return inactiveUsers;
}

// Function to disable a user via SCIM API using the specific format
function disableUser(string userId, string accessToken) returns error? {

    // Prepare SCIM patch request to disable user using the exact format from curl
    ScimPatchRequest patchRequest = {
        Operations: [
            {
                op: "replace",
                path: "urn:scim:wso2:schema:accountDisabled",
                value: true
            }
        ],
        schemas: [
            "urn:ietf:params:scim:api:messages:2.0:PatchOp"
        ]
    };

    map<string|string[]> headers = {
        "Authorization": "Bearer " + accessToken,
        "Content-Type": "application/json"
    };

    string requestPath = usersApiPath + "/" + userId;
    
    log:printInfo("Disabling user via SCIM API: " + userId);
    log:printDebug("SCIM PATCH request: " + value:toJsonString(patchRequest));

    http:Response|error response = asgardeoClient->patch(path = requestPath, message = patchRequest, headers = headers);

    if response is error {
        log:printError("Failed to disable user " + userId + ": " + response.message());
        return error("Failed to disable user: " + response.message());
    }

    int statusCode = response.statusCode;
    if statusCode >= 200 && statusCode < 300 {
        log:printInfo("Successfully disabled user: " + userId);
    } else {
        string errorMsg = "Failed to disable user " + userId + ". Status code: " + statusCode.toString();
        log:printError(errorMsg);
        return error(errorMsg);
    }
}

// Function to delete a user via SCIM API
function deleteUser(string userId, string accessToken) returns error? {

    map<string|string[]> headers = {
        "Authorization": "Bearer " + accessToken,
        "Content-Type": "application/json"
    };

    string requestPath = usersApiPath + "/" + userId;
    
    log:printInfo("Deleting user via SCIM API: " + userId);

    http:Response|error response = asgardeoClient->delete(path = requestPath, headers = headers);

    if response is error {
        log:printError("Failed to delete user " + userId + ": " + response.message());
        return error("Failed to delete user: " + response.message());
    }

    int statusCode = response.statusCode;
    if statusCode >= 200 && statusCode < 300 {
        log:printInfo("Successfully deleted user: " + userId);
    } else {
        string errorMsg = "Failed to delete user " + userId + ". Status code: " + statusCode.toString();
        log:printError(errorMsg);
        return error(errorMsg);
    }
}

// Function to disable users individually with filtering
function disableUsers(InactiveUsersResponse inactiveUsers) returns OperationResult|error {
    string|error accessToken = getCurrentAccessToken();
    if accessToken is error {
        return error("Failed to get access token for disable operation: " + accessToken.message());
    }

    OperationResult result = {
        totalUsers: inactiveUsers.length(),
        successCount: 0,
        failureCount: 0,
        skippedCount: 0,
        failedUsers: [],
        skippedUsers: []
    };

    log:printInfo("Starting disable operation for " + inactiveUsers.length().toString() + " users");
    log:printInfo("Users with 'abb.com' in username will be skipped");

    foreach InactiveUser user in inactiveUsers {
        log:printInfo("Processing user: " + user.username + " (ID: " + user.userId + ")");
        
        // Check if user should be skipped
        if shouldSkipUserForDisable(user) {
            result.skippedCount = result.skippedCount + 1;
            result.skippedUsers.push(user.username + " (" + user.userId + ")");
            log:printInfo("Skipped user with abb.com domain: " + user.username);
            continue;
        }
        
        error? disableResult = disableUser(user.userId, accessToken);
        if disableResult is error {
            result.failureCount = result.failureCount + 1;
            result.failedUsers.push(user.username + " (" + user.userId + ")");
            log:printError("Failed to disable user " + user.username + ": " + disableResult.message());
        } else {
            result.successCount = result.successCount + 1;
            log:printInfo("Successfully disabled user: " + user.username);
        }
    }

    log:printInfo("Disable operation completed. Success: " + result.successCount.toString() + 
                  ", Failed: " + result.failureCount.toString() + 
                  ", Skipped: " + result.skippedCount.toString());
    
    return result;
}

// Function to delete users individually
function deleteUsers(InactiveUsersResponse inactiveUsers) returns OperationResult|error {
    string|error accessToken = getCurrentAccessToken();
    if accessToken is error {
        return error("Failed to get access token for delete operation: " + accessToken.message());
    }

    OperationResult result = {
        totalUsers: inactiveUsers.length(),
        successCount: 0,
        failureCount: 0,
        skippedCount: 0,
        failedUsers: [],
        skippedUsers: []
    };

    log:printInfo("Starting delete operation for " + inactiveUsers.length().toString() + " users");

    foreach InactiveUser user in inactiveUsers {
        log:printInfo("Processing user: " + user.username + " (ID: " + user.userId + ")");
        
        error? deleteResult = deleteUser(user.userId, accessToken);
        if deleteResult is error {
            result.failureCount = result.failureCount + 1;
            result.failedUsers.push(user.username + " (" + user.userId + ")");
            log:printError("Failed to delete user " + user.username + ": " + deleteResult.message());
        } else {
            result.successCount = result.successCount + 1;
            log:printInfo("Successfully deleted user: " + user.username);
        }
    }

    log:printInfo("Delete operation completed. Success: " + result.successCount.toString() + 
                  ", Failed: " + result.failureCount.toString());
    
    return result;
}

// Helper function to create a border line
function createBorderLine(int length) returns string {
    string border = "";
    int i = 0;
    while i < length {
        border = border + "=";
        i = i + 1;
    }
    return border;
}

// Function to display inactive users in a nice format
function displayInactiveUsers(InactiveUsersResponse inactiveUsers) {
    string borderLine = createBorderLine(80);
    
    io:println("╔" + borderLine + "╗");
    io:println("║                          INACTIVE USERS REPORT                          ║");
    io:println("╠" + borderLine + "╣");
    
    if inactiveUsers.length() == 0 {
        io:println("║                          No inactive users found                        ║");
        io:println("╚" + borderLine + "╝");
        return;
    }
    
    io:println("║ Total inactive users found: " + inactiveUsers.length().toString().padEnd(43) + "║");
    io:println("║ Inactive threshold: " + inactiveDaysThreshold.toString() + " days" + "".padEnd(50 - inactiveDaysThreshold.toString().length()) + "║");
    io:println("╠" + borderLine + "╣");
    
    int index = 0;
    foreach InactiveUser user in inactiveUsers {
        index = index + 1;
        io:println("║ User #" + index.toString() + "".padEnd(72 - index.toString().length()) + "║");
        io:println("║   User ID: " + user.userId.padEnd(66) + "║");
        io:println("║   Username: " + user.username.padEnd(65) + "║");
        io:println("║   User Store Domain: " + user.userStoreDomain.padEnd(56) + "║");
        
        if index < inactiveUsers.length() {
            io:println("║" + "".padEnd(78, "-") + "║");
        }
    }
    
    io:println("╚" + borderLine + "╝");
}

// Function to display operation results with skipped users
function displayOperationResult(OperationResult result, string operation) {
    string borderLine = createBorderLine(80);
    
    io:println("╔" + borderLine + "╗");
    io:println("║                    " + operation.toUpperAscii() + " OPERATION RESULTS                    ║");
    io:println("╠" + borderLine + "╣");
    io:println("║ Total users processed: " + result.totalUsers.toString().padEnd(48) + "║");
    io:println("║ Successful operations: " + result.successCount.toString().padEnd(48) + "║");
    io:println("║ Failed operations: " + result.failureCount.toString().padEnd(52) + "║");
    io:println("║ Skipped operations: " + result.skippedCount.toString().padEnd(51) + "║");
    
    if result.skippedUsers.length() > 0 {
        io:println("╠" + borderLine + "╣");
        io:println("║                             SKIPPED USERS                               ║");
        io:println("╠" + borderLine + "╣");
        
        foreach string skippedUser in result.skippedUsers {
            io:println("║ " + skippedUser.padEnd(77) + "║");
        }
    }
    
    if result.failedUsers.length() > 0 {
        io:println("╠" + borderLine + "╣");
        io:println("║                              FAILED USERS                               ║");
        io:println("╠" + borderLine + "╣");
        
        foreach string failedUser in result.failedUsers {
            io:println("║ " + failedUser.padEnd(77) + "║");
        }
    }
    
    io:println("╚" + borderLine + "╝");
}

// Automation 1: List inactive users
public function runListAutomation() returns error? {
    log:printInfo("Running LIST automation");
    io:println("=== AUTOMATION: LIST INACTIVE USERS ===");
    
    InactiveUsersResponse|error inactiveUsers = getInactiveUsers();
    if inactiveUsers is error {
        return error("Failed to get inactive users: " + inactiveUsers.message());
    }
    
    displayInactiveUsers(inactiveUsers);
    io:println("List automation completed successfully.");
    return;
}

// Automation 2: Disable inactive users
public function runDisableAutomation() returns error? {
    log:printInfo("Running DISABLE automation");
    io:println("=== AUTOMATION: DISABLE INACTIVE USERS ===");
    io:println("NOTE: Users with 'abb.com' in username will be skipped");
    
    InactiveUsersResponse|error inactiveUsers = getInactiveUsers();
    if inactiveUsers is error {
        return error("Failed to get inactive users: " + inactiveUsers.message());
    }
    
    if inactiveUsers.length() == 0 {
        io:println("No inactive users found to disable.");
        return;
    }
    
    displayInactiveUsers(inactiveUsers);
    
    OperationResult|error result = disableUsers(inactiveUsers);
    if result is error {
        return error("Disable operation failed: " + result.message());
    }
    
    displayOperationResult(result, "DISABLE");
    io:println("Disable automation completed successfully.");
    return;
}

// Automation 3: Delete inactive users
public function runDeleteAutomation() returns error? {
    log:printInfo("Running DELETE automation");
    io:println("=== AUTOMATION: DELETE INACTIVE USERS ===");
    
    InactiveUsersResponse|error inactiveUsers = getInactiveUsers();
    if inactiveUsers is error {
        return error("Failed to get inactive users: " + inactiveUsers.message());
    }
    
    if inactiveUsers.length() == 0 {
        io:println("No inactive users found to delete.");
        return;
    }
    
    displayInactiveUsers(inactiveUsers);
    
    OperationResult|error result = deleteUsers(inactiveUsers);
    if result is error {
        return error("Delete operation failed: " + result.message());
    }
    
    displayOperationResult(result, "DELETE");
    io:println("Delete automation completed successfully.");
    return;
}

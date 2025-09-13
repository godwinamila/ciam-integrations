import ballerina/http;
import ballerina/log;
import ballerina/lang.value;
import ballerina/time;
import ballerina/io;

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

// Function to switch token to organization context
function switchToOrganizationToken(string organizationId) returns string|error {
    // Get current access token
    string|error currentToken = getCurrentAccessToken();
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

// Function to get B2C inactive users
function getB2CInactiveUsers() returns InactiveUsersResponse|error {
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
    string requestPath = b2cIncativeUsersApiPath + "?inactiveAfter=" + inactiveAfterDate;
    http:Response|error response = asgardeoClient->get(path = requestPath, headers = headers);
    
    if response is error {
        log:printError(string`Failed to call B2C inactive users API: - ${response.detail().toString()}`);
        return error("Failed to call B2C inactive users API: " + response.message());
    }
    
    // Parse response
    json|error jsonPayload = response.getJsonPayload();
    if jsonPayload is error {
        log:printError("Failed to parse API response: " + jsonPayload.message());
        return error("Failed to parse API response: " + jsonPayload.message());
    }
    
    log:printDebug("API Response - getB2CInactiveUsers: " + value:toJsonString(jsonPayload));
    
    // Convert JSON to typed record
    InactiveUsersResponse|error inactiveUsers = value:cloneWithType(jsonPayload, InactiveUsersResponse);
    if inactiveUsers is error {
        log:printError("Failed to convert response to InactiveUsersResponse: " + inactiveUsers.message());
        return error("Failed to convert response to InactiveUsersResponse: " + inactiveUsers.message());
    }
    
    return inactiveUsers;
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

// Function to display B2C inactive users in a nice format
function displayB2CInactiveUsers(InactiveUsersResponse inactiveUsers) {
    string borderLine = createBorderLine(80);
    
    io:println("╔" + borderLine + "╗");
    io:println("║                        B2C INACTIVE USERS REPORT                        ║");
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

// Function to process inactive users (main workflow)
public function processInactiveUsers() returns error? {
    io:println("Starting inactive users processing...");
    
    // Check operation type and handle accordingly
    if operationType == B2B_DELETE || operationType == B2B_DISABLE || operationType == B2B_LIST {
        io:println("B2B operations are not implemented yet.");
        return;
    }
    
    if operationType == B2C_LIST {
        // Get B2C inactive users
        InactiveUsersResponse|error inactiveUsers = getB2CInactiveUsers();
        if inactiveUsers is error {
            return error("Failed to get B2C inactive users: " + inactiveUsers.message());
        }
        
        // Display the results
        displayB2CInactiveUsers(inactiveUsers);
        
        io:println("B2C inactive users listing completed successfully.");
        return;
    }
    
    if operationType == B2C_DELETE || operationType == B2C_DISABLE {
        io:println("B2C " + operationType.toString() + " operations are not implemented yet.");
        return;
    }
    
    io:println("Unknown operation type: " + operationType.toString());
}
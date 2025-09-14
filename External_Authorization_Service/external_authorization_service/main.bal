import ballerina/http;
import ballerina/io;
import ballerina/log;

// HTTP service for handling token requests
service / on new http:Listener(8089) {
    
    // POST resource to handle token requests
    resource function post token(http:Caller caller, http:Request req, @http:Payload TokenRequest tokenRequest) returns error? {
        
        // Print the whole request payload before processing
        string requestPayload = tokenRequest.toJsonString();
        log:printInfo("Received request with payload: " + requestPayload);
        
        // Process the token request
        ErrorResponse|TokenResponse|error? response = processTokenRequest(tokenRequest);
        
        // Send response back to client
        check caller->respond(response);
    }
}

// Function to process the token request
function processTokenRequest(TokenRequest tokenRequest) returns ErrorResponse|TokenResponse|error? {
    
    // Log key information from the request
    log:printInfo("Processing token request", 
        actionType = tokenRequest.actionType,
        clientId = tokenRequest.event.request.clientId,
        organization = tokenRequest.event.organization.name,
        organizationId = tokenRequest.event.organization.id,
        userId = tokenRequest.event.user?.id,
        userOrganizationName = tokenRequest.event.user?.organization?.name
    );
    
    match tokenRequest.actionType {
        "PRE_ISSUE_ACCESS_TOKEN" => {
            return handlePreIssueAccessToken(tokenRequest);
        }
        _ => {
            ErrorResponse errorResponse = {
                body : {
                    actionStatus: "ERROR",
                    errorMessage: "Unsupported action type: " + tokenRequest.actionType,
                    errorDescription: "Unsupported action type: " + tokenRequest.actionType
                }
            };
            return errorResponse;
        }
    }
}

// Handle PRE_ISSUE_ACCESS_TOKEN action
function handlePreIssueAccessToken(TokenRequest tokenRequest) returns TokenResponse {
    
    // Check if allowed operations include "add" with "/accessToken/scopes/" in paths
    boolean scopeAddAllowed = false;
    foreach AllowedOperation operation in tokenRequest.allowedOperations {
        log:printInfo("Allowed operation", op = operation.op, pathsCount = operation.paths.length());
        
        if operation.op == "add" {
            foreach string path in operation.paths {
                if path == "/accessToken/scopes/" {
                    scopeAddAllowed = true;
                    break;
                }
            }
        }
        if scopeAddAllowed {
            break;
        }
    }
    
    // Always return SUCCESS status with 200 OK
    ScopeAddResponse response = {
        actionStatus: "SUCCESS"
    };
    
    if scopeAddAllowed {
        log:printInfo("scope add operation is allowed");
        
        // Get organization entitlements and add scopes based on organization
        Operation[] operations = getOrganizationScopes(tokenRequest);
        if operations.length() > 0 {
            response.operations = operations;
        } else {
            // Fallback to default scope if no organization entitlements found
            response.operations = [
                {
                    op: "add",
                    path: "/accessToken/scopes/-",
                    value: "trial_account"
                }
            ];
        }
    } else {
        // Log that scope add operation is not allowed
        log:printInfo("scope add operation not allowed");
    }

    // Print the whole response payload before returning
    string responsePayload = response.toJsonString();
    log:printInfo("Complete response payload: " + responsePayload);

    return {body: {...response}};
}

// Function to get organization scopes based on entitlements
function getOrganizationScopes(TokenRequest tokenRequest) returns Operation[] {
    Operation[] operations = [];
    
    // Get user organization name
    string? userOrgName = tokenRequest.event.user?.organization?.name;
    if userOrgName is () {
        log:printInfo("User organization name not found");
        return operations;
    }
    
    // Read entitlements file
    json|io:Error entitlementsResult = io:fileReadJson(entitlementsFilePath);
    if entitlementsResult is io:Error {
        log:printError("Failed to read entitlements file", 'error = entitlementsResult);
        return operations;
    }
    
    // Convert JSON to entitlements array
    OrganizationEntitlement[]|error entitlements = entitlementsResult.cloneWithType();
    if entitlements is error {
        log:printError("Failed to parse entitlements", 'error = entitlements);
        return operations;
    }
    
    // Find organization by name
    OrganizationEntitlement? orgEntitlement = ();
    foreach OrganizationEntitlement entitlement in entitlements {
        if entitlement.orgId == userOrgName {
            orgEntitlement = entitlement;
            break;
        }
    }
    
    if orgEntitlement is () {
        log:printInfo("Organization not found in entitlements", organizationName = userOrgName);
        return operations;
    }
    
    log:printInfo("Found organization entitlement", 
        organizationName = userOrgName,
        plan = orgEntitlement.plan,
        featuresCount = orgEntitlement.features.length()
    );
    
    // Create operations for each feature
    foreach string feature in orgEntitlement.features {
        operations.push({
            op: "add",
            path: "/accessToken/scopes/-",
            value: feature
        });
    }
    
    return operations;
}
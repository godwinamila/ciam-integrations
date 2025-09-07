import ballerina/http;
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
        userId = tokenRequest.event.user.id,
        userOrganizationName = tokenRequest.event.user.organization.name
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
        // Include operations if scope add is allowed
        response.operations = [
            {
                op: "add",
                path: "/accessToken/scopes/-",
                value: "custom-scope-1"
            }
        ];
    } else {
        // Log that scope add operation is not allowed
        log:printInfo("scope add operation not allowed");
    }

    // Print the whole response payload before returning
    string responsePayload = response.toJsonString();
    log:printInfo("Complete response payload: " + responsePayload);

    return {body: {...response}};
}
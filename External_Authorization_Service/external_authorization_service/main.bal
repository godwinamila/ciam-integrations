import ballerina/http;
import ballerina/log;

// HTTP service for handling token requests
service / on new http:Listener(8089) {
    
    // POST resource to handle token requests
    resource function post token(http:Caller caller, http:Request req, @http:Payload json tokenRequest) returns error? {
        
        // Print the whole request payload before processing
        string requestPayload = tokenRequest.toJsonString();
        log:printInfo("Complete request payload: " + requestPayload);
        
        // Extract actionType from JSON
        json|error actionTypeResult = tokenRequest.actionType;
        string actionType = "";
        if actionTypeResult is json {
            actionType = actionTypeResult is string ? actionTypeResult : "";
        }
        log:printInfo("Received token request", actionType = actionType);
        
        // Process the token request
        json response = processTokenRequest(tokenRequest);
        
        // Send response back to client
        check caller->respond(response);
    }
}

// Function to process the token request
function processTokenRequest(json tokenRequest) returns json {
    
    // Extract actionType from JSON
    json|error actionTypeResult = tokenRequest.actionType;
    string actionType = "";
    if actionTypeResult is json {
        actionType = actionTypeResult is string ? actionTypeResult : "";
    }
    
    // Extract event information from JSON
    json|error eventResult = tokenRequest.event;
    if eventResult is json && eventResult is map<json> {
        json|error requestResult = eventResult.request;
        json|error organizationResult = eventResult.organization;
        json|error userResult = eventResult.user;
        
        string clientId = "";
        string organizationName = "";
        string organizationId = "";
        string userId = "";
        
        if requestResult is json && requestResult is map<json> {
            json|error clientIdResult = requestResult.clientId;
            if clientIdResult is json {
                clientId = clientIdResult is string ? clientIdResult : "";
            }
        }
        
        if organizationResult is json && organizationResult is map<json> {
            json|error orgNameResult = organizationResult.name;
            json|error orgIdResult = organizationResult.id;
            if orgNameResult is json {
                organizationName = orgNameResult is string ? orgNameResult : "";
            }
            if orgIdResult is json {
                organizationId = orgIdResult is string ? orgIdResult : "";
            }
        }
        
        if userResult is json && userResult is map<json> {
            json|error userIdResult = userResult.id;
            if userIdResult is json {
                userId = userIdResult is string ? userIdResult : "";
            }
        }
        
        // Log key information from the request
        log:printInfo("Processing token request", 
            actionType = actionType,
            clientId = clientId,
            organization = organizationName,
            organizationId = organizationId,
            userId = userId
        );
    }
    
    // Process based on action type
    match actionType {
        "PRE_ISSUE_ACCESS_TOKEN" => {
            return handlePreIssueAccessToken(tokenRequest);
        }
        _ => {
            TokenResponse errorResponse = {
                status: "ERROR",
                message: "Unsupported action type: " + actionType,
                actionType: actionType
            };
            return errorResponse.toJson();
        }
    }
}

// Handle PRE_ISSUE_ACCESS_TOKEN action
function handlePreIssueAccessToken(json tokenRequest) returns json {
    
    // Check if allowed operations include "add" with "/accessToken/scopes/" in paths
    boolean scopeAddAllowed = false;
    json|error allowedOperationsResult = tokenRequest.allowedOperations;
    
    if allowedOperationsResult is json && allowedOperationsResult is json[] {
        foreach json operationJson in allowedOperationsResult {
            if operationJson is map<json> {
                json|error opResult = operationJson.op;
                json|error pathsResult = operationJson.paths;
                
                string op = "";
                if opResult is json {
                    op = opResult is string ? opResult : "";
                }
                
                int pathsCount = 0;
                if pathsResult is json && pathsResult is json[] {
                    pathsCount = pathsResult.length();
                }
                
                log:printInfo("Allowed operation", op = op, pathsCount = pathsCount);
                
                if op == "add" && pathsResult is json && pathsResult is json[] {
                    foreach json pathJson in pathsResult {
                        string path = pathJson is string ? pathJson : "";
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
    log:printInfo("Sending back response " + response.toJson().toString());
    return response.toJson();
}
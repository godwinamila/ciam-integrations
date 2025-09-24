import ballerina/log;
import ballerina/http;

// Function to get Salesforce access token using refresh token
function getSalesforceAccessToken() returns string|error {
    
    // If token already exists, return it (in production, you'd want to check expiry)
    if salesforceAccessToken != "" {
        return salesforceAccessToken;
    }
    
    // Prepare OAuth request with query parameters
    string tokenEndpoint = string `/services/oauth2/token?refresh_token=${salesforceRefreshToken}&grant_type=refresh_token&client_id=${salesforceClientId}&client_secret=${salesforceClientSecret}`;
    
    http:Request tokenRequest = new;
    tokenRequest.setHeader("Content-Type", "application/x-www-form-urlencoded");
    
    // Make token request
    http:Response|error tokenResponse = salesforceHttpClient->post(tokenEndpoint, tokenRequest);
    if tokenResponse is error {
        log:printError("Failed to get Salesforce access token", tokenResponse);
        return tokenResponse;
    }
    
    // Parse token response
    json|error tokenJson = tokenResponse.getJsonPayload();
    if tokenJson is error {
        log:printError("Failed to parse token response", tokenJson);
        return tokenJson;
    }
    
    // Extract access token
    json|error accessTokenJson = tokenJson.access_token;
    if accessTokenJson is error {
        return error("Failed to extract access token from response");
    }
    
    if accessTokenJson is string {
        salesforceAccessToken = accessTokenJson;
        log:printInfo("Successfully obtained Salesforce access token using refresh token");
        return salesforceAccessToken;
    } else {
        return error("Invalid access token response");
    }
}

// Function to create contact in Salesforce
function createSalesforceContact(RegistrationSuccessEvent regEvent) returns error? {
    
    string userEmail = "";
    string userFirstName = "";
    string userLastName = "";
    string userMobile = "";
    boolean marketingConsent = false; // Default to false
    
    // Extract user details from claims
    foreach UserClaim claim in regEvent.user.claims {
        string formattedValue = formatClaimValue(claim.value);
        
        if claim.uri == "http://wso2.org/claims/emailaddress" {
            userEmail = formattedValue;
        } else if claim.uri == "http://wso2.org/claims/givenname" {
            userFirstName = formattedValue;
        } else if claim.uri == "http://wso2.org/claims/lastname" {
            userLastName = formattedValue;
        } else if claim.uri == "http://wso2.org/claims/mobile" {
            userMobile = formattedValue;
        } else if claim.uri == "http://wso2.org/claims/marketing_consent" {
            if formattedValue == "true" {
                marketingConsent = true;
            }
        }
    }
    
    // Get access token
    string|error accessToken = getSalesforceAccessToken();
    if accessToken is error {
        return accessToken;
    }
    
    // Create contact record as JSON
    json contactRequest = {
        "FirstName": userFirstName,
        "LastName": userLastName,
        "Email": userEmail,
        "MobilePhone": userMobile,
        "Marketing_consent__c": marketingConsent,
        "Asgardeo_user_id__c": regEvent.user.id
    };
    
    // Prepare HTTP request
    http:Request createRequest = new;
    createRequest.setJsonPayload(contactRequest);
    createRequest.setHeader("Authorization", string `Bearer ${accessToken}`);
    createRequest.setHeader("Content-Type", "application/json");
    
    // Make create request
    string createEndpoint = "/services/data/v60.0/sobjects/Contact";
    http:Response|error createResponse = salesforceHttpClient->post(createEndpoint, createRequest);
    if createResponse is error {
        log:printError("Failed to create contact in Salesforce", createResponse);
        return createResponse;
    }
    
    // Check response status code
    int statusCode = createResponse.statusCode;
    if statusCode == 200 || statusCode == 201 {
        log:printInfo("Successfully created contact in Salesforce", 
                     statusCode = statusCode,
                     asgardeoUserId = regEvent.user.id);
    } else {
        json|error errorJson = createResponse.getJsonPayload();
        string errorMessage = errorJson is json ? errorJson.toString() : "Unknown error";
        log:printError("Failed to create contact in Salesforce", 
                      statusCode = statusCode, 
                      errorMessage = errorMessage);
        return error(string `Contact creation failed with status code: ${statusCode}`);
    }
}

// Function to update marketing consent in Salesforce
function updateSalesforceMarketingConsent(string asgardeoUserId, boolean marketingConsent, string? lastName = ()) returns error? {
    
    // Get access token
    string|error accessToken = getSalesforceAccessToken();
    if accessToken is error {
        return accessToken;
    }
    
    // Create update request with only marketing consent
    json updateRequest = {
        "Marketing_consent__c": marketingConsent
    };
    
    // Only include LastName if explicitly provided
    if lastName is string && lastName.trim() != "" {
        updateRequest = {
            "Marketing_consent__c": marketingConsent,
            "LastName": lastName
        };
        log:printInfo("Including provided LastName in update", lastName = lastName);
    }
    
    // Prepare HTTP request
    http:Request patchRequest = new;
    patchRequest.setJsonPayload(updateRequest);
    patchRequest.setHeader("Authorization", string `Bearer ${accessToken}`);
    patchRequest.setHeader("Content-Type", "application/json");
    
    // Make update request using external ID
    string updateEndpoint = string `/services/data/v60.0/sobjects/Contact/Asgardeo_user_id__c/${asgardeoUserId}`;
    http:Response|error updateResponse = salesforceHttpClient->patch(updateEndpoint, patchRequest);
    if updateResponse is error {
        log:printError("Failed to update marketing consent in Salesforce", updateResponse);
        return updateResponse;
    }
    
    // Check response status - now includes 201 as successful
    int statusCode = updateResponse.statusCode;
    if statusCode == 200 || statusCode == 201 || statusCode == 204 {
        log:printInfo("Successfully updated marketing consent in Salesforce", 
                     asgardeoUserId = asgardeoUserId, 
                     marketingConsent = marketingConsent,
                     statusCode = statusCode);
    } else {
        json|error errorJson = updateResponse.getJsonPayload();
        string errorMessage = errorJson is json ? errorJson.toString() : "Unknown error";
        log:printError("Failed to update marketing consent in Salesforce", 
                      statusCode = statusCode, 
                      errorMessage = errorMessage);
        return error(string `Update failed with status code: ${statusCode}`);
    }
}

// Helper function to format claim value for logging
function formatClaimValue(string|string[] claimValue) returns string {
    if claimValue is string {
        return claimValue;
    } else {
        return string:'join(", ", ...claimValue);
    }
}

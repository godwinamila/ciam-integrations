// Copyright (c) 2024, WSO2 LLC. (https://www.wso2.com). All Rights Reserved.
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied. See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/http;
import ballerina/log;
import ballerina/regex;

final AsgardeoAppConfig asgardeoAppConfig = {
    tokenUrl: asgardeoTokenUrl,
    clientId: asgardeoClientId,
    clientSecret: asgardeoClientSecret
};

final http:Client asgardeoClient = check new (asgardeoUrl, {
    auth: {
        ...asgardeoAppConfig,
        scopes: asgardeoScopes
    }
});

# Retrieve the given user from Asgardeo.
# 
# + id - The id of the user.
# + return - The AsgardeoUser if the user is found, else an error.
isolated function getAsgardeoUser(string id) returns AsgardeoUser|error {

    // Retrieve user from the Asgardeo server given the user id.
    json|error jsonResponse = asgardeoClient->get("/scim2/Users/" + id);

    // Handle error response.
    if jsonResponse is error {
        log:printError(string `Error while fetching Asgardeo user for the id: ${id}.`, jsonResponse);
        return error("Error while fetching the user.");
    }

    AsgardeoUserResponse response = check jsonResponse.cloneWithType(AsgardeoUserResponse);

    if response.userName == "" {
        log:printError(string `A user not found for the id: ${id}.`);
        return error("User not found.");
    }

    // Extract the username from the response.
    string username = regex:split(response.userName, "/")[1];

    log:printInfo("Successfully retrieved the username from Asgardeo.");

    // Return the user object.
    return {
        id: response.id,
        username: username
    };
}

# Method to authenticate the user.
# 
# + user - The user object.
# + return - An error if the authentication fails.
isolated function authenticateUser(User user) returns error? {

    // Create a new HTTP client to connect to the external IDP.
    final http:Client legacyIDPClient = check new (legacyIDPBaseUrl, {
        timeout: 30,
        secureSocket: {
            cert: legacyIDPCert,
            verifyHostName: false
        }
    });

    string credentials = string `${legacyIDPClientId}:${legacyIDPClientSecret}`;
    string encodedCredentials = credentials.toBytes().toBase64();

    map<string|string[]> headers = {
        "Authorization": string `Basic ${encodedCredentials}`,
        "Content-Type": "application/x-www-form-urlencoded"
    };

    string requestBody = string `grant_type=password&username=${user.username}&password=${user.password}`;

    // Authenticate the user by invoking the external IDP.
    // In this example, the external authentication is done invoking the SCIM2 Me endpoint.
    // You may replace this with an implementation that suits your IDP.
    http:Response response = check legacyIDPClient->post("/oauth2/token", requestBody, headers = headers);

    // Check if the authentication was successful.
    if response.statusCode == http:STATUS_OK {
        // Parse the response body to check if access token exists
        json|error responseBody = response.getJsonPayload();
        
        if responseBody is json {
            LegacyIdpTokenResponse|error tokenResponse = responseBody.cloneWithType(LegacyIdpTokenResponse);
            
            if tokenResponse is LegacyIdpTokenResponse {
                // Access token exists in the response (verified by successful record conversion)
                log:printInfo(string `Authentication successful for user: ${user.id}. Access token received.`);
                return;
            } else {
                log:printError(string `Authentication failed for the user: ${user.id}. Invalid token response format.`);
                return error("Authentication failed");
            }
        } else {
            log:printError(string `Authentication failed for the user: ${user.id}. Unable to parse response body.`);
            return error("Authentication failed");
        }
        
    } else if response.statusCode == http:STATUS_BAD_REQUEST {
        
        // Parse the response body to get error details
        json|error responseBody = response.getJsonPayload();
        
        if responseBody is json {
            LegacyIdpErrorResponse|error errorResponse = responseBody.cloneWithType(LegacyIdpErrorResponse);
            
            if errorResponse is LegacyIdpErrorResponse {
                string errorDescription = errorResponse.error_description;
                
                // Check if error_description contains "Authentication failed for"
                if errorDescription.includes("Authentication failed") {
                    log:printError(string `Authentication failed for the user: ${user.id}. Invalid credentials`);
                    return error("Invalid Credentials");
                } else {
                    log:printError(string `Authentication failed for the user: ${user.id}.`);
                    return error("Authentication failed");
                }
            }
        }
        // Fallback if unable to parse response body
        log:printError(string `Authentication failed for the user: ${user.id}.`);
        return error("Authentication failed");
    } else {
        log:printError(string `Authentication failed for the user: ${user.id}.`);
        return error("Authentication failed");
    }
}

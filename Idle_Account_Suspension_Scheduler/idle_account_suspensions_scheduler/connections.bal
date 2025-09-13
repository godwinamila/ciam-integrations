import ballerina/http;

// Single HTTP client for all Asgardeo API operations
final http:Client asgardeoClient = check new (asgardeoBaseUrl, {
    timeout: 30
});
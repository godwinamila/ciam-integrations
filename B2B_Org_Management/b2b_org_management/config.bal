import ballerina/http;

// Asgardeo API configuration
configurable string asgardeoBaseUrl = "https://api.eu.asgardeo.io/t/pocabbgroup";
configurable string asgardeoClientId = ?;
configurable string asgardeoClientSecret = ?;
configurable string asgardeoScopes = "SYSTEM";

// Organization switching scopes
configurable string orgSwitchScopes = "SYSTEM";

// Single HTTP client for all Asgardeo API operations
final http:Client asgardeoClient = check new (asgardeoBaseUrl, {
    timeout: 30
});
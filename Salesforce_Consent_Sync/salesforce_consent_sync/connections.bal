import ballerina/http;

// HTTP Client for Salesforce API
final http:Client salesforceHttpClient = check new (salesforceBaseUrl);

// Global variable to store access token
string salesforceAccessToken = "";

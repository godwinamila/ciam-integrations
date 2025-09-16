import ballerina/http;

// Configure HTTP client with SSL settings for Splunk HEC
http:ClientConfiguration clientConfig = {
    timeout: 60,
    secureSocket: {
        cert: splunkServiceCert,
        verifyHostName: false
    } 
};
    

// Initialize HTTP client for Splunk HEC with configuration
final http:Client splunkClient = check new (splunkUrl, clientConfig);

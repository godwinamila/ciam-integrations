import ballerina/http;

// HTTP client for NewRelic Events API
http:Client newRelicClient = check new (string `${newRelicEventApiHostname}/v1/accounts/${newRelicAccountId}/events`, 
    config = {
        timeout: 30
    }
);

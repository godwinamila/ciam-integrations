import ballerina/http;
import ballerina/log;

// Function to send event to Splunk
function sendEventToSplunk(string eventType, int timestamp, SessionEstablishedEvent|SessionRevokedEvent|LoginSuccessEvent|LoginFailedEvent eventData, string eventId) returns error? {
    
    // Create Splunk event payload
    SplunkEvent splunkEvent = {
        eventId: eventId,
        eventType: eventType,
        timestamp: timestamp,
        eventData: eventData 
    };

    log:printInfo("Sending event : " + splunkEvent.toJsonString());

    map<string|string[]> headers = {
            "Authorization": "Splunk " + hecToken,
            "Content-Type": "application/json"
    };

    http:Response|error response = splunkClient->post(
        path = "", 
        message = {
            "event": splunkEvent,
            "sourcetype": "asgardeo_idp_index"    
        }, 
        headers = headers);

    if response is error {
        log:printError("Failed to send event to Splunk", response);
        return error("Failed to send event to Splunk: " + response.message());
    }

    // Check response status
    if response.statusCode != 200 {
        string|error responseBody = response.getTextPayload();
        string errorMsg = responseBody is string ? responseBody : "Unknown error";
        log:printError("Splunk HEC returned error", statusCode = response.statusCode, responseBody = errorMsg);
        return error("Splunk HEC error: " + response.statusCode.toString() + " - " + errorMsg);
    }

    // Parse response
    json|error responseJson = response.getJsonPayload();
    if responseJson is error {
        log:printError(string`Could not parse Splunk response as JSON:  - ${responseJson.detail().toString()}`);
    } else {
        SplunkHecResponse|error splunkResponse = responseJson.cloneWithType(SplunkHecResponse);
        if splunkResponse is SplunkHecResponse {
            if splunkResponse.text != "Success" {
                log:printError("Splunk HEC processing error", code = splunkResponse.code, text = splunkResponse.text);
                return error("Splunk processing error: " + splunkResponse.text);
            }
            log:printInfo("Event successfully sent to Splunk", eventId = splunkResponse.code, text = splunkResponse.text);
        } else {
            log:printError(string`Failed to publsih event:  - ${splunkResponse.detail().toString()}`);
            return error("Failed to publsih event: " + splunkResponse.message());
        }
    }

    log:printInfo("Event published to Splunk successfully", 
                  eventType = eventType, 
                  eventId = eventId);
    
    return;
}
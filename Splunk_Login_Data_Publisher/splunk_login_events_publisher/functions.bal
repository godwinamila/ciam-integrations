import ballerina/http;
import ballerina/log;

// Function to send event to Splunk
function sendEventToSplunk(string eventType, json eventData, SecurityEventToken setPayload) returns error? {
    
    // Create Splunk event payload
    SplunkEvent splunkEvent = {
        time: setPayload.iat,
        event: {
            "eventType": eventType,
            "issuer": setPayload.iss,
            "jwtId": setPayload.jti,
            "issuedAt": setPayload.iat,
            "eventData": eventData
        }
    };

    // Send to Splunk HEC
    http:Response|error response = splunkClient->post("", splunkEvent, {
        "Content-Type": "application/json"
    });

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
        log:printWarn("Could not parse Splunk response as JSON", responseJson);
    } else {
        SplunkHecResponse|error splunkResponse = responseJson.cloneWithType(SplunkHecResponse);
        if splunkResponse is SplunkHecResponse {
            if splunkResponse.code != 0 {
                log:printError("Splunk HEC processing error", code = splunkResponse.code, text = splunkResponse.text);
                return error("Splunk processing error: " + splunkResponse.text);
            }
            log:printInfo("Event successfully sent to Splunk", code = splunkResponse.code, text = splunkResponse.text);
        }
    }

    log:printInfo("Event published to Splunk successfully", 
                  eventType = eventType, 
                  jwtId = setPayload.jti);
    
    return;
}
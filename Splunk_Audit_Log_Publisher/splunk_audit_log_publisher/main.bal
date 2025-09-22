import ballerina/http;
import ballerina/log; 

// HTTP service to handle log requests
service /logs on new http:Listener(8082) {
    
    resource function post .(http:Request request) returns http:Response|error {
        // Extract JSON payload from request
        json payload = check request.getJsonPayload();
        
        // Print the received JSON payload
        log:printInfo("Received log payload: " + payload.toString());
        
        // Prepare headers for Splunk HEC
        map<string|string[]> headers = {
            "Authorization": "Splunk " + hecToken,
            "Content-Type": "application/json"
        };
        
        // Forward the payload to Splunk HEC
        http:Response|error splunkResponse = splunkClient->post(
            path = "", 
            message = {
                "event": payload,
                "sourcetype": "asagrdeo_audit_log"    
            }, 
            headers = headers);
        
        // Create response for the original caller
        http:Response response = new;
        
        if splunkResponse is http:Response {
            // Successfully forwarded to Splunk
            response.statusCode = 200;
            response.setJsonPayload({"status": "success", "message": "Log forwarded to Splunk"});
            log:printInfo("Successfully forwarded log to Splunk");
        } else {
            // Error forwarding to Splunk
            response.statusCode = 500;
            response.setJsonPayload({"status": "error", "message": "Failed to forward log to Splunk"});
            log:printError("Failed to forward log to Splunk", splunkResponse);
        }
        
        return response;
    }
}

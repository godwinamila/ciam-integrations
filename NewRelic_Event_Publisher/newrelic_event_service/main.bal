import ballerina/crypto;
import ballerina/http;
import ballerina/log;

// HTTP listener for webhook endpoint
listener http:Listener webhookListener = new (9090);

// Webhook service to handle Asgardeo events
service / on webhookListener {

    // GET resource to handle webhook subscription verification
    resource function get webhook(http:Caller caller, http:Request request) returns error? {

        // Extract query parameters
        map<string[]> queryParams = request.getQueryParams();
        
        // Get hub parameters
        string[]? hubModeArray = queryParams["hub.mode"];
        string[]? hubTopicArray = queryParams["hub.topic"];
        string[]? hubChallengeArray = queryParams["hub.challenge"];
        string[]? hubLeaseSecondsArray = queryParams["hub.lease_seconds"];

        // Validate required parameters exist
        if hubModeArray is () || hubTopicArray is () || hubChallengeArray is () || hubLeaseSecondsArray is () {
            log:printError("Missing required hub parameters for subscription verification");
            http:Response errorResponse = new;
            errorResponse.statusCode = 400;
            errorResponse.setTextPayload("Bad Request: Missing hub parameters");
            check caller->respond(errorResponse);
            return;
        }

        // Extract parameter values
        string hubMode = hubModeArray[0];
        string hubTopic = hubTopicArray[0];
        string hubChallenge = hubChallengeArray[0];
        string hubLeaseSeconds = hubLeaseSecondsArray[0];

        // Validate subscription mode
        if hubMode != "subscribe" {
            log:printError("Invalid hub mode for subscription verification", hubMode = hubMode);
            http:Response errorResponse = new;
            errorResponse.statusCode = 400;
            errorResponse.setTextPayload("Bad Request: Invalid hub mode");
            check caller->respond(errorResponse);
            return;
        }

        // Log subscription verification details
        log:printInfo("Processing webhook subscription verification",
                hubMode = hubMode,
                hubTopic = hubTopic,
                hubChallenge = hubChallenge,
                hubLeaseSeconds = hubLeaseSeconds);

        // Create response with challenge value and 2xx status code
        http:Response response = new;
        response.statusCode = 200;
        response.setTextPayload(hubChallenge);
        response.setHeader("Content-Type", "text/plain");
        
        // Send verification response
        check caller->respond(response);
        
        log:printInfo("Webhook subscription verification completed successfully",
                hubTopic = hubTopic);
    }

    // POST resource to handle webhook notifications
    resource function post webhook(http:Caller caller, http:Request request) returns error? {

        // Get raw request body for signature verification
        byte[]|error rawPayload = request.getBinaryPayload();
        if rawPayload is error {
            log:printError("Failed to extract raw payload", rawPayload);
            WebhookResponse errorResponse = {
                message: "Failed to read request body",
                success: false
            };
            check caller->respond(errorResponse);
            return;
        }

        // Check if signature verification should be skipped
        if skipSignatureVerification {
            log:printInfo("Signature verification skipped due to configuration");
        } else {
            // Verify signature if webhook secret is configured
            if webhookSecret.trim() != "" {
                error? signatureVerification = verifyWebhookSignature(request, rawPayload);
                if signatureVerification is error {
                    log:printError("Webhook signature verification failed", signatureVerification);
                    http:Response unauthorizedResponse = new;
                    unauthorizedResponse.statusCode = 401;
                    unauthorizedResponse.setJsonPayload({
                        message: "Unauthorized: Invalid signature",
                        success: false
                    });
                    check caller->respond(unauthorizedResponse);
                    return;
                }
                log:printInfo("Webhook signature verification successful");
            } else {
                log:printWarn("Webhook secret not configured, skipping signature verification");
            }
        }

        // Convert raw payload to string then to JSON
        string|error payloadStr = string:fromBytes(rawPayload);
        if payloadStr is error {
            log:printError("Failed to convert payload to string", payloadStr);
            WebhookResponse errorResponse = {
                message: "Invalid payload encoding",
                success: false
            };
            check caller->respond(errorResponse);
            return;
        }

        json|error payload = payloadStr.fromJsonString();
        if payload is error {
            log:printError("Failed to parse JSON payload", payload);
            WebhookResponse errorResponse = {
                message: "Invalid JSON payload",
                success: false
            };
            check caller->respond(errorResponse);
            return;
        }

        // Log the complete event payload for debugging and monitoring
        log:printInfo("Received webhook event payload", eventPayload = payload.toJsonString());

        // Convert JSON to SecurityEventToken record
        SecurityEventToken|error setPayload = payload.cloneWithType(SecurityEventToken);
        if setPayload is error {
            log:printError("Failed to parse Security Event Token", setPayload);
            WebhookResponse errorResponse = {
                message: "Invalid Security Event Token format",
                success: false
            };
            check caller->respond(errorResponse);
            return;
        }

        // Process the Security Event Token
        error? processResult = processSecurityEventToken(setPayload);
        if processResult is error {
            log:printError("Failed to process Security Event Token", processResult);
            WebhookResponse errorResponse = {
                message: "Failed to process webhook event",
                success: false
            };
            http:InternalServerError serverError = {
                body: errorResponse
            };
            check caller->respond(serverError);
            return;
        }

        // Send success response
        WebhookResponse successResponse = {
            message: "Webhook processed successfully",
            success: true
        };
        check caller->respond(successResponse);
    }
}

// Function to verify webhook signature using HMAC-SHA256
function verifyWebhookSignature(http:Request request, byte[] rawPayload) returns error? {

    // Extract signature header
    string|error signatureHeader = request.getHeader("X-Hub-Signature");
    if signatureHeader is error {
        return error("Missing X-Hub-Signature header");
    }

    // Parse signature header (format: sha256=<hash>)
    // if !signatureHeader.startsWith("sha256=") {
    //     return error("Invalid signature format, expected sha256= prefix");
    // }

    // string expectedSignature = signatureHeader.substring(7); // Remove "sha256=" prefix

    // Compute HMAC-SHA256 using webhook secret
    byte[] secretBytes = webhookSecret.toBytes();
    byte[]|crypto:Error computedHmac = crypto:hmacSha256(input = rawPayload, key = secretBytes);
    
    if computedHmac is crypto:Error {
        return error("Failed to compute HMAC signature", computedHmac);
    }

    // Convert computed HMAC to hex string
    string computedSignature = computedHmac.toBase16();

    // Compare signatures (case-insensitive)
    if signatureHeader.toLowerAscii() != computedSignature.toLowerAscii() {
        return error("Signature mismatch: computed signature does not match expected signature");
    }

    return;
}

// Function to process Security Event Token
function processSecurityEventToken(SecurityEventToken setPayload) returns error? {

    log:printInfo("Processing Security Event Token",
            issuer = setPayload.iss,
            jwtId = setPayload.jti,
            issuedAt = setPayload.iat);

    // Get all event types from the events object
    string[] eventTypes = setPayload.events.keys();
    
    // Process each event type
    foreach string eventType in eventTypes {
        json eventData = setPayload.events.get(eventType);
        check processEventByType(eventType, eventData, setPayload);
    }
}

// Function to process events based on their type URL
function processEventByType(string eventType, json eventData, SecurityEventToken setPayload) returns error? {

    log:printInfo("Processing event", eventType = eventType);

    // Transform any event to New Relic format using generic flattening
    NewRelicEvent|error transformedEvent = transformEventToNewRelic(eventType, eventData);
    if transformedEvent is error {
        log:printError("Failed to transform event", eventType = eventType, 'error = transformedEvent);
        return transformedEvent;
    }
    
    // Publish to New Relic
    NewRelicEvent[] events = [transformedEvent];
    error? publishResult = publishToNewRelic(events);
    if publishResult is error {
        log:printError("Failed to publish event to New Relic", eventType = eventType, 'error = publishResult);
        return publishResult;
    }
    
    log:printInfo("Successfully processed and published event to New Relic", eventType = eventType);
}
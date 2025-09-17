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
            if webhookKey.trim() != "" {
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

        // Extract event types and log payload with event type information
        string[] eventTypes = setPayload.events.keys();
        string[] readableEventTypes = [];
        
        // Extract readable event type names from URLs
        foreach string eventType in eventTypes {
            string readableEventType = extractEventTypeName(eventType);
            readableEventTypes.push(readableEventType);
        }

        // Get payload string and check its size
        string payloadString = payload.toJsonString();
        int payloadSize = payloadString.length();
        
        // Log payload information with size details
        if payloadSize > 2000 {
            // Log truncated payload for large payloads
            string truncatedPayload = payloadString.substring(0, 2000) + "... [TRUNCATED]";
            log:printInfo("Received webhook event (large payload)", 
                    eventTypes = readableEventTypes, 
                    fullEventUrls = eventTypes,
                    payloadSize = payloadSize,
                    truncatedPayload = truncatedPayload);
        } else {
            // Log full payload for smaller payloads
            log:printInfo("Received webhook event", 
                    eventTypes = readableEventTypes, 
                    fullEventUrls = eventTypes,
                    payloadSize = payloadSize,
                    eventPayload = payloadString);
        }

        // Also log key payload components separately
        log:printInfo("Webhook event details",
                issuer = setPayload.iss,
                jwtId = setPayload.jti,
                issuedAt = setPayload.iat,
                requestCorrelationId = setPayload?.rci ?: "N/A",
                eventCount = eventTypes.length());

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

// Function to extract readable event type name from URL
function extractEventTypeName(string eventTypeUrl) returns string {
    // Find the last occurrence of "/" to extract the event type name
    int? lastSlashIndex = eventTypeUrl.indexOf("/", eventTypeUrl.length() - 1);
    int searchIndex = 0;
    int foundIndex = -1;
    
    // Find the last slash by searching from beginning
    while true {
        int? currentIndex = eventTypeUrl.indexOf("/", searchIndex);
        if currentIndex is () {
            break;
        }
        foundIndex = currentIndex;
        searchIndex = currentIndex + 1;
    }
    
    if foundIndex >= 0 && foundIndex < eventTypeUrl.length() - 1 {
        return eventTypeUrl.substring(foundIndex + 1);
    }
    
    return eventTypeUrl;
}

// Function to get username from user claims (handles both claims and addedClaims)
function getUsernameFromClaims(UserClaim[]? claims) returns string {
    if claims is () {
        return "N/A";
    }
    
    foreach UserClaim claim in claims {
        if claim.uri == "http://wso2.org/claims/username" {
            string|string[] claimValue = claim.value;
            if claimValue is string {
                return claimValue;
            } else {
                // If it's an array, return the first element
                if claimValue.length() > 0 {
                    return claimValue[0];
                }
            }
        }
    }
    return "N/A";
}

// Function to get email from user claims (handles both claims and addedClaims)
function getEmailFromClaims(UserClaim[]? claims) returns string {
    if claims is () {
        return "N/A";
    }
    
    foreach UserClaim claim in claims {
        if claim.uri == "http://wso2.org/claims/emailaddress" {
            string|string[] claimValue = claim.value;
            if claimValue is string {
                return claimValue;
            } else {
                // If it's an array, return the first element
                if claimValue.length() > 0 {
                    return claimValue[0];
                }
            }
        }
    }
    return "N/A";
}

// Function to get claim value by URI from user claims
function getClaimValueByUri(UserClaim[]? claims, string claimUri) returns string {
    if claims is () {
        return "N/A";
    }
    
    foreach UserClaim claim in claims {
        if claim.uri == claimUri {
            string|string[] claimValue = claim.value;
            if claimValue is string {
                return claimValue;
            } else {
                // If it's an array, return the first element
                if claimValue.length() > 0 {
                    return claimValue[0];
                }
            }
        }
    }
    return "N/A";
}

// Function to get claim value as string array by URI from user claims
function getClaimValueArrayByUri(UserClaim[]? claims, string claimUri) returns string[] {
    if claims is () {
        return [];
    }
    
    foreach UserClaim claim in claims {
        if claim.uri == claimUri {
            string|string[] claimValue = claim.value;
            if claimValue is string {
                return [claimValue];
            } else {
                return claimValue;
            }
        }
    }
    return [];
}

// Function to get all claim URIs from user claims
function getClaimUris(UserClaim[]? claims) returns string[] {
    if claims is () {
        return [];
    }
    
    string[] claimUris = [];
    foreach UserClaim claim in claims {
        claimUris.push(claim.uri);
    }
    return claimUris;
}

// Function to format claim values for logging
function formatClaimValues(UserClaim[]? claims) returns map<string> {
    if claims is () {
        return {};
    }
    
    map<string> formattedClaims = {};
    foreach UserClaim claim in claims {
        string claimKey = claim.uri;
        string|string[] claimValue = claim.value;
        
        if claimValue is string {
            formattedClaims[claimKey] = claimValue;
        } else {
            // Join array values with comma
            formattedClaims[claimKey] = string:'join(", ", ...claimValue);
        }
    }
    return formattedClaims;
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
    byte[] secretBytes = webhookKey.toBytes();
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
        check processEventByType(eventType, setPayload.iat, eventData, setPayload.jti);
    }
}

// Function to process events based on their type URL
function processEventByType(string eventType, int issuedAt, json eventData, string eventId) returns error? {

    string readableEventType = extractEventTypeName(eventType);
    
    // Process different event types based on readable event type name
    if readableEventType == "sessionEstablished" {
        SessionEstablishedEvent|error sessionEvent = eventData.cloneWithType(SessionEstablishedEvent);
        if sessionEvent is error {
            log:printError("Failed to parse session established event", sessionEvent);
            return;
        }
        
        string username = getUsernameFromClaims(sessionEvent.user?.claims);
        log:printInfo("Processing session established event",
                sessionId = sessionEvent.session.id,
                userId = sessionEvent.user?.id ?: "N/A",
                username = username,
                userStoreName = sessionEvent.userStore.name,
                tenantName = sessionEvent.tenant.name,
                applicationName = sessionEvent.application.name,
                loginTime = sessionEvent.session.loginTime);
        
        error? response = sendEventToSplunk(readableEventType, issuedAt, sessionEvent, eventId);
        if response is error {
            log:printError(string`Failed to publish session establish event ${eventId} caused by - ${response.detail().toString()}`);
        }
    } else if readableEventType == "loginSuccess" {
        LoginSuccessEvent|error loginEvent = eventData.cloneWithType(LoginSuccessEvent);
        if loginEvent is error {
            log:printError("Failed to parse login success event", loginEvent);
            return;
        }
        
        string username = getUsernameFromClaims(loginEvent.user?.claims);
        log:printInfo("Processing login success event",
                userId = loginEvent.user?.id ?: "N/A",
                username = username,
                userStoreName = loginEvent.userStore.name,
                tenantName = loginEvent.tenant.name,
                applicationName = loginEvent.application.name,
                authenticationMethods = loginEvent.authenticationMethods);
                
        error? response = sendEventToSplunk(readableEventType, issuedAt, loginEvent, eventId);
        if response is error {
            log:printError(string`Failed to publish login success event ${eventId} caused by - ${response.detail().toString()}`);
        }
    } else if readableEventType == "accessTokenIssued" {
        AccessTokenIssuedEvent|error tokenEvent = eventData.cloneWithType(AccessTokenIssuedEvent);
        if tokenEvent is error {
            log:printError("Failed to parse access token issued event", tokenEvent);
            return;
        }
        
        string username = getUsernameFromClaims(tokenEvent.user?.claims);
        log:printInfo("Processing access token issued event",
                userId = tokenEvent.user?.id ?: "N/A",
                username = username,
                userStoreName = tokenEvent.userStore.name,
                tenantName = tokenEvent.tenant.name,
                applicationName = tokenEvent.application.name,
                consumerKey = tokenEvent.application?.consumerKey ?: "N/A",
                tokenType = tokenEvent.accessToken.tokenType,
                grantType = tokenEvent.accessToken.grantType,
                issuedAt = tokenEvent.accessToken.iat);
                
    } else if readableEventType == "accessTokenRevoked" {
        AccessTokenRevokedEvent|error revokeEvent = eventData.cloneWithType(AccessTokenRevokedEvent);
        if revokeEvent is error {
            log:printError("Failed to parse access token revoked event", revokeEvent);
            return;
        }
        
        string username = getUsernameFromClaims(revokeEvent.user?.claims);
        string[] applicationNames = [];
        foreach Application app in revokeEvent.applications {
            applicationNames.push(app.name);
        }
        
        log:printInfo("Processing access token revoked event",
                userId = revokeEvent.user?.id ?: "N/A",
                username = username,
                userStoreName = revokeEvent.userStore.name,
                tenantName = revokeEvent.tenant.name,
                applicationNames = applicationNames);
                
    } else if readableEventType == "sessionRevoked" {
        SessionRevokedEvent|error sessionRevokeEvent = eventData.cloneWithType(SessionRevokedEvent);
        if sessionRevokeEvent is error {
            log:printError("Failed to parse session revoked event", sessionRevokeEvent);
            return;
        }
        
        string username = getUsernameFromClaims(sessionRevokeEvent.user?.claims);
        string[] sessionIds = [];
        foreach Session session in sessionRevokeEvent.sessions {
            sessionIds.push(session.id);
        }
        
        log:printInfo("Processing session revoked event",
                userId = sessionRevokeEvent.user?.id ?: "N/A",
                username = username,
                userStoreName = sessionRevokeEvent.userStore.name,
                tenantName = sessionRevokeEvent.tenant.name,
                sessionIds = sessionIds);

        error? response = sendEventToSplunk(readableEventType, issuedAt, sessionRevokeEvent, eventId);
        if response is error {
            log:printError(string`Failed to publish session revoke event ${eventId} caused by - ${response.detail().toString()}`);
        }        
    } else if readableEventType == "userCreated" {
        UserCreatedEvent|error userEvent = eventData.cloneWithType(UserCreatedEvent);
        if userEvent is error {
            log:printError("Failed to parse user created event", userEvent);
            return;
        }
        
        string username = getUsernameFromClaims(userEvent.user?.claims);
        string email = getEmailFromClaims(userEvent.user?.claims);
        
        log:printInfo("Processing user created event",
                userId = userEvent.user?.id ?: "N/A",
                username = username,
                email = email,
                userStoreName = userEvent.userStore.name,
                tenantName = userEvent.tenant.name,
                initiatorType = userEvent.initiatorType,
                action = userEvent.action);
                
    } else if readableEventType == "userAccountLocked" {
        UserAccountLockedEvent|error lockEvent = eventData.cloneWithType(UserAccountLockedEvent);
        if lockEvent is error {
            log:printError("Failed to parse user account locked event", lockEvent);
            return;
        }
        
        string email = getEmailFromClaims(lockEvent.user?.claims);
        
        log:printInfo("Processing user account locked event",
                userId = lockEvent.user?.id ?: "N/A",
                email = email,
                userStoreName = lockEvent.userStore.name,
                tenantName = lockEvent.tenant.name,
                reason = lockEvent?.reason ?: "N/A");
                
    } else if readableEventType == "userAccountUnlocked" {
        UserAccountUnlockedEvent|error unlockEvent = eventData.cloneWithType(UserAccountUnlockedEvent);
        if unlockEvent is error {
            log:printError("Failed to parse user account unlocked event", unlockEvent);
            return;
        }
        
        string email = getEmailFromClaims(unlockEvent.user?.claims);
        
        log:printInfo("Processing user account unlocked event",
                userId = unlockEvent.user?.id ?: "N/A",
                email = email,
                userStoreName = unlockEvent.userStore.name,
                tenantName = unlockEvent.tenant.name);
                
    } else if readableEventType == "credentialUpdated" {
        CredentialUpdatedEvent|error credEvent = eventData.cloneWithType(CredentialUpdatedEvent);
        if credEvent is error {
            log:printError("Failed to parse credential updated event", credEvent);
            return;
        }
        
        string email = getEmailFromClaims(credEvent.user?.claims);
        
        log:printInfo("Processing credential updated event",
                userId = credEvent.user?.id ?: "N/A",
                email = email,
                userStoreName = credEvent.userStore.name,
                tenantName = credEvent.tenant.name,
                credentialType = credEvent.credentialType,
                action = credEvent.action,
                initiatorType = credEvent.initiatorType);
                
    } else if readableEventType == "userProfileUpdated" {
        UserProfileUpdatedEvent|error profileEvent = eventData.cloneWithType(UserProfileUpdatedEvent);
        if profileEvent is error {
            log:printError("Failed to parse user profile updated event", profileEvent);
            return;
        }
        
        // Extract information about added and updated claims
        string[] addedClaimUris = getClaimUris(profileEvent.user?.addedClaims);
        string[] updatedClaimUris = getClaimUris(profileEvent.user?.updatedClaims);
        
        // Format claim values for better logging
        map<string> addedClaimsFormatted = formatClaimValues(profileEvent.user?.addedClaims);
        map<string> updatedClaimsFormatted = formatClaimValues(profileEvent.user?.updatedClaims);
        
        // Extract specific claim values for detailed logging
        string jobTitle = getClaimValueByUri(profileEvent.user?.addedClaims, "http://wso2.org/claims/jobTitle");
        string marketingConsent = getClaimValueByUri(profileEvent.user?.updatedClaims, "http://wso2.org/claims/marketing_consent");
        string[] emailAddresses = getClaimValueArrayByUri(profileEvent.user?.updatedClaims, "http://wso2.org/claims/emailAddresses");
        string[] mobileNumbers = getClaimValueArrayByUri(profileEvent.user?.updatedClaims, "http://wso2.org/claims/mobileNumbers");
        string mobile = getClaimValueByUri(profileEvent.user?.updatedClaims, "http://wso2.org/claims/mobile");
        string lastName = getClaimValueByUri(profileEvent.user?.updatedClaims, "http://wso2.org/claims/lastname");
        
        log:printInfo("Processing user profile updated event",
                userId = profileEvent.user?.id ?: "N/A",
                userRef = profileEvent.user?.ref ?: "N/A",
                userStoreName = profileEvent.userStore.name,
                tenantName = profileEvent.tenant.name,
                organizationName = profileEvent.organization.name,
                action = profileEvent.action,
                initiatorType = profileEvent.initiatorType,
                addedClaimCount = addedClaimUris.length(),
                updatedClaimCount = updatedClaimUris.length(),
                addedClaimUris = addedClaimUris,
                updatedClaimUris = updatedClaimUris);
        
        // Log detailed claim information if there are added claims
        if addedClaimsFormatted.length() > 0 {
            log:printInfo("User profile added claims details",
                    userId = profileEvent.user?.id ?: "N/A",
                    addedClaims = addedClaimsFormatted,
                    jobTitle = jobTitle);
        }
        
        // Log detailed claim information if there are updated claims
        if updatedClaimsFormatted.length() > 0 {
            log:printInfo("User profile updated claims details",
                    userId = profileEvent.user?.id ?: "N/A",
                    updatedClaims = updatedClaimsFormatted,
                    marketingConsent = marketingConsent,
                    emailAddresses = emailAddresses,
                    mobileNumbers = mobileNumbers,
                    mobile = mobile,
                    lastName = lastName);
        }
                
    } else if readableEventType == "userDeleted" {
        UserDeletedEvent|error deleteEvent = eventData.cloneWithType(UserDeletedEvent);
        if deleteEvent is error {
            log:printError("Failed to parse user deleted event", deleteEvent);
            return;
        }
        
        string username = getUsernameFromClaims(deleteEvent.user?.claims);
        
        log:printInfo("Processing user deleted event",
                userId = deleteEvent.user?.id ?: "N/A",
                username = username,
                userStoreName = deleteEvent.userStore.name,
                tenantName = deleteEvent.tenant.name,
                initiatorType = deleteEvent.initiatorType);
                
    } else if readableEventType == "loginFailed" {
        LoginFailedEvent|error failedEvent = eventData.cloneWithType(LoginFailedEvent);
        if failedEvent is error {
            log:printError("Failed to parse login failed event", failedEvent);
            return;
        }
        
        string username = getUsernameFromClaims(failedEvent.user?.claims);
        
        log:printInfo("Processing login failed event",
                username = username,
                tenantName = failedEvent.tenant.name,
                organizationName = failedEvent.organization.name,
                applicationName = failedEvent.application.name,
                reasonDescription = failedEvent.reason.description,
                failedStep = failedEvent.reason.context.failedStep.step,
                failedIdp = failedEvent.reason.context.failedStep.idp);
        
        error? response = sendEventToSplunk(readableEventType, issuedAt, failedEvent, eventId);
        if response is error {
            log:printError(string`Failed to publish login failed event ${eventId} caused by - ${response.detail().toString()}`);
        } 
                
    } else {
        // For unsupported event types, log the raw event data
        string eventDataString = eventData.toJsonString();
        log:printInfo("Processing unsupported event type", 
                eventType = readableEventType,
                eventData = eventDataString);
    }
}
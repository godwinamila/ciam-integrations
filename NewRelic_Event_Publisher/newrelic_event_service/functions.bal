import ballerina/http;
import ballerina/log;

// Function to publish events to New Relic
function publishToNewRelic(NewRelicEvent[] events) returns error? {
    
    // Create request headers
    map<string|string[]> headers = {
        "Content-Type": "application/json",
        "Api-Key": newRelicApiKey
    };
    
    // Send POST request to New Relic Events API
    http:Response|error response = newRelicClient->post(path = "", message = events, headers = headers);
    
    if response is error {
        log:printError("Failed to publish events to New Relic", response);
        return error("Failed to publish events to New Relic", response);
    }
    
    // Check response status
    int statusCode = response.statusCode;
    if statusCode >= 200 && statusCode < 300 {
        log:printInfo("Successfully published events to New Relic", 
                     eventCount = events.length(), 
                     statusCode = statusCode);
    } else {
        string|error responseBody = response.getTextPayload();
        string bodyText = responseBody is error ? "Unable to read response" : responseBody;
        log:printError("New Relic API returned error status", 
                      statusCode = statusCode, 
                      responseBody = bodyText);
        return error(string `New Relic API error: ${statusCode} - ${bodyText}`);
    }
}

// Function to flatten any event data to New Relic format
function transformEventToNewRelic(string eventTypeUrl, json eventData) returns NewRelicEvent|error {
    
    // Extract event type from URL (e.g., "loginSuccess" from full URL)
    string eventTypeName = extractEventTypeName(eventTypeUrl);
    
    // Create New Relic event with eventType
    NewRelicEvent newRelicEvent = {
        eventType: string `Asgardeo${eventTypeName}`
    };
    
    // Check if this is a login success event to handle claims specially
    boolean isLoginSuccess = eventTypeUrl.includes("loginSuccess");
    
    // Flatten the event data and add all fields to the New Relic event
    map<anydata> flattenedData = {};
    if isLoginSuccess {
        flattenedData = flattenJsonWithClaimsHandling(eventData, "");
    } else {
        flattenedData = flattenJson(eventData, "");
    }
    
    // Add all flattened fields to the New Relic event
    string[] flattenedKeys = flattenedData.keys();
    foreach string key in flattenedKeys {
        anydata value = flattenedData.get(key);
        newRelicEvent[key] = value;
    }
    
    return newRelicEvent;
}

// Function to extract event type name from event type URL
function extractEventTypeName(string eventTypeUrl) returns string {
    
    // Find the last occurrence of "/" to get the event type name
    int? lastSlashIndex = eventTypeUrl.indexOf("/", eventTypeUrl.length() - 1);
    int searchIndex = 0;
    int foundIndex = -1;
    
    // Find all occurrences of "/" to get the last one
    while true {
        int? currentIndex = eventTypeUrl.indexOf("/", searchIndex);
        if currentIndex is () {
            break;
        }
        foundIndex = currentIndex;
        searchIndex = currentIndex + 1;
    }
    
    string eventTypeName = "";
    if foundIndex >= 0 && foundIndex < eventTypeUrl.length() - 1 {
        eventTypeName = eventTypeUrl.substring(foundIndex + 1);
    } else {
        eventTypeName = eventTypeUrl;
    }
    
    // Capitalize first letter for consistent naming
    if eventTypeName.length() > 0 {
        string firstChar = eventTypeName.substring(0, 1).toUpperAscii();
        string restChars = eventTypeName.substring(1);
        return firstChar + restChars;
    }
    
    return "UnknownEvent";
}

// Function to recursively flatten JSON data with special handling for claims arrays
function flattenJsonWithClaimsHandling(json data, string prefix) returns map<anydata> {
    
    map<anydata> result = {};
    
    if data is map<json> {
        // Handle JSON objects
        string[] dataKeys = data.keys();
        foreach string key in dataKeys {
            json value = data.get(key);
            string newKey = prefix == "" ? key : string `${prefix}_${key}`;
            
            // Special handling for claims arrays
            if key == "claims" && value is json[] {
                map<anydata> claimsResult = processClaims(value, prefix);
                string[] claimsKeys = claimsResult.keys();
                foreach string claimsKey in claimsKeys {
                    anydata claimsValue = claimsResult.get(claimsKey);
                    result[claimsKey] = claimsValue;
                }
            } else if value is map<json> || value is json[] {
                // Recursively flatten nested objects and arrays
                map<anydata> nestedResult = flattenJsonWithClaimsHandling(value, newKey);
                string[] nestedKeys = nestedResult.keys();
                foreach string nestedKey in nestedKeys {
                    anydata nestedValue = nestedResult.get(nestedKey);
                    result[nestedKey] = nestedValue;
                }
            } else {
                // Add primitive values directly
                result[newKey] = value;
            }
        }
    } else if data is json[] {
        // Handle JSON arrays (but not claims arrays, which are handled above)
        foreach int index in 0 ..< data.length() {
            json arrayItem = data[index];
            string arrayKey = string `${prefix}_${index}`;
            
            if arrayItem is map<json> || arrayItem is json[] {
                // Recursively flatten nested objects and arrays in array
                map<anydata> nestedResult = flattenJsonWithClaimsHandling(arrayItem, arrayKey);
                string[] nestedKeys = nestedResult.keys();
                foreach string nestedKey in nestedKeys {
                    anydata nestedValue = nestedResult.get(nestedKey);
                    result[nestedKey] = nestedValue;
                }
            } else {
                // Add primitive array values directly
                result[arrayKey] = arrayItem;
            }
        }
        
        // Also add the array length for reference
        result[string `${prefix}_length`] = data.length();
        
    } else {
        // Handle primitive values
        if prefix != "" {
            result[prefix] = data;
        }
    }
    
    return result;
}

// Function to process claims array and use URI as key
function processClaims(json[] claimsArray, string prefix) returns map<anydata> {
    
    map<anydata> result = {};
    
    foreach json claimItem in claimsArray {
        if claimItem is map<json> {
            // Extract URI and value from claim object
            json uriValue = claimItem.get("uri");
            json valueValue = claimItem.get("value");
            
            if uriValue is string {
                // Use the URI as the key directly
                string claimKey = uriValue;
                
                // Clean up the URI to make it a valid field name
                // Remove protocol and replace special characters with underscores
                string cleanKey = cleanClaimUri(claimKey);
                
                // Add prefix if provided
                string finalKey = prefix == "" ? cleanKey : string `${prefix}_${cleanKey}`;
                
                result[finalKey] = valueValue;
            }
        }
    }
    
    // Also add the claims count for reference
    string countKey = prefix == "" ? "claims_count" : string `${prefix}_claims_count`;
    result[countKey] = claimsArray.length();
    
    return result;
}

// Function to clean claim URI to make it a valid field name
function cleanClaimUri(string uri) returns string {
    
    // Remove common prefixes to make the key shorter and cleaner
    string cleanedUri = uri;
    
    if cleanedUri.startsWith("http://wso2.org/claims/") {
        cleanedUri = cleanedUri.substring(23); // Remove "http://wso2.org/claims/"
    } else if cleanedUri.startsWith("https://wso2.org/claims/") {
        cleanedUri = cleanedUri.substring(24); // Remove "https://wso2.org/claims/"
    } else if cleanedUri.startsWith("http://") {
        cleanedUri = cleanedUri.substring(7); // Remove "http://"
    } else if cleanedUri.startsWith("https://") {
        cleanedUri = cleanedUri.substring(8); // Remove "https://"
    }
    
    // Replace special characters with underscores by building a new string
    string result = "";
    foreach int i in 0 ..< cleanedUri.length() {
        string char = cleanedUri.substring(i, i + 1);
        // Check if character is alphanumeric
        int[] charBytes = char.toCodePointInts();
        if charBytes.length() > 0 {
            int charCode = charBytes[0];
            // Check if it's a letter (A-Z, a-z) or digit (0-9)
            if (charCode >= 65 && charCode <= 90) || (charCode >= 97 && charCode <= 122) || (charCode >= 48 && charCode <= 57) {
                result = result + char;
            } else {
                result = result + "_";
            }
        } else {
            result = result + "_";
        }
    }
    
    // Remove multiple consecutive underscores by rebuilding the string
    string finalResult = "";
    boolean lastWasUnderscore = false;
    foreach int i in 0 ..< result.length() {
        string char = result.substring(i, i + 1);
        if char == "_" {
            if !lastWasUnderscore {
                finalResult = finalResult + char;
                lastWasUnderscore = true;
            }
        } else {
            finalResult = finalResult + char;
            lastWasUnderscore = false;
        }
    }
    
    // Remove leading and trailing underscores
    string trimmedResult = finalResult.trim();
    if trimmedResult.startsWith("_") && trimmedResult.length() > 1 {
        trimmedResult = trimmedResult.substring(1);
    }
    if trimmedResult.endsWith("_") && trimmedResult.length() > 1 {
        trimmedResult = trimmedResult.substring(0, trimmedResult.length() - 1);
    }
    
    // Ensure the result is not empty
    if trimmedResult == "" || trimmedResult == "_" {
        trimmedResult = "claim";
    }
    
    return trimmedResult;
}

// Function to recursively flatten JSON data (original function for non-login events)
function flattenJson(json data, string prefix) returns map<anydata> {
    
    map<anydata> result = {};
    
    if data is map<json> {
        // Handle JSON objects
        string[] dataKeys = data.keys();
        foreach string key in dataKeys {
            json value = data.get(key);
            string newKey = prefix == "" ? key : string `${prefix}_${key}`;
            
            if value is map<json> || value is json[] {
                // Recursively flatten nested objects and arrays
                map<anydata> nestedResult = flattenJson(value, newKey);
                string[] nestedKeys = nestedResult.keys();
                foreach string nestedKey in nestedKeys {
                    anydata nestedValue = nestedResult.get(nestedKey);
                    result[nestedKey] = nestedValue;
                }
            } else {
                // Add primitive values directly
                result[newKey] = value;
            }
        }
    } else if data is json[] {
        // Handle JSON arrays
        foreach int index in 0 ..< data.length() {
            json arrayItem = data[index];
            string arrayKey = string `${prefix}_${index}`;
            
            if arrayItem is map<json> || arrayItem is json[] {
                // Recursively flatten nested objects and arrays in array
                map<anydata> nestedResult = flattenJson(arrayItem, arrayKey);
                string[] nestedKeys = nestedResult.keys();
                foreach string nestedKey in nestedKeys {
                    anydata nestedValue = nestedResult.get(nestedKey);
                    result[nestedKey] = nestedValue;
                }
            } else {
                // Add primitive array values directly
                result[arrayKey] = arrayItem;
            }
        }
        
        // Also add the array length for reference
        result[string `${prefix}_length`] = data.length();
        
    } else {
        // Handle primitive values
        if prefix != "" {
            result[prefix] = data;
        }
    }
    
    return result;
}
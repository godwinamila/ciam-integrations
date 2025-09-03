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
    
    // Flatten the event data and add all fields to the New Relic event
    map<anydata> flattenedData = flattenJson(eventData, "");
    
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

// Function to recursively flatten JSON data
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
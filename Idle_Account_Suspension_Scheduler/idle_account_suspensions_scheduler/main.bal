import ballerina/io;
import ballerina/log;

public function main() returns error? {
    io:println("Starting Idle Account Management Automation Suite...");
    io:println("Automation mode: " + automationMode.toString());
    io:println("Inactive days threshold: " + inactiveDaysThreshold.toString());
    io:println("");
    
    log:printInfo("Automation suite started with mode: " + automationMode.toString());
    
    // Execute the appropriate automation based on mode
    error? result = ();
    
    if automationMode == LIST {
        result = runListAutomation();
    } else if automationMode == DISABLE {
        result = runDisableAutomation();
    } else if automationMode == DELETE {
        result = runDeleteAutomation();
    } else {
        string errorMsg = "Unknown automation mode: " + automationMode.toString();
        log:printError(errorMsg);
        return error(errorMsg);
    }
    
    if result is error {
        io:println("Automation failed: " + result.message());
        log:printError("Automation failed: " + result.message());
        return result;
    }
    
    io:println("");
    io:println("Idle Account Management Automation completed successfully.");
    log:printInfo("Automation suite completed successfully");
}

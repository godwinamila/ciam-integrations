import ballerina/io;

public function main() returns error? {
    io:println("Starting Idle Account Suspensions Task...");
    io:println("Operation type: " + operationType.toString());
    io:println("Inactive days threshold: " + inactiveDaysThreshold.toString());
    
    // Run the processing once
    error? result = processInactiveUsers();
    if result is error {
        io:println("Task failed: " + result.message());
        return result;
    }
    
    io:println("Idle Account Suspensions Task completed successfully.");
}
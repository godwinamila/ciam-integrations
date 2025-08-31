import ballerina/http;
import ballerina/io;

// HTTP service for business signup
service /signup on new http:Listener(8081) {
    
    // POST endpoint for business signup
    resource function post createUser(BusinessSignupRequest payload) returns BusinessSignupResponse|http:BadRequest {
        
        // Extract key business information from the payload with proper type casting
        string? givenNameValue = payload["http://wso2.org/claims/givenname"] is string ? <string>payload["http://wso2.org/claims/givenname"] : ();
        string? lastNameValue = payload["http://wso2.org/claims/lastname"] is string ? <string>payload["http://wso2.org/claims/lastname"] : ();
        string? mobileValue = payload["http://wso2.org/claims/mobile"] is string ? <string>payload["http://wso2.org/claims/mobile"] : ();
        string? countryValue = payload["http://wso2.org/claims/country"] is string ? <string>payload["http://wso2.org/claims/country"] : ();
        string? marketingConsentValue = payload["http://wso2.org/claims/marketing_consent"] is string ? <string>payload["http://wso2.org/claims/marketing_consent"] : ();
        string? emailAddressValue = payload["http://wso2.org/claims/emailaddress"] is string ? <string>payload["http://wso2.org/claims/emailaddress"] : ();
        
        BusinessInfo businessInfo = {
            givenName: givenNameValue,
            lastName: lastNameValue,
            mobile: mobileValue,
            country: countryValue,
            marketingConsent: marketingConsentValue,
            institution: payload?.institution,
            registeredBusinessNumber: payload?.registeredBusinessNumber,
            emailAddress: emailAddressValue
        };
        
        // Log the business information using io:println
        io:println("=== Business Signup Information ===");
        io:println("Given Name: ", businessInfo.givenName ?: "Not provided");
        io:println("Last Name: ", businessInfo.lastName ?: "Not provided");
        io:println("Email Address: ", businessInfo.emailAddress ?: "Not provided");
        io:println("Mobile: ", businessInfo.mobile ?: "Not provided");
        io:println("Country: ", businessInfo.country ?: "Not provided");
        io:println("Institution: ", businessInfo.institution ?: "Not provided");
        io:println("Registered Business Number: ", businessInfo.registeredBusinessNumber ?: "Not provided");
        io:println("Marketing Consent: ", businessInfo.marketingConsent ?: "Not provided");
        io:println("===================================");
        
        // Create response
        BusinessSignupResponse response = {
            status: "success",
            message: "Business signup information received successfully",
            businessInfo: businessInfo
        };
        
        return response;
    }

    // GET endpoint that accepts businessName as query parameter
    resource function get businessData(string businessName) returns BusinessNameResponse|http:BadRequest {
        
        // Log the received business name
        io:println("=== Business Name Request ===");
        io:println("Business Name: ", businessName);
        io:println("=============================");
        
        // Create response with the business name
        BusinessNameResponse response = {
            status: "success",
            message: "Business name retrieved successfully",
            businessName: businessName
        };
        
        return response;
    }
}
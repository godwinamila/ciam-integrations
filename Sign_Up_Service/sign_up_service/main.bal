import ballerina/http;
import ballerina/log;

// HTTP service for business signup
service /signup on new http:Listener(8081) {
    
    // POST endpoint for business signup
    resource function post createUser(BusinessSignupRequest payload) returns http:Found|http:BadRequest {
        
        // Extract key business information from the payload with proper type casting
        string? givenNameValue = payload["http://wso2.org/claims/givenname"] is string ? <string>payload["http://wso2.org/claims/givenname"] : ();
        string? lastNameValue = payload["http://wso2.org/claims/lastname"] is string ? <string>payload["http://wso2.org/claims/lastname"] : ();
        string? mobileValue = payload["http://wso2.org/claims/mobile"] is string ? <string>payload["http://wso2.org/claims/mobile"] : ();
        string? countryValue = payload["http://wso2.org/claims/country"] is string ? <string>payload["http://wso2.org/claims/country"] : ();
        string? marketingConsentValue = payload["marketingConsent"] is string ? <string>payload["marketingConsent"] : ();
        string? emailAddressValue = payload["http://wso2.org/claims/emailaddress"] is string ? <string>payload["http://wso2.org/claims/emailaddress"] : ();
        string? password = payload["password"] is string ? <string>payload["password"] : ();
        string? signInURL = payload["signInURL"] is string ? <string>payload["signInURL"] : ();
        
        BusinessInfo businessInfo = {
            givenName: givenNameValue,
            lastName: lastNameValue,
            mobile: mobileValue,
            country: countryValue,
            marketingConsent: marketingConsentValue,
            institution: payload?.institution,
            registeredBusinessNumber: payload?.registeredBusinessNumber,
            emailAddress: emailAddressValue,
            password: password
        };
        
        // Log the business information using log:printInfo
        log:printInfo("=== Business Signup Information ===");
        log:printInfo("Given Name: " + (businessInfo.givenName ?: "Not provided"));
        log:printInfo("Last Name: " + (businessInfo.lastName ?: "Not provided"));
        log:printInfo("Email Address: " + (businessInfo.emailAddress ?: "Not provided"));
        log:printInfo("Mobile: " + (businessInfo.mobile ?: "Not provided"));
        log:printInfo("Country: " + (businessInfo.country ?: "Not provided"));
        log:printInfo("Institution: " + (businessInfo.institution ?: "Not provided"));
        log:printInfo("Registered Business Number: " + (businessInfo.registeredBusinessNumber ?: "Not provided"));
        log:printInfo("Marketing Consent: " + (businessInfo.marketingConsent ?: "Not provided"));
        log:printInfo("signInURL: " + (signInURL ?: "Not provided"));
        log:printInfo("===================================");
        
        // Handle organization setup
        OrganizationInfo? organizationInfo = ();
        if businessInfo.institution is string {
            string institutionName = <string>businessInfo.institution;
            OrganizationInfo?|error orgResult = handleOrganizationSetup(institutionName);
            
            if orgResult is error {
                log:printInfo("Error setting up organization: " + orgResult.message());
                return <http:BadRequest>{
                    body: {
                        "error": "Failed to setup organization",
                        "message": orgResult.message()
                    }
                };
            }
            organizationInfo = orgResult;
        }
        
        // Handle user creation, group assignment, and sharing only if organization info is available
        if organizationInfo is OrganizationInfo {
            error? userCreationResult = handleUserCreationFlow(businessInfo, organizationInfo);
            if userCreationResult is error {
                log:printInfo("Error in user creation flow: " + userCreationResult.message());
                return <http:BadRequest>{
                    body: {
                        "error": "Failed to complete user creation flow",
                        "message": userCreationResult.message()
                    }
                };
            }
        }

        // Determine redirect URL - use signInURL from request if provided, otherwise use configured URL
        string redirectUrl = signInURL ?: successRedirectUrl;
        
        // User creation flow completed successfully, redirect to determined URL
        log:printInfo("User creation flow completed successfully. Redirecting to: " + redirectUrl);
        return <http:Found>{
            headers: {
                "location": redirectUrl
            }
        };
    }

    // GET endpoint that accepts businessName as query parameter
    resource function get businessData(string businessName) returns BusinessNameResponse|http:BadRequest {
        
        // Log the received business name
        log:printInfo("=== Business Name Request ===");
        log:printInfo("Business Name: " + businessName);
        log:printInfo("=============================");
        
        // Create response with the business name
        BusinessNameResponse response = {
            status: "success",
            message: "Business name retrieved successfully",
            businessName: businessName
        };
        
        return response;
    }
}
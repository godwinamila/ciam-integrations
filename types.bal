// Business signup request payload structure
public type BusinessSignupRequest record {|
    string isSaaSApp?;
    string usernameInput?;
    string username?;
    string password?;
    string previous_step?;
    string client_id?;
    string code_challenge?;
    string code_challenge_method?;
    string commonAuthCallerPath?;
    string forceAuth?;
    string passiveAuth?;
    string redirect_uri?;
    string response_mode?;
    string response_type?;
    string scope?;
    string state?;
    string sessionDataKey?;
    string relyingParty?;
    string 'type?;
    string sp?;
    string spId?;
    string authenticators?;
    string callback?;
    string isSelfRegistrationWithVerification?;
    string userType?;
    string institution?;
    string registeredBusinessNumber?;

    // Allow additional fields including the claim fields with special characters
    anydata...;
|};

// Extracted business information for subsequent integrations
public type BusinessInfo record {|
    string? givenName;
    string? lastName;
    string? mobile;
    string? country;
    string? marketingConsent;
    string? institution;
    string? registeredBusinessNumber;
    string? emailAddress;
|};

// Response structure
public type BusinessSignupResponse record {|
    string status;
    string message;
    BusinessInfo businessInfo;
|};

// Business name response structure
public type BusinessNameResponse record {|
    string status;
    string message;
    string businessName;
|};
// Security Event Token (SET) payload structure
public type SecurityEventToken record {|
    string iss; // Issuer
    int iat; // Issued At timestamp
    string jti; // JWT ID
    map<json> events; // Events object with dynamic keys
    anydata...;
|};

// Registration success event data
public type RegistrationSuccessEvent record {|
    string initiatorType;
    RegistrationUserInfo user;
    TenantInfo tenant;
    UserStoreInfo userStore;
    string action;
    anydata...;
|};

// User profile updated event data
public type UserProfileUpdatedEvent record {|
    string initiatorType;
    ProfileUpdateUserInfo user;
    TenantInfo tenant;
    UserStoreInfo userStore;
    string action;
    anydata...;
|};

// User deleted event data
public type UserDeletedEvent record {|
    string initiatorType;
    RegistrationUserInfo user;
    TenantInfo tenant;
    UserStoreInfo userStore;
    anydata...;
|};

// User info for registration events
public type RegistrationUserInfo record {|
    string id;
    string ref;
    UserClaim[] claims;
    anydata...;
|};

// User info for profile update events
public type ProfileUpdateUserInfo record {|
    string id;
    string ref;
    UserClaim[] addedClaims?;
    UserClaim[] updatedClaims?;
    anydata...;
|};

// User claim structure - value can be string or string array
public type UserClaim record {|
    string uri;
    string|string[] value;
    anydata...;
|};

// Tenant info structure
public type TenantInfo record {
    string id;
    string name;
};

// User store info structure
public type UserStoreInfo record {
    string id;
    string name;
};

// Webhook response
public type WebhookResponse record {
    string message;
    boolean success;
};

// Webhook subscription verification parameters
public type SubscriptionVerification record {
    string hubMode;
    string hubTopic;
    string hubChallenge;
    string hubLeaseSeconds;
};

// Processed user data ready for Azure creation
public type AzureUserData record {
    string mailNickname;
    string userPrincipalName;
    string mail;
    boolean accountEnabled;
    string displayName;
};

// Password profile for Azure AD user
public type PasswordProfile record {
    string password;
    boolean forceChangePasswordNextSignIn;
};

// Identity for Azure AD user
public type Identity record {
    string signInType;
    string issuer;
    string issuerAssignedId;
};

// Azure AD user creation request
public type AzureUserRequest record {
    boolean accountEnabled;
    string displayName;
    string userPrincipalName;
    string mail;
    string mailNickname;
    PasswordProfile passwordProfile;
};

// Azure AD user creation response
public type AzureUserResponse record {|
    string id?;
    string displayName?;
    string userPrincipalName?;
    string mail?;
    anydata...;
|};

// OAuth2 token response
public type TokenResponse record {|
    string access_token;
    string token_type;
    int expires_in;
    anydata...;
|};

// Security Event Token structure
public type SecurityEventToken record {|
    string iss; // Issuer
    int iat; // Issued At timestamp
    string jti; // JWT ID
    string? rci?; // Request correlation ID
    map<json> events; // Events object with dynamic keys
    anydata...;
|};

// Webhook response
public type WebhookResponse record {|
    string message;
    boolean success;
    anydata...;
|};

// Webhook subscription verification parameters
public type SubscriptionVerification record {|
    string hubMode;
    string hubTopic;
    string hubChallenge;
    string hubLeaseSeconds;
    anydata...;
|};

// Common nested types
public type UserClaim record {|
    string uri;
    string|string[] value;
    anydata...;
|};

public type Organization record {|
    string id;
    string name;
    string orgHandle;
    int depth;
    anydata...;
|};

public type User record {|
    string? id?;
    UserClaim[]? claims?; // Made optional since some events don't have claims
    Organization? organization?;
    string? ref?;
    UserClaim[]? addedClaims?;
    UserClaim[]? updatedClaims?; // Added to handle updated claims
    anydata...;
|};

public type Tenant record {|
    string id;
    string name;
    anydata...;
|};

public type UserStore record {|
    string id;
    string name;
    anydata...;
|};

public type Application record {|
    string? id?;
    string name;
    string? consumerKey?;
    anydata...;
|};

public type Session record {|
    string id;
    int loginTime;
    Application[] applications;
    anydata...;
|};

public type AccessToken record {|
    string tokenType;
    string iat;
    string grantType;
    anydata...;
|};

// Reason structure for login failed events
public type FailedStep record {|
    int step;
    string idp;
    anydata...;
|};

public type ReasonContext record {|
    FailedStep failedStep;
    anydata...;
|};

public type Reason record {|
    string description;
    ReasonContext context;
    anydata...;
|};

// Event-specific types
public type SessionEstablishedEvent record {|
    User user;
    Tenant tenant;
    Organization organization;
    UserStore userStore;
    Application application;
    Session session;
    anydata...;
|};

public type LoginSuccessEvent record {|
    User user;
    Tenant tenant;
    Organization organization;
    UserStore userStore;
    Application application;
    string[] authenticationMethods;
    anydata...;
|};

public type LoginFailedEvent record {|
    User user;
    Tenant tenant;
    Organization organization;
    Application application;
    Reason reason;
    anydata...;
|};

public type AccessTokenIssuedEvent record {|
    User user;
    Tenant tenant;
    Organization organization;
    UserStore userStore;
    Application application;
    AccessToken accessToken;
    anydata...;
|};

public type AccessTokenRevokedEvent record {|
    User user;
    Tenant tenant;
    Organization organization;
    UserStore userStore;
    Application[] applications;
    anydata...;
|};

public type SessionRevokedEvent record {|
    User user;
    Tenant tenant;
    Organization organization;
    UserStore userStore;
    Session[] sessions;
    anydata...;
|};

public type UserCreatedEvent record {|
    string initiatorType;
    User user;
    Tenant tenant;
    Organization organization;
    UserStore userStore;
    string action;
    anydata...;
|};

public type UserAccountLockedEvent record {|
    User user;
    Tenant tenant;
    Organization organization;
    UserStore userStore;
    string? reason?;
    anydata...;
|};

public type UserAccountUnlockedEvent record {|
    User user;
    Tenant tenant;
    Organization organization;
    UserStore userStore;
    anydata...;
|};

public type CredentialUpdatedEvent record {|
    string initiatorType;
    User user;
    Tenant tenant;
    Organization organization;
    UserStore userStore;
    string credentialType;
    string action;
    anydata...;
|};

public type UserProfileUpdatedEvent record {|
    string initiatorType;
    User user;
    Tenant tenant;
    Organization organization;
    UserStore userStore;
    string action;
    anydata...;
|};

public type UserDeletedEvent record {|
    string initiatorType;
    User user;
    Tenant tenant;
    Organization organization;
    UserStore userStore;
    anydata...;
|};
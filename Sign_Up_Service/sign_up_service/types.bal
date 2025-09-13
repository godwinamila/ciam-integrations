// Business signup request payload structure
public type BusinessSignupRequest record {|
    string username?;
    string password?;
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
    string? emailAddress;
    string? password;
    string? registeredBusinessNumber;
|};

// Response structure
public type BusinessSignupResponse record {|
    string status;
    string message;
|};

// Business name response structure
public type BusinessDataResponse record {|
    string businessName;
    string registrationNo;
|};

// Asgardeo Organization API types
public type OrganizationAttribute record {|
    string key;
    string value;
|};

public type Organization record {|
    string id;
    string name;
    OrganizationAttribute[] attributes?;
    anydata...;
|};

public type OrganizationsResponse record {|
    Organization[] organizations?;
    anydata...;
|};

public type OrganizationCreateRequest record {|
    string name;
    OrganizationAttribute[] attributes;
|};

public type OrganizationCreateResponse record {|
    string id;
    string name;
    OrganizationAttribute[] attributes?;
    anydata...;
|};

public type UserCreateResponse record {|
    string id;
    string userName;
    anydata...;
|};

public type OrganizationInfo record {|
    string id;
    boolean isExistingOrg;
    string orgAdminGroupId;
    string accessToken;
|};

// Token switching types
public type TokenSwitchResponse record {|
    string access_token;
    string scope;
    string token_type;
    int expires_in;
|};

// SCIM2 Role types
public type RolePermission record {|
    string value;
|};

public type RoleAudience record {|
    string 'type;
    string value;
    string display?;
|};

public type RoleCreateRequest record {|
    RoleAudience audience;
    string displayName;
    RolePermission[] permissions;
    string[] schemas;
|};

public type RoleCreateResponse record {|
    string id;
    string displayName;
    RoleAudience audience;
    anydata...;
|};

// SCIM2 Group types
public type GroupCreateRequest record {|
    string displayName;
    anydata[] members?;
    string[] schemas;
|};

public type Group record {|
    string displayName;
    string id;
    anydata...;
|};

public type GroupGetResponse record {|
    int totalResults;
    Group[] Resources;
    anydata...;
|};

public type PatchResponse record {|
    string displayName;
    string id;
    anydata...;
|};

// Application types
public type Application record {|
    string id;
    string name;
    anydata...;
|};

public type ApplicationsResponse record {|
    int totalResults;
    int count;
    Application[] applications;
    anydata...;
|};

// Console app role types
public type ConsoleAppRole record {|
    RoleAudience audience;
    string displayName;
    string id;
    anydata...;
|};

public type ConsoleAppRolesResponse record {|
    int totalResults;
    ConsoleAppRole[] Resources;
    anydata...;
|};

// Userstore types
public type Userstore record {|
    string id;
    string name;
    boolean enabled;
    string description;
    boolean isLocal;
    string self;
    string typeName;
|};

// Salesforce Account record type
public type SalesforceAccount record {|
    string AccountNumber;
    anydata...;
|};

// Salesforce query response structure
public type SalesforceQueryResponse record {|
    int totalSize;
    boolean done;
    SalesforceAccount[] records;
|};
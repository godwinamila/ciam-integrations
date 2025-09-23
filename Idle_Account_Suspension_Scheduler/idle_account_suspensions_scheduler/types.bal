// Record type for inactive user data
public type InactiveUser record {|
    string userId;
    string username;
    string userStoreDomain;
|};

// Array type for inactive users response
public type InactiveUsersResponse InactiveUser[];

// Token API Response
public type TokenResponse record {|
    string access_token;
    string scope;
    string token_type;
    int expires_in;
|};

// SCIM User patch operation for disabling
public type ScimPatchOperation record {|
    string op;
    string path;
    boolean value;
|};

// SCIM Patch request
public type ScimPatchRequest record {|
    string[] schemas;
    ScimPatchOperation[] Operations;
|};

// Individual operation result with skipped users tracking
public type OperationResult record {|
    int totalUsers;
    int successCount;
    int failureCount;
    int skippedCount;
    string[] failedUsers;
    string[] skippedUsers;
|};

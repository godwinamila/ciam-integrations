// Record types for the token request payload

public type TokenRequest record {
    string actionType;
    Event event;
    AllowedOperation[] allowedOperations;
};

public type Event record {
    Request request;
    Tenant tenant;
    Organization organization;
    User user;
    UserStore userStore;
    AccessToken accessToken;
    RefreshToken refreshToken;
};

public type Request record {
    map<string[]> additionalHeaders;
    string clientId;
    string grantType;
};

public type Tenant record {
    string id;
    string name;
};

public type Organization record {
    string id;
    string name;
};

public type User record {
    string id;
    Organization organization;
};

public type UserStore record {
    string id;
    string name;
};

public type AccessToken record {
    string tokenType;
    string[] scopes;
    Claim[] claims;
};

public type RefreshToken record {
    map<Claim[]> claims;
};

public type Claim record {
    string name;
    anydata value;
};

public type AllowedOperation record {
    string op;
    string[] paths;
};

public type TokenResponse record {
    string status;
    string message;
    string? actionType?;
};

public type ScopeAddResponse record {
    string actionStatus;
    Operation[]? operations?;
};

public type Operation record {
    string op;
    string path;
    string value;
};
import ballerina/http;

type TokenResponse record {|
    *http:Ok;
    ScopeAddResponse body;
|};

type ErrorResponse record {|
    *http:BadRequest;
    record {
        string actionStatus;
        string errorMessage;
        string errorDescription;
    } body;
|};

public type ScopeAddResponse record {
    string actionStatus;
    Operation[]? operations?;
};

public type Operation record {
    string op;
    string path;
    string value;
};

public type Organization record {|
    string id;
    string name;
    anydata...;
|};

public type User record {|
    string id;
    Organization organization;
    anydata...;
|};

public type TokenRequest record {|
    string actionType;
    Event event;
    AllowedOperation[] allowedOperations;
    anydata...;
|};

public type Event record {|
    Request request;
    Tenant tenant?;
    Organization organization;
    User user?;
    AccessToken accessToken;
    anydata...;
|};

public type Request record {|
    string clientId;
    string grantType;
    anydata...;
|};

public type Tenant record {
    string id;
    string name;
};

public type AccessToken record {|
    string tokenType;
    string[] scopes;
    Claim[] claims?;
    anydata...;
|};

public type Claim record {
    string name;
    anydata value;
};

public type AllowedOperation record {
    string op;
    string[] paths;
};

public type OrganizationEntitlement record {
    string orgId;
    string plan;
    string[] features;
    string validUntil;
};
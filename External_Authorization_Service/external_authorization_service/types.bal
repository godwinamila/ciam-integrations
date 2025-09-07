// Response types for the token service

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
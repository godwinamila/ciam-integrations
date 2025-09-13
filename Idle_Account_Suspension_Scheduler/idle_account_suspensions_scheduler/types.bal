// Record type for inactive user data
public type InactiveUser record {|
    string userId;
    string username;
    string userStoreDomain;
|};

// Array type for inactive users response
public type InactiveUsersResponse InactiveUser[];

// Configuration for operation type
public enum OperationType {
    B2B_DELETE = "b2b_delete",
    B2B_DISABLE = "b2b_disable",
    B2B_LIST = "b2b_list",
    B2C_DELETE = "b2c_delete",
    B2C_DISABLE = "b2c_disable",
    B2C_LIST = "b2c_list"
}

// Token API Response
public type TokenResponse record {|
    string access_token;
    string scope;
    string token_type;
    int expires_in;
|};
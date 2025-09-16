public type SecurityEventToken record {|
    string iss; // Issuer
    int iat; // Issued At timestamp
    string jti; // JWT ID
    map<json> events; // Events object with dynamic keys
    anydata...;
|};

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

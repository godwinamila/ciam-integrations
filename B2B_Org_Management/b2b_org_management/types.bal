// Token switching types (already exists)
public type TokenResponse record {|
    string access_token;
    string scope;
    string token_type;
    int expires_in;
|};

// Organization attribute type
public type Attribute record {|
    string key;
    string value;
|};

// Base organization request/response types
public type OrganizationCreateRequest record {|
    string name;
    string? description = ();
    Attribute[] attributes = [];
|};

public type OrganizationPatchOperation record {|
    string operation; // ADD, REMOVE, REPLACE
    string path;
    string? value = ();
|};

public type OrganizationResponse record {|
    string id;
    string name;
    string? description = ();
    string status;
    boolean hasChildren;
    Attribute[] attributes;
    anydata...;
|};

// Pagination link type
public type PaginationLink record {|
    string href;
    string rel;
|};

// Organization list response type with pagination links - handles empty responses
public type OrganizationListResponse record {|
    OrganizationResponse[]? organizations = ();
    PaginationLink[]? links = ();
    anydata...;
|};

// Custom list response with pagination
public type CustomOrganizationListResponse record {|
    CustomOrganizationResponse[] organizations;
    PaginationLink[]? links = ();
|};

// Custom organization types for the facade
public type ManagedOrgCreateRequest record {|
    string businessName;
    string gisGuid;
    string businessRegistrationNo;
    string country;
|};

public type SelfOrgCreateRequest record {|
    string businessName;
    string businessRegistrationNo;
    string country;
|};

public type SubOrgCreateRequest record {|
    string businessEntityName;
    string country;
|};

public type SiteOrgCreateRequest record {|
    string siteId;
    string location;
|};

// Patch request types
public type ManagedOrgPatchRequest record {|
    string? businessName = ();
    string? gisGuid = ();
    string? businessRegistrationNo = ();
    string? country = ();
|};

public type SelfOrgPatchRequest record {|
    string? businessName = ();
    string? businessRegistrationNo = ();
    string? country = ();
|};

public type SubOrgPatchRequest record {|
    string? businessEntityName = ();
    string? country = ();
|};

public type SiteOrgPatchRequest record {|
    string? siteId = ();
    string? location = ();
|};

// Response types for custom organizations
public type CustomOrganizationResponse record {|
    string id;
    string name;
    string orgType;
    string status;
    boolean hasChildren;
    record {} attributes;
|};

// Upgrade request for self-org to managed-org
public type SelfOrgUpgradeRequest record {|
    string gisGuid;
|};

// Error response type
public type ErrorResponse record {|
    string code;
    string message;
    string? description = ();
|};

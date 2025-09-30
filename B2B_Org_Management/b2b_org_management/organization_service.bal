import ballerina/http;
import ballerina/log;

// Service for custom organization management
service /organizations on new http:Listener(8081) {

    // ABB Managed Orgs

    // Create ABB-managed org
    resource function post managedOrgs(ManagedOrgCreateRequest request) returns CustomOrganizationResponse|http:Response|error {
        return createManagedOrg(request);
    }

    // Create sub-org in ABB-managed org
    resource function post managedOrgs/[string parentOrgId]/subOrgs(SubOrgCreateRequest request) returns CustomOrganizationResponse|http:Response|error {
        return createSubOrg(parentOrgId, request);
    }

    // Create site in ABB-managed org
    resource function post managedOrgs/[string parentOrgId]/sites(SiteOrgCreateRequest request) returns CustomOrganizationResponse|http:Response|error {
        return createSiteInManagedOrg(parentOrgId, request);
    }
    
    // List ABB-managed orgs
    resource function get managedOrgs(int? 'limit = 10, string? after = (), string? before = ()) returns CustomOrganizationListResponse|http:Response|error {
        return listManagedOrgs('limit, after, before);
    }

    // List sub-orgs of ABB-managed orgs
    resource function get managedOrgs/[string parentOrgId]/subOrgs(int? 'limit = 10, string? after = (), string? before = (), boolean? recursive = false) returns CustomOrganizationListResponse|http:Response|error {
        return listSubOrgs(parentOrgId, 'limit, after, before, recursive);
    }

    // List sites of ABB-managed orgs
    resource function get managedOrgs/[string parentOrgId]/sites(int? 'limit = 10, string? after = (), string? before = ()) returns CustomOrganizationListResponse|http:Response|error {
        return listSitesInManagedOrg(parentOrgId, 'limit, after, before, true);
    }

    // Get ABB-managed org by ID
    resource function get managedOrgs/[string orgId]() returns CustomOrganizationResponse|http:Response|error {
        return getManagedOrg(orgId);
    }

    // Get sub-org in ABB-managed org by ID
    resource function get managedOrgs/[string parentOrgId]/subOrgs/[string orgId]() returns CustomOrganizationResponse|http:Response|error {
        return getSubOrg(parentOrgId, orgId);
    }

    // Get site in ABB-managed org by ID
    resource function get managedOrgs/[string parentOrgId]/sites/[string orgId]() returns CustomOrganizationResponse|http:Response|error {
        return getSiteFromManagedOrg(parentOrgId, orgId);
    }

    // Update ABB-managed org by ID
    resource function patch managedOrgs/[string orgId](ManagedOrgPatchRequest request) returns CustomOrganizationResponse|http:Response|error {
        return patchManagedOrg(orgId, request);
    }

    // Update sub-org in ABB-managed org by ID
    resource function patch managedOrgs/[string parentOrgId]/subOrgs/[string orgId](SubOrgPatchRequest request) returns CustomOrganizationResponse|http:Response|error {
        return patchSubOrg(parentOrgId, orgId, request);
    }

    // Update site in ABB-managed org by ID
    resource function patch managedOrgs/[string parentOrgId]/sites/[string orgId](SiteOrgPatchRequest request) returns CustomOrganizationResponse|http:Response|error {
        return patchSiteInManagedOrg(parentOrgId, orgId, request);
    }

    // Delete ABB-managed org by ID
    resource function delete managedOrgs/[string orgId]() returns http:Response|error {
        return deleteManagedOrg(orgId);
    }

    // Delete sub-org in ABB-managed org by ID
    resource function delete managedOrgs/[string parentOrgId]/subOrgs/[string orgId]() returns http:Response|error {
        return deleteSubOrg(parentOrgId, orgId);
    }

    // Delete site in ABB-managed org by ID
    resource function delete managedOrgs/[string parentOrgId]/sites/[string orgId]() returns http:Response|error {
        return deleteSiteFromManagedOrg(parentOrgId, orgId);
    }
    
    // Self-Managed Orgs
    
    // Create self-managed org
    resource function post selfOrgs(SelfOrgCreateRequest request) returns CustomOrganizationResponse|http:Response|error {
        return createSelfOrg(request);
    }

    // Create site in self-managed org
    resource function post selfOrgs/[string parentOrgId]/sites(SiteOrgCreateRequest request) returns CustomOrganizationResponse|http:Response|error {
        return createSiteInSelfOrg(parentOrgId, request);
    }

    // List self-managed orgs
    resource function get selfOrgs(int? 'limit = 10, string? after = (), string? before = ()) returns CustomOrganizationListResponse|http:Response|error {
        return listSelfOrgs('limit, after, before);
    }

    // List sites in self-managed orgs
    resource function get selfOrgs/[string parentOrgId]/sites(int? 'limit = 10, string? after = (), string? before = ()) returns CustomOrganizationListResponse|http:Response|error {
        return listSitesInSelfOrg(parentOrgId, 'limit, after, before, true);
    }
    
    // Get self-managed org by ID
    resource function get selfOrgs/[string orgId]() returns CustomOrganizationResponse|http:Response|error {
        return getSelfOrg(orgId);
    }

    // Get site in self-managed org by ID
    resource function get selfOrgs/[string parentOrgId]/sites/[string orgId]() returns CustomOrganizationResponse|http:Response|error {
        return getSiteFromSelfOrg(parentOrgId, orgId);
    }

    // Update self-managed org by ID
    resource function patch selfOrgs/[string orgId](SelfOrgPatchRequest request) returns CustomOrganizationResponse|http:Response|error {
        return patchSelfOrg(orgId, request);
    }

    // Update site in self-managed org by ID
    resource function patch selfOrgs/[string parentOrgId]/sites/[string orgId](SiteOrgPatchRequest request) returns CustomOrganizationResponse|http:Response|error {
        return patchSiteInSelfOrg(parentOrgId, orgId, request);
    }

    // Delete self-managed org by ID
    resource function delete selfOrgs/[string orgId]() returns http:Response|error {
        return deleteSelfOrg(orgId);
    }

    // Delete site in self-managed org by ID
    resource function delete selfOrgs/[string parentOrgId]/sites/[string orgId]() returns http:Response|error {
        return deleteSiteFromSelfOrg(parentOrgId, orgId);
    }

    // Upgrade API
    resource function post selfOrgs/[string orgId]/upgrade(SelfOrgUpgradeRequest request) returns CustomOrganizationResponse|http:Response|error {
        return upgradeSelfOrgToManaged(orgId, request);
    }
}

// VALIDATION FUNCTIONS to validate org type
function validateParentOrg(string parentOrgId, string expectedType, string rootToken) returns http:Response|error? {
    map<string|string[]> headers = {
        "Authorization": string `Bearer ${rootToken}`
    };

    OrganizationResponse|error parentOrg = asgardeoClient->get(string `/api/server/v1/organizations/${parentOrgId}`, headers = headers);
    
    if parentOrg is error {
        log:printError("Error validating parent org type", parentOrg);
        return createErrorResponse(404, "Parent organization not found");
    }

    string? parentType = getAttributeValue(parentOrg.attributes, "type");
    if parentType != expectedType {
        string message = string `Invalid parent organization type. Expected '${expectedType}' but found '${parentType ?: "unknown"}'`;
        return createErrorResponse(400, message);
    }

    return ();
}

function validateRootOrgType(string orgId, string expectedType, string rootToken) returns http:Response|error? {
    map<string|string[]> headers = {
        "Authorization": string `Bearer ${rootToken}`
    };

    OrganizationResponse|error org = asgardeoClient->get(string `/api/server/v1/organizations/${orgId}`, headers = headers);
    
    if org is error {
        log:printError("Error validating root org type", org);
        return createErrorResponse(404, "Organization not found");
    }

    string? orgType = getAttributeValue(org.attributes, "type");
    if orgType != expectedType {
        log:printInfo(string `Organization ${orgId} found but has type '${orgType ?: "unknown"}', expected '${expectedType}'`);
        return createErrorResponse(404, "Organization not found");
    }

    return ();
}

function validateSubOrgType(string orgId, string expectedType, string orgToken) returns http:Response|error? {
    map<string|string[]> headers = {
        "Authorization": string `Bearer ${orgToken}`
    };

    OrganizationResponse|error org = asgardeoClient->get(string `/o/api/server/v1/organizations/${orgId}`, headers = headers);
    
    if org is error {
        log:printError("Error validating sub org type", org);
        return createErrorResponse(404, "Organization not found");
    }

    string? orgType = getAttributeValue(org.attributes, "type");
    if orgType != expectedType {
        log:printInfo(string `Organization ${orgId} found but has type '${orgType ?: "unknown"}', expected '${expectedType}'`);
        return createErrorResponse(404, "Organization not found");
    }

    return ();
}

function validateNoSubOrgsExist(string orgToken) returns http:Response|error? {
    map<string|string[]> headers = {
        "Authorization": string `Bearer ${orgToken}`
    };

    string queryParams = buildFilteredQueryParams(1, (), (), false, "attributes.type+eq+sub-org");
    string endpoint = string `/o/api/server/v1/organizations${queryParams}`;

    OrganizationListResponse|error response = asgardeoClient->get(endpoint, headers = headers);
    if response is error {
        log:printError("Error checking for existing sub-orgs", response);
        return createErrorResponse(500, "Failed to validate organization hierarchy");
    }

    OrganizationResponse[] organizations = response.organizations ?: [];
    if organizations.length() > 0 {
        return createErrorResponse(400, "Cannot create sites in an organization that contains sub-organizations. Sites must be leaf nodes.");
    }

    return ();
}

function validateNoSitesExist(string orgToken) returns http:Response|error? {
    map<string|string[]> headers = {
        "Authorization": string `Bearer ${orgToken}`
    };

    string queryParams = buildFilteredQueryParams(1, (), (), false, "attributes.type+eq+site");
    string endpoint = string `/o/api/server/v1/organizations${queryParams}`;

    OrganizationListResponse|error response = asgardeoClient->get(endpoint, headers = headers);
    if response is error {
        log:printError("Error checking for existing sites", response);
        return createErrorResponse(500, "Failed to validate organization hierarchy");
    }

    OrganizationResponse[] organizations = response.organizations ?: [];
    if organizations.length() > 0 {
        return createErrorResponse(400, "Cannot create sub-organizations in an organization that contains sites. Sites and sub-organizations cannot coexist.");
    }

    return ();
}

// LIST functions
function listManagedOrgs(int? 'limit, string? after, string? before) returns CustomOrganizationListResponse|http:Response|error {
    if after is string && before is string {
        return createErrorResponse(400, "Cannot specify both 'after' and 'before' parameters simultaneously");
    }

    string|error rootToken = getRootAccessToken();
    if rootToken is error {
        return createErrorResponse(500, "Failed to get root access token");
    }

    map<string|string[]> headers = {
        "Authorization": string `Bearer ${rootToken}`
    };

    string queryParams = buildFilteredQueryParams('limit, after, before, false, "attributes.type+eq+abb-managed");
    string endpoint = string `/api/server/v1/organizations${queryParams}`;

    OrganizationListResponse|error response = asgardeoClient->get(endpoint, headers = headers);
    if response is error {
        log:printError("Error listing managed orgs", response);
        return createErrorResponse(500, "Failed to list managed organizations");
    }

    OrganizationResponse[] organizations = response.organizations ?: [];
    
    CustomOrganizationResponse[] customOrgs = [];
    foreach OrganizationResponse org in organizations {
        customOrgs.push(mapToCustomResponse(org, "abb-managed"));
    }

    return {
        organizations: customOrgs,
        links: response.links
    };
}

function listSelfOrgs(int? 'limit, string? after, string? before) returns CustomOrganizationListResponse|http:Response|error {
    if after is string && before is string {
        return createErrorResponse(400, "Cannot specify both 'after' and 'before' parameters simultaneously");
    }

    string|error rootToken = getRootAccessToken();
    if rootToken is error {
        return createErrorResponse(500, "Failed to get root access token");
    }

    map<string|string[]> headers = {
        "Authorization": string `Bearer ${rootToken}`
    };

    string queryParams = buildFilteredQueryParams('limit, after, before, false, "attributes.type+eq+self-managed");
    string endpoint = string `/api/server/v1/organizations${queryParams}`;

    OrganizationListResponse|error response = asgardeoClient->get(endpoint, headers = headers);
    if response is error {
        log:printError("Error listing self orgs", response);
        return createErrorResponse(500, "Failed to list self-managed organizations");
    }

    OrganizationResponse[] organizations = response.organizations ?: [];
    
    CustomOrganizationResponse[] customOrgs = [];
    foreach OrganizationResponse org in organizations {
        customOrgs.push(mapToCustomResponse(org, "self-managed"));
    }

    return {
        organizations: customOrgs,
        links: response.links
    };
}

function listSubOrgs(string parentOrgId, int? 'limit, string? after, string? before, boolean? recursive) returns CustomOrganizationListResponse|http:Response|error {
    if after is string && before is string {
        return createErrorResponse(400, "Cannot specify both 'after' and 'before' parameters simultaneously");
    }

    string|error orgToken = switchToOrganizationToken(parentOrgId);
    if orgToken is error {
        return createErrorResponse(500, "Failed to switch to organization token");
    }

    map<string|string[]> headers = {
        "Authorization": string `Bearer ${orgToken}`
    };

    string queryParams = buildFilteredQueryParams('limit, after, before, recursive, "attributes.type+eq+sub-org");
    string endpoint = string `/o/api/server/v1/organizations${queryParams}`;

    OrganizationListResponse|error response = asgardeoClient->get(endpoint, headers = headers);
    if response is error {
        log:printError("Error listing sub orgs", response);
        return createErrorResponse(500, "Failed to list sub organizations");
    }

    OrganizationResponse[] organizations = response.organizations ?: [];
    
    CustomOrganizationResponse[] customOrgs = [];
    foreach OrganizationResponse org in organizations {
        customOrgs.push(mapToCustomResponse(org, "sub-org"));
    }

    return {
        organizations: customOrgs,
        links: response.links
    };
}

// List Sites
function listSitesInManagedOrg(string parentOrgId, int? 'limit, string? after, string? before, boolean? recursive) returns CustomOrganizationListResponse|http:Response|error {
    if after is string && before is string {
        return createErrorResponse(400, "Cannot specify both 'after' and 'before' parameters simultaneously");
    }

    // Get root token once for validation
    string|error rootToken = getRootAccessToken();
    if rootToken is error {
        return createErrorResponse(500, "Failed to get root access token");
    }

    // Validate parent type using the same root token
    http:Response|error? parentValidation = validateParentOrg(parentOrgId, "abb-managed", rootToken);
    if parentValidation is http:Response {
        http:Response|error? subOrgValidation = validateParentOrg(parentOrgId, "sub-org", rootToken);
        if subOrgValidation is http:Response {
            return createErrorResponse(400, "Parent organization must be of type 'abb-managed' or 'sub-org' to list sites");
        } else if subOrgValidation is error {
            return subOrgValidation;
        }
    } else if parentValidation is error {
        return parentValidation;
    }

    string|error orgToken = switchToOrganizationToken(parentOrgId);
    if orgToken is error {
        return createErrorResponse(500, "Failed to switch to organization token");
    }

    map<string|string[]> headers = {
        "Authorization": string `Bearer ${orgToken}`
    };

    string queryParams = buildFilteredQueryParams('limit, after, before, recursive, "attributes.type+eq+site");
    string endpoint = string `/o/api/server/v1/organizations${queryParams}`;

    OrganizationListResponse|error response = asgardeoClient->get(endpoint, headers = headers);
    if response is error {
        log:printError("Error listing sites in managed org", response);
        return createErrorResponse(500, "Failed to list site organizations");
    }

    OrganizationResponse[] organizations = response.organizations ?: [];
    
    CustomOrganizationResponse[] customOrgs = [];
    foreach OrganizationResponse org in organizations {
        customOrgs.push(mapToCustomResponse(org, "site"));
    }

    return {
        organizations: customOrgs,
        links: response.links
    };
}

function listSitesInSelfOrg(string parentOrgId, int? 'limit, string? after, string? before, boolean? recursive) returns CustomOrganizationListResponse|http:Response|error {
    if after is string && before is string {
        return createErrorResponse(400, "Cannot specify both 'after' and 'before' parameters simultaneously");
    }

    // Get root token once for validation
    string|error rootToken = getRootAccessToken();
    if rootToken is error {
        return createErrorResponse(500, "Failed to get root access token");
    }

    // Validate parent type using the same root token
    http:Response|error? parentValidation = validateParentOrg(parentOrgId, "self-managed", rootToken);
    if parentValidation is http:Response {
        return parentValidation;
    } else if parentValidation is error {
        return parentValidation;
    }

    string|error orgToken = switchToOrganizationToken(parentOrgId);
    if orgToken is error {
        return createErrorResponse(500, "Failed to switch to organization token");
    }

    map<string|string[]> headers = {
        "Authorization": string `Bearer ${orgToken}`
    };

    string queryParams = buildFilteredQueryParams('limit, after, before, recursive, "attributes.type+eq+site");
    string endpoint = string `/o/api/server/v1/organizations${queryParams}`;

    OrganizationListResponse|error response = asgardeoClient->get(endpoint, headers = headers);
    if response is error {
        log:printError("Error listing sites in self org", response);
        return createErrorResponse(500, "Failed to list site organizations");
    }

    OrganizationResponse[] organizations = response.organizations ?: [];
    
    CustomOrganizationResponse[] customOrgs = [];
    foreach OrganizationResponse org in organizations {
        customOrgs.push(mapToCustomResponse(org, "site"));
    }

    return {
        organizations: customOrgs,
        links: response.links
    };
}

// CREATE functions
function createManagedOrg(ManagedOrgCreateRequest request) returns CustomOrganizationResponse|http:Response|error {
    string|error rootToken = getRootAccessToken();
    if rootToken is error {
        return createErrorResponse(500, "Failed to get root access token");
    }

    Attribute[] attributes = [
        {key: "type", value: "abb-managed"},
        {key: "GISGUID", value: request.gisGuid},
        {key: "BusinessName", value: request.businessName},
        {key: "BusinessRegistrationNo", value: request.businessRegistrationNo},
        {key: "Country", value: request.country}
    ];

    OrganizationCreateRequest orgRequest = {
        name: request.businessName,
        attributes: attributes
    };

    map<string|string[]> headers = {
        "Authorization": string `Bearer ${rootToken}`,
        "Content-Type": "application/json"
    };

    OrganizationResponse|error response = asgardeoClient->post("/api/server/v1/organizations", orgRequest, headers = headers);
    if response is error {
        log:printError("Error creating managed org", response);
        return createErrorResponse(500, "Failed to create managed organization");
    }

    return mapToCustomResponse(response, "abb-managed");
}

function createSelfOrg(SelfOrgCreateRequest request) returns CustomOrganizationResponse|http:Response|error {
    string|error rootToken = getRootAccessToken();
    if rootToken is error {
        return createErrorResponse(500, "Failed to get root access token");
    }

    Attribute[] attributes = [
        {key: "type", value: "self-managed"},
        {key: "BusinessName", value: request.businessName},
        {key: "BusinessRegistrationNo", value: request.businessRegistrationNo},
        {key: "Country", value: request.country}
    ];

    OrganizationCreateRequest orgRequest = {
        name: request.businessName,
        attributes: attributes
    };

    map<string|string[]> headers = {
        "Authorization": string `Bearer ${rootToken}`,
        "Content-Type": "application/json"
    };

    OrganizationResponse|error response = asgardeoClient->post("/api/server/v1/organizations", orgRequest, headers = headers);
    if response is error {
        log:printError("Error creating self org", response);
        return createErrorResponse(500, "Failed to create self-managed organization");
    }

    return mapToCustomResponse(response, "self-managed");
}

function createSubOrg(string parentOrgId, SubOrgCreateRequest request) returns CustomOrganizationResponse|http:Response|error {
    // Get root token once for validation
    string|error rootToken = getRootAccessToken();
    if rootToken is error {
        return createErrorResponse(500, "Failed to get root access token");
    }

    // Validate parent type using the same root token
    http:Response|error? parentValidation = validateParentOrg(parentOrgId, "abb-managed", rootToken);
    if parentValidation is http:Response {
        http:Response|error? subOrgValidation = validateParentOrg(parentOrgId, "sub-org", rootToken);
        if subOrgValidation is http:Response {
            return createErrorResponse(400, "Parent organization must be of type 'abb-managed' or 'sub-org' to create sub-orgs");
        } else if subOrgValidation is error {
            return subOrgValidation;
        }
    } else if parentValidation is error {
        return parentValidation;
    }

    // Get org token once for both validation and creation
    string|error orgToken = switchToOrganizationToken(parentOrgId);
    if orgToken is error {
        return createErrorResponse(500, "Failed to switch to organization token");
    }

    http:Response|error? siteValidation = validateNoSitesExist(orgToken);
    if siteValidation is http:Response {
        return siteValidation;
    } else if siteValidation is error {
        return siteValidation;
    }

    Attribute[] attributes = [
        {key: "type", value: "sub-org"},
        {key: "Country", value: request.country},
        {key: "BusinessEntityName", value: request.businessEntityName}
    ];

    OrganizationCreateRequest orgRequest = {
        name: request.businessEntityName,
        attributes: attributes
    };

    map<string|string[]> headers = {
        "Authorization": string `Bearer ${orgToken}`,
        "Content-Type": "application/json"
    };

    OrganizationResponse|error response = asgardeoClient->post("/o/api/server/v1/organizations", orgRequest, headers = headers);
    if response is error {
        log:printError("Error creating sub org", response);
        return createErrorResponse(500, "Failed to create sub organization");
    }

    return mapToCustomResponse(response, "sub-org");
}

function createSiteInManagedOrg(string parentOrgId, SiteOrgCreateRequest request) returns CustomOrganizationResponse|http:Response|error {
    // Get root token once for validation
    string|error rootToken = getRootAccessToken();
    if rootToken is error {
        return createErrorResponse(500, "Failed to get root access token");
    }

    // Validate parent type using the same root token
    http:Response|error? parentValidation = validateParentOrg(parentOrgId, "abb-managed", rootToken);
    if parentValidation is http:Response {
        http:Response|error? subOrgValidation = validateParentOrg(parentOrgId, "sub-org", rootToken);
        if subOrgValidation is http:Response {
            return createErrorResponse(400, "Parent organization must be of type 'abb-managed' or 'sub-org' to create sites");
        } else if subOrgValidation is error {
            return subOrgValidation;
        }
    } else if parentValidation is error {
        return parentValidation;
    }

    // Get org token once for both validation and creation
    string|error orgToken = switchToOrganizationToken(parentOrgId);
    if orgToken is error {
        return createErrorResponse(500, "Failed to switch to organization token");
    }

    http:Response|error? subOrgValidation = validateNoSubOrgsExist(orgToken);
    if subOrgValidation is http:Response {
        return subOrgValidation;
    } else if subOrgValidation is error {
        return subOrgValidation;
    }

    Attribute[] attributes = [
        {key: "type", value: "site"},
        {key: "SiteId", value: request.siteId},
        {key: "Location", value: request.location}
    ];

    OrganizationCreateRequest orgRequest = {
        name: request.siteId,
        attributes: attributes
    };

    map<string|string[]> headers = {
        "Authorization": string `Bearer ${orgToken}`,
        "Content-Type": "application/json"
    };

    OrganizationResponse|error response = asgardeoClient->post("/o/api/server/v1/organizations", orgRequest, headers = headers);
    if response is error {
        log:printError("Error creating site in managed org", response);
        return createErrorResponse(500, "Failed to create site organization");
    }

    return mapToCustomResponse(response, "site");
}

function createSiteInSelfOrg(string parentOrgId, SiteOrgCreateRequest request) returns CustomOrganizationResponse|http:Response|error {
    // Get root token once for validation
    string|error rootToken = getRootAccessToken();
    if rootToken is error {
        return createErrorResponse(500, "Failed to get root access token");
    }

    // Validate parent type using the same root token
    http:Response|error? parentValidation = validateParentOrg(parentOrgId, "self-managed", rootToken);
    if parentValidation is http:Response {
        return parentValidation;
    } else if parentValidation is error {
        return parentValidation;
    }

    // Reuse the managed org creation logic but skip sub-org validation
    string|error orgToken = switchToOrganizationToken(parentOrgId);
    if orgToken is error {
        return createErrorResponse(500, "Failed to switch to organization token");
    }

    Attribute[] attributes = [
        {key: "type", value: "site"},
        {key: "SiteId", value: request.siteId},
        {key: "Location", value: request.location}
    ];

    OrganizationCreateRequest orgRequest = {
        name: request.siteId,
        attributes: attributes
    };

    map<string|string[]> headers = {
        "Authorization": string `Bearer ${orgToken}`,
        "Content-Type": "application/json"
    };

    OrganizationResponse|error response = asgardeoClient->post("/o/api/server/v1/organizations", orgRequest, headers = headers);
    if response is error {
        log:printError("Error creating site in self org", response);
        return createErrorResponse(500, "Failed to create site organization");
    }

    return mapToCustomResponse(response, "site");
}

// GET functions
function getManagedOrg(string orgId) returns CustomOrganizationResponse|http:Response|error {
    string|error rootToken = getRootAccessToken();
    if rootToken is error {
        return createErrorResponse(500, "Failed to get root access token");
    }

    map<string|string[]> headers = {
        "Authorization": string `Bearer ${rootToken}`
    };

    OrganizationResponse|error response = asgardeoClient->get(string `/api/server/v1/organizations/${orgId}`, headers = headers);
    if response is error {
        log:printError("Error getting managed org", response);
        return createErrorResponse(404, "Managed organization not found");
    }

    string? orgType = getAttributeValue(response.attributes, "type");
    if orgType != "abb-managed" {
        log:printInfo(string `Organization ${orgId} found but has type '${orgType ?: "unknown"}', expected 'abb-managed'`);
        return createErrorResponse(404, "Managed organization not found");
    }

    return mapToCustomResponse(response, "abb-managed");
}

function getSelfOrg(string orgId) returns CustomOrganizationResponse|http:Response|error {
    string|error rootToken = getRootAccessToken();
    if rootToken is error {
        return createErrorResponse(500, "Failed to get root access token");
    }

    map<string|string[]> headers = {
        "Authorization": string `Bearer ${rootToken}`
    };

    OrganizationResponse|error response = asgardeoClient->get(string `/api/server/v1/organizations/${orgId}`, headers = headers);
    if response is error {
        log:printError("Error getting self org", response);
        return createErrorResponse(404, "Self-managed organization not found");
    }

    string? orgType = getAttributeValue(response.attributes, "type");
    if orgType != "self-managed" {
        log:printInfo(string `Organization ${orgId} found but has type '${orgType ?: "unknown"}', expected 'self-managed'`);
        return createErrorResponse(404, "Self-managed organization not found");
    }

    return mapToCustomResponse(response, "self-managed");
}

function getSubOrg(string parentOrgId, string orgId) returns CustomOrganizationResponse|http:Response|error {
    // Get root token once for validation
    string|error rootToken = getRootAccessToken();
    if rootToken is error {
        return createErrorResponse(500, "Failed to get root access token");
    }

    // Validate parent type using the same root token
    http:Response|error? parentValidation = validateParentOrg(parentOrgId, "abb-managed", rootToken);
    if parentValidation is http:Response {
        http:Response|error? subOrgValidation = validateParentOrg(parentOrgId, "sub-org", rootToken);
        if subOrgValidation is http:Response {
            return createErrorResponse(400, "Parent organization must be of type 'abb-managed' or 'sub-org'");
        } else if subOrgValidation is error {
            return subOrgValidation;
        }
    } else if parentValidation is error {
        return parentValidation;
    }

    string|error orgToken = switchToOrganizationToken(parentOrgId);
    if orgToken is error {
        return createErrorResponse(500, "Failed to switch to organization token");
    }

    map<string|string[]> headers = {
        "Authorization": string `Bearer ${orgToken}`
    };

    OrganizationResponse|error response = asgardeoClient->get(string `/o/api/server/v1/organizations/${orgId}`, headers = headers);
    if response is error {
        log:printError("Error getting sub org", response);
        return createErrorResponse(404, "Sub organization not found");
    }

    string? orgType = getAttributeValue(response.attributes, "type");
    if orgType != "sub-org" {
        log:printInfo(string `Organization ${orgId} found but has type '${orgType ?: "unknown"}', expected 'sub-org'`);
        return createErrorResponse(404, "Sub organization not found");
    }

    return mapToCustomResponse(response, "sub-org");
}

function getSiteFromManagedOrg(string parentOrgId, string orgId) returns CustomOrganizationResponse|http:Response|error {
    // Get root token once for validation
    string|error rootToken = getRootAccessToken();
    if rootToken is error {
        return createErrorResponse(500, "Failed to get root access token");
    }

    // Validate parent type using the same root token
    http:Response|error? parentValidation = validateParentOrg(parentOrgId, "abb-managed", rootToken);
    if parentValidation is http:Response {
        http:Response|error? subOrgValidation = validateParentOrg(parentOrgId, "sub-org", rootToken);
        if subOrgValidation is http:Response {
            return createErrorResponse(400, "Parent organization must be of type 'abb-managed' or 'sub-org'");
        } else if subOrgValidation is error {
            return subOrgValidation;
        }
    } else if parentValidation is error {
        return parentValidation;
    }

    string|error orgToken = switchToOrganizationToken(parentOrgId);
    if orgToken is error {
        return createErrorResponse(500, "Failed to switch to organization token");
    }

    map<string|string[]> headers = {
        "Authorization": string `Bearer ${orgToken}`
    };

    OrganizationResponse|error response = asgardeoClient->get(string `/o/api/server/v1/organizations/${orgId}`, headers = headers);
    if response is error {
        log:printError("Error getting site from managed org", response);
        return createErrorResponse(404, "Site organization not found");
    }

    string? orgType = getAttributeValue(response.attributes, "type");
    if orgType != "site" {
        log:printInfo(string `Organization ${orgId} found but has type '${orgType ?: "unknown"}', expected 'site'`);
        return createErrorResponse(404, "Site not found");
    }

    return mapToCustomResponse(response, "site");
}

function getSiteFromSelfOrg(string parentOrgId, string orgId) returns CustomOrganizationResponse|http:Response|error {
    // Get root token once for validation
    string|error rootToken = getRootAccessToken();
    if rootToken is error {
        return createErrorResponse(500, "Failed to get root access token");
    }

    // Validate parent type using the same root token
    http:Response|error? parentValidation = validateParentOrg(parentOrgId, "self-managed", rootToken);
    if parentValidation is http:Response {
        return parentValidation;
    } else if parentValidation is error {
        return parentValidation;
    }

    string|error orgToken = switchToOrganizationToken(parentOrgId);
    if orgToken is error {
        return createErrorResponse(500, "Failed to switch to organization token");
    }

    map<string|string[]> headers = {
        "Authorization": string `Bearer ${orgToken}`
    };

    OrganizationResponse|error response = asgardeoClient->get(string `/o/api/server/v1/organizations/${orgId}`, headers = headers);
    if response is error {
        log:printError("Error getting site from self org", response);
        return createErrorResponse(404, "Site organization not found");
    }

    string? orgType = getAttributeValue(response.attributes, "type");
    if orgType != "site" {
        log:printInfo(string `Organization ${orgId} found but has type '${orgType ?: "unknown"}', expected 'site'`);
        return createErrorResponse(404, "Site not found");
    }

    return mapToCustomResponse(response, "site");
}

// PATCH functions
function patchManagedOrg(string orgId, ManagedOrgPatchRequest request) returns CustomOrganizationResponse|http:Response|error {
    // Get root token once for both validation and patching
    string|error rootToken = getRootAccessToken();
    if rootToken is error {
        return createErrorResponse(500, "Failed to get root access token");
    }

    // Validate type using the same root token
    http:Response|error? typeValidation = validateRootOrgType(orgId, "abb-managed", rootToken);
    if typeValidation is http:Response {
        return typeValidation;
    } else if typeValidation is error {
        return typeValidation;
    }

    OrganizationPatchOperation[] patchOps = [];

    if request.businessName is string {
        string businessName = <string>request.businessName;
        patchOps.push({operation: "REPLACE", path: "/name", value: businessName});
    }

    if request.gisGuid is string {
        string gisGuid = <string>request.gisGuid;
        patchOps.push({operation: "REPLACE", path: "/attributes/GISGUID", value: gisGuid});
    }

    if request.businessRegistrationNo is string {
        string businessRegistrationNo = <string>request.businessRegistrationNo;
        patchOps.push({operation: "REPLACE", path: "/attributes/BusinessRegistrationNo", value: businessRegistrationNo});
    }

    if request.country is string {
        string country = <string>request.country;
        patchOps.push({operation: "REPLACE", path: "/attributes/Country", value: country});
    }

    map<string|string[]> headers = {
        "Authorization": string `Bearer ${rootToken}`,
        "Content-Type": "application/json"
    };

    OrganizationResponse|error response = asgardeoClient->patch(string `/api/server/v1/organizations/${orgId}`, patchOps, headers = headers);
    if response is error {
        log:printError("Error patching managed org", response);
        return createErrorResponse(500, "Failed to update managed organization");
    }

    return mapToCustomResponse(response, "abb-managed");
}

function patchSelfOrg(string orgId, SelfOrgPatchRequest request) returns CustomOrganizationResponse|http:Response|error {
    // Get root token once for both validation and patching
    string|error rootToken = getRootAccessToken();
    if rootToken is error {
        return createErrorResponse(500, "Failed to get root access token");
    }

    // Validate type using the same root token
    http:Response|error? typeValidation = validateRootOrgType(orgId, "self-managed", rootToken);
    if typeValidation is http:Response {
        return typeValidation;
    } else if typeValidation is error {
        return typeValidation;
    }

    OrganizationPatchOperation[] patchOps = [];

    if request.businessName is string {
        string businessName = <string>request.businessName;
        patchOps.push({operation: "REPLACE", path: "/name", value: businessName});
    }

    if request.businessRegistrationNo is string {
        string businessRegistrationNo = <string>request.businessRegistrationNo;
        patchOps.push({operation: "REPLACE", path: "/attributes/BusinessRegistrationNo", value: businessRegistrationNo});
    }

    if request.country is string {
        string country = <string>request.country;
        patchOps.push({operation: "REPLACE", path: "/attributes/Country", value: country});
    }

    map<string|string[]> headers = {
        "Authorization": string `Bearer ${rootToken}`,
        "Content-Type": "application/json"
    };

    OrganizationResponse|error response = asgardeoClient->patch(string `/api/server/v1/organizations/${orgId}`, patchOps, headers = headers);
    if response is error {
        log:printError("Error patching self org", response);
        return createErrorResponse(500, "Failed to update self-managed organization");
    }

    return mapToCustomResponse(response, "self-managed");
}

function patchSubOrg(string parentOrgId, string orgId, SubOrgPatchRequest request) returns CustomOrganizationResponse|http:Response|error {
    // Get root token once for parent validation
    string|error rootToken = getRootAccessToken();
    if rootToken is error {
        return createErrorResponse(500, "Failed to get root access token");
    }

    // Validate parent type using the same root token
    http:Response|error? parentValidation = validateParentOrg(parentOrgId, "abb-managed", rootToken);
    if parentValidation is http:Response {
        http:Response|error? subOrgValidation = validateParentOrg(parentOrgId, "sub-org", rootToken);
        if subOrgValidation is http:Response {
            return createErrorResponse(400, "Parent organization must be of type 'abb-managed' or 'sub-org'");
        } else if subOrgValidation is error {
            return subOrgValidation;
        }
    } else if parentValidation is error {
        return parentValidation;
    }

    // Get org token once for both validation and patching
    string|error orgToken = switchToOrganizationToken(parentOrgId);
    if orgToken is error {
        return createErrorResponse(500, "Failed to switch to organization token");
    }

    // CLEANED: Removed parentOrgId parameter
    http:Response|error? typeValidation = validateSubOrgType(orgId, "sub-org", orgToken);
    if typeValidation is http:Response {
        return typeValidation;
    } else if typeValidation is error {
        return typeValidation;
    }

    OrganizationPatchOperation[] patchOps = [];

    if request.businessEntityName is string {
        string businessEntityName = <string>request.businessEntityName;
        patchOps.push({operation: "REPLACE", path: "/name", value: businessEntityName});
    }

    if request.country is string {
        string country = <string>request.country;
        patchOps.push({operation: "REPLACE", path: "/attributes/Country", value: country});
    }

    map<string|string[]> headers = {
        "Authorization": string `Bearer ${orgToken}`,
        "Content-Type": "application/json"
    };

    OrganizationResponse|error response = asgardeoClient->patch(string `/o/api/server/v1/organizations/${orgId}`, patchOps, headers = headers);
    if response is error {
        log:printError("Error patching sub org", response);
        return createErrorResponse(500, "Failed to update sub organization");
    }

    return mapToCustomResponse(response, "sub-org");
}

function patchSiteInManagedOrg(string parentOrgId, string orgId, SiteOrgPatchRequest request) returns CustomOrganizationResponse|http:Response|error {
    // Get root token once for parent validation
    string|error rootToken = getRootAccessToken();
    if rootToken is error {
        return createErrorResponse(500, "Failed to get root access token");
    }

    // Validate parent type using the same root token
    http:Response|error? parentValidation = validateParentOrg(parentOrgId, "abb-managed", rootToken);
    if parentValidation is http:Response {
        http:Response|error? subOrgValidation = validateParentOrg(parentOrgId, "sub-org", rootToken);
        if subOrgValidation is http:Response {
            return createErrorResponse(400, "Parent organization must be of type 'abb-managed' or 'sub-org'");
        } else if subOrgValidation is error {
            return subOrgValidation;
        }
    } else if parentValidation is error {
        return parentValidation;
    }

    // Get org token once for both validation and patching
    string|error orgToken = switchToOrganizationToken(parentOrgId);
    if orgToken is error {
        return createErrorResponse(500, "Failed to switch to organization token");
    }

    http:Response|error? typeValidation = validateSubOrgType(orgId, "site", orgToken);
    if typeValidation is http:Response {
        return typeValidation;
    } else if typeValidation is error {
        return typeValidation;
    }

    OrganizationPatchOperation[] patchOps = [];

    if request.siteId is string {
        string siteId = <string>request.siteId;
        patchOps.push({operation: "REPLACE", path: "/name", value: siteId});
        patchOps.push({operation: "REPLACE", path: "/attributes/SiteId", value: siteId});
    }

    if request.location is string {
        string location = <string>request.location;
        patchOps.push({operation: "REPLACE", path: "/attributes/Location", value: location});
    }

    map<string|string[]> headers = {
        "Authorization": string `Bearer ${orgToken}`,
        "Content-Type": "application/json"
    };

    OrganizationResponse|error response = asgardeoClient->patch(string `/o/api/server/v1/organizations/${orgId}`, patchOps, headers = headers);
    if response is error {
        log:printError("Error patching site in managed org", response);
        return createErrorResponse(500, "Failed to update site organization");
    }

    return mapToCustomResponse(response, "site");
}

function patchSiteInSelfOrg(string parentOrgId, string orgId, SiteOrgPatchRequest request) returns CustomOrganizationResponse|http:Response|error {
    // Get root token once for parent validation
    string|error rootToken = getRootAccessToken();
    if rootToken is error {
        return createErrorResponse(500, "Failed to get root access token");
    }

    // Validate parent type using the same root token
    http:Response|error? parentValidation = validateParentOrg(parentOrgId, "self-managed", rootToken);
    if parentValidation is http:Response {
        return parentValidation;
    } else if parentValidation is error {
        return parentValidation;
    }

    // Get org token once for both validation and patching
    string|error orgToken = switchToOrganizationToken(parentOrgId);
    if orgToken is error {
        return createErrorResponse(500, "Failed to switch to organization token");
    }

    // CLEANED: Removed parentOrgId parameter
    http:Response|error? typeValidation = validateSubOrgType(orgId, "site", orgToken);
    if typeValidation is http:Response {
        return typeValidation;
    } else if typeValidation is error {
        return typeValidation;
    }

    OrganizationPatchOperation[] patchOps = [];

    if request.siteId is string {
        string siteId = <string>request.siteId;
        patchOps.push({operation: "REPLACE", path: "/name", value: siteId});
        patchOps.push({operation: "REPLACE", path: "/attributes/SiteId", value: siteId});
    }
    
    if request.location is string {
        string location = <string>request.location;
        patchOps.push({operation: "REPLACE", path: "/attributes/Location", value: location});
    }

    map<string|string[]> headers = {
        "Authorization": string `Bearer ${orgToken}`,
        "Content-Type": "application/json"
    };

    OrganizationResponse|error response = asgardeoClient->patch(string `/o/api/server/v1/organizations/${orgId}`, patchOps, headers = headers);
    if response is error {
        log:printError("Error patching site in self org", response);
        return createErrorResponse(500, "Failed to update site organization");
    }

    return mapToCustomResponse(response, "site");
}

// DELETE functions
function deleteManagedOrg(string orgId) returns http:Response|error {
    // Get root token once for both validation and deletion
    string|error rootToken = getRootAccessToken();
    if rootToken is error {
        return createErrorResponse(500, "Failed to get root access token");
    }

    // Validate type using the same root token
    http:Response|error? typeValidation = validateRootOrgType(orgId, "abb-managed", rootToken);
    if typeValidation is http:Response {
        return typeValidation;
    } else if typeValidation is error {
        return typeValidation;
    }

    map<string|string[]> headers = {
        "Authorization": string `Bearer ${rootToken}`
    };

    http:Response|error response = asgardeoClient->delete(string `/api/server/v1/organizations/${orgId}`, headers = headers);
    if response is error {
        log:printError("Error deleting managed org", response);
        return createErrorResponse(500, "Failed to delete managed organization");
    }

    return response;
}

function deleteSelfOrg(string orgId) returns http:Response|error {
    // Get root token once for both validation and deletion
    string|error rootToken = getRootAccessToken();
    if rootToken is error {
        return createErrorResponse(500, "Failed to get root access token");
    }

    // Validate type using the same root token
    http:Response|error? typeValidation = validateRootOrgType(orgId, "self-managed", rootToken);
    if typeValidation is http:Response {
        return typeValidation;
    } else if typeValidation is error {
        return typeValidation;
    }

    map<string|string[]> headers = {
        "Authorization": string `Bearer ${rootToken}`
    };

    http:Response|error response = asgardeoClient->delete(string `/api/server/v1/organizations/${orgId}`, headers = headers);
    if response is error {
        log:printError("Error deleting self org", response);
        return createErrorResponse(500, "Failed to delete self-managed organization");
    }

    return response;
}

function deleteSubOrg(string parentOrgId, string orgId) returns http:Response|error {
    // Get root token once for parent validation
    string|error rootToken = getRootAccessToken();
    if rootToken is error {
        return createErrorResponse(500, "Failed to get root access token");
    }

    // Validate parent type using the same root token
    http:Response|error? parentValidation = validateParentOrg(parentOrgId, "abb-managed", rootToken);
    if parentValidation is http:Response {
        return parentValidation;
    } else if parentValidation is error {
        return parentValidation;
    }

    // Get org token once for both validation and deletion
    string|error orgToken = switchToOrganizationToken(parentOrgId);
    if orgToken is error {
        return createErrorResponse(500, "Failed to switch to organization token");
    }

    // CLEANED: Removed parentOrgId parameter
    http:Response|error? typeValidation = validateSubOrgType(orgId, "sub-org", orgToken);
    if typeValidation is http:Response {
        return typeValidation;
    } else if typeValidation is error {
        return typeValidation;
    }

    map<string|string[]> headers = {
        "Authorization": string `Bearer ${orgToken}`
    };

    http:Response|error response = asgardeoClient->delete(string `/o/api/server/v1/organizations/${orgId}`, headers = headers);
    if response is error {
        log:printError("Error deleting sub org", response);
        return createErrorResponse(500, "Failed to delete sub organization");
    }

    return response;
}

function deleteSiteFromManagedOrg(string parentOrgId, string orgId) returns http:Response|error {
    // Get root token once for parent validation
    string|error rootToken = getRootAccessToken();
    if rootToken is error {
        return createErrorResponse(500, "Failed to get root access token");
    }

    // Validate parent type using the same root token
    http:Response|error? parentValidation = validateParentOrg(parentOrgId, "abb-managed", rootToken);
    if parentValidation is http:Response {
        http:Response|error? subOrgValidation = validateParentOrg(parentOrgId, "sub-org", rootToken);
        if subOrgValidation is http:Response {
            return createErrorResponse(400, "Parent organization must be of type 'abb-managed' or 'sub-org'");
        } else if subOrgValidation is error {
            return subOrgValidation;
        }
    } else if parentValidation is error {
        return parentValidation;
    }

    // Get org token once for both validation and deletion
    string|error orgToken = switchToOrganizationToken(parentOrgId);
    if orgToken is error {
        return createErrorResponse(500, "Failed to switch to organization token");
    }

    http:Response|error? typeValidation = validateSubOrgType(orgId, "site", orgToken);
    if typeValidation is http:Response {
        return typeValidation;
    } else if typeValidation is error {
        return typeValidation;
    }

    map<string|string[]> headers = {
        "Authorization": string `Bearer ${orgToken}`
    };

    http:Response|error response = asgardeoClient->delete(string `/o/api/server/v1/organizations/${orgId}`, headers = headers);
    if response is error {
        log:printError("Error deleting site from managed org", response);
        return createErrorResponse(500, "Failed to delete site");
    }

    return response;
}

function deleteSiteFromSelfOrg(string parentOrgId, string orgId) returns http:Response|error {
    // Get root token once for parent validation
    string|error rootToken = getRootAccessToken();
    if rootToken is error {
        return createErrorResponse(500, "Failed to get root access token");
    }

    // Validate parent type using the same root token
    http:Response|error? parentValidation = validateParentOrg(parentOrgId, "self-managed", rootToken);
    if parentValidation is http:Response {
        return parentValidation;
    } else if parentValidation is error {
        return parentValidation;
    }

    // Get org token once for both validation and deletion
    string|error orgToken = switchToOrganizationToken(parentOrgId);
    if orgToken is error {
        return createErrorResponse(500, "Failed to switch to organization token");
    }

    http:Response|error? typeValidation = validateSubOrgType(orgId, "site", orgToken);
    if typeValidation is http:Response {
        return typeValidation;
    } else if typeValidation is error {
        return typeValidation;
    }

    map<string|string[]> headers = {
        "Authorization": string `Bearer ${orgToken}`
    };

    http:Response|error response = asgardeoClient->delete(string `/o/api/server/v1/organizations/${orgId}`, headers = headers);
    if response is error {
        log:printError("Error deleting site from self org", response);
        return createErrorResponse(500, "Failed to delete site");
    }

    return response;
}

// Org upgrade function
function upgradeSelfOrgToManaged(string orgId, SelfOrgUpgradeRequest request) returns CustomOrganizationResponse|http:Response|error {
    // Get root token once for both validation and upgrade
    string|error rootToken = getRootAccessToken();
    if rootToken is error {
        return createErrorResponse(500, "Failed to get root access token");
    }

    // Validate type using the same root token
    http:Response|error? typeValidation = validateRootOrgType(orgId, "self-managed", rootToken);
    if typeValidation is http:Response {
        return typeValidation;
    } else if typeValidation is error {
        return typeValidation;
    }

    OrganizationPatchOperation[] patchOps = [
        {operation: "REPLACE", path: "/attributes/type", value: "abb-managed"},
        {operation: "ADD", path: "/attributes/GISGUID", value: request.gisGuid}
    ];

    map<string|string[]> headers = {
        "Authorization": string `Bearer ${rootToken}`,
        "Content-Type": "application/json"
    };

    OrganizationResponse|error response = asgardeoClient->patch(string `/api/server/v1/organizations/${orgId}`, patchOps, headers = headers);
    if response is error {
        log:printError("Error upgrading self org to managed", response);
        return createErrorResponse(500, "Failed to upgrade self-managed organization");
    }

    return mapToCustomResponse(response, "abb-managed");
}

// Helper functions
function mapToCustomResponse(OrganizationResponse orgResponse, string orgType) returns CustomOrganizationResponse {
    record {} attributeMap = {};

    foreach Attribute attr in orgResponse.attributes {
        attributeMap[attr.key] = attr.value;
    }

    return {
        id: orgResponse.id,
        name: orgResponse.name,
        orgType: orgType,
        status: orgResponse.status,
        hasChildren: orgResponse.hasChildren,
        attributes: attributeMap
    };
}

function createErrorResponse(int statusCode, string message) returns http:Response {
    ErrorResponse errorResponse = {
        code: string `ORG-${statusCode}`,
        message: message
    };

    http:Response response = new;
    response.statusCode = statusCode;
    response.setJsonPayload(errorResponse);
    return response;
}

function buildFilteredQueryParams(int? 'limit, string? after, string? before, boolean? recursive, string filter) returns string {
    string[] params = [];
    
    params.push(string `filter=${filter}`);
    
    if 'limit is int {
        int limitValue = <int>'limit;
        params.push(string `limit=${limitValue}`);
    }
    
    if after is string {
        string afterValue = <string>after;
        params.push(string `after=${afterValue}`);
    }
    
    if before is string {
        string beforeValue = <string>before;
        params.push(string `before=${beforeValue}`);
    }
    
    if recursive is boolean && recursive {
        params.push("recursive=true");
    }
    
    return "?" + string:'join("&", ...params);
}

function buildQueryParams(int? 'limit, int? offset) returns string {
    string[] params = [];
    
    if 'limit is int {
        int limitValue = <int>'limit;
        params.push(string `limit=${limitValue}`);
    }
    
    if offset is int {
        int offsetValue = <int>offset;
        params.push(string `offset=${offsetValue}`);
    }

    if params.length() > 0 {
        return "?" + string:'join("&", ...params);
    }
    
    return "";
}

function getAttributeValue(Attribute[] attributes, string key) returns string? {
    foreach Attribute attr in attributes {
        if attr.key == key {
            return attr.value;
        }
    }
    return ();
}

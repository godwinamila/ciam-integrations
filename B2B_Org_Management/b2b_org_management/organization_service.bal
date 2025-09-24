import ballerina/http;
import ballerina/log;

// Service for custom organization management
service /organizations on new http:Listener(8081) {

    // CREATE APIs
    resource function post managedOrgs(ManagedOrgCreateRequest request) returns CustomOrganizationResponse|http:Response|error {
        return createManagedOrg(request);
    }

    resource function post selfOrgs(SelfOrgCreateRequest request) returns CustomOrganizationResponse|http:Response|error {
        return createSelfOrg(request);
    }

    resource function post managedOrgs/[string parentOrgId]/subOrgs(SubOrgCreateRequest request) returns CustomOrganizationResponse|http:Response|error {
        return createSubOrg(parentOrgId, request);
    }

    resource function post managedOrgs/[string parentOrgId]/sites(SiteOrgCreateRequest request) returns CustomOrganizationResponse|http:Response|error {
        return createSiteInManagedOrg(parentOrgId, request);
    }

    resource function post selfOrgs/[string parentOrgId]/sites(SiteOrgCreateRequest request) returns CustomOrganizationResponse|http:Response|error {
        return createSiteInSelfOrg(parentOrgId, request);
    }

    // GET APIs
    resource function get managedOrgs/[string orgId]() returns CustomOrganizationResponse|http:Response|error {
        return getManagedOrg(orgId);
    }

    resource function get selfOrgs/[string orgId]() returns CustomOrganizationResponse|http:Response|error {
        return getSelfOrg(orgId);
    }

    resource function get managedOrgs/[string parentOrgId]/subOrgs/[string orgId]() returns CustomOrganizationResponse|http:Response|error {
        return getSubOrg(parentOrgId, orgId);
    }

    resource function get managedOrgs/[string parentOrgId]/sites/[string orgId]() returns CustomOrganizationResponse|http:Response|error {
        return getSiteFromManagedOrg(parentOrgId, orgId);
    }

    resource function get selfOrgs/[string parentOrgId]/sites/[string orgId]() returns CustomOrganizationResponse|http:Response|error {
        return getSiteFromSelfOrg(parentOrgId, orgId);
    }

    // PATCH APIs
    resource function patch managedOrgs/[string orgId](ManagedOrgPatchRequest request) returns CustomOrganizationResponse|http:Response|error {
        return patchManagedOrg(orgId, request);
    }

    resource function patch selfOrgs/[string orgId](SelfOrgPatchRequest request) returns CustomOrganizationResponse|http:Response|error {
        return patchSelfOrg(orgId, request);
    }

    resource function patch managedOrgs/[string parentOrgId]/subOrgs/[string orgId](SubOrgPatchRequest request) returns CustomOrganizationResponse|http:Response|error {
        return patchSubOrg(parentOrgId, orgId, request);
    }

    resource function patch managedOrgs/[string parentOrgId]/sites/[string orgId](SiteOrgPatchRequest request) returns CustomOrganizationResponse|http:Response|error {
        return patchSiteInManagedOrg(parentOrgId, orgId, request);
    }

    resource function patch selfOrgs/[string parentOrgId]/sites/[string orgId](SiteOrgPatchRequest request) returns CustomOrganizationResponse|http:Response|error {
        return patchSiteInSelfOrg(parentOrgId, orgId, request);
    }

    // DELETE APIs
    resource function delete managedOrgs/[string orgId]() returns http:Response|error {
        return deleteManagedOrg(orgId);
    }

    resource function delete selfOrgs/[string orgId]() returns http:Response|error {
        return deleteSelfOrg(orgId);
    }

    resource function delete managedOrgs/[string parentOrgId]/subOrgs/[string orgId]() returns http:Response|error {
        return deleteSubOrg(parentOrgId, orgId);
    }

    resource function delete managedOrgs/[string parentOrgId]/sites/[string orgId]() returns http:Response|error {
        return deleteSiteFromManagedOrg(parentOrgId, orgId);
    }

    resource function delete selfOrgs/[string parentOrgId]/sites/[string orgId]() returns http:Response|error {
        return deleteSiteFromSelfOrg(parentOrgId, orgId);
    }

    // Upgrade API
    resource function post selfOrgs/[string orgId]/upgrade(SelfOrgUpgradeRequest request) returns CustomOrganizationResponse|http:Response|error {
        return upgradeSelfOrgToManaged(orgId, request);
    }
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
    string|error orgToken = switchToOrganizationToken(parentOrgId);
    if orgToken is error {
        return createErrorResponse(500, "Failed to switch to organization token");
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
        log:printError("Error creating site in managed org", response);
        return createErrorResponse(500, "Failed to create site organization");
    }

    return mapToCustomResponse(response, "site");
}

function createSiteInSelfOrg(string parentOrgId, SiteOrgCreateRequest request) returns CustomOrganizationResponse|http:Response|error {
    return createSiteInManagedOrg(parentOrgId, request);
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

    return mapToCustomResponse(response, "self-managed");
}

function getSubOrg(string parentOrgId, string orgId) returns CustomOrganizationResponse|http:Response|error {
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

    return mapToCustomResponse(response, "sub-org");
}

function getSiteFromManagedOrg(string parentOrgId, string orgId) returns CustomOrganizationResponse|http:Response|error {
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

    return mapToCustomResponse(response, "site");
}

function getSiteFromSelfOrg(string parentOrgId, string orgId) returns CustomOrganizationResponse|http:Response|error {
    return getSiteFromManagedOrg(parentOrgId, orgId);
}

// PATCH functions
function patchManagedOrg(string orgId, ManagedOrgPatchRequest request) returns CustomOrganizationResponse|http:Response|error {
    string|error rootToken = getRootAccessToken();
    if rootToken is error {
        return createErrorResponse(500, "Failed to get root access token");
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
    string|error rootToken = getRootAccessToken();
    if rootToken is error {
        return createErrorResponse(500, "Failed to get root access token");
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
    string|error orgToken = switchToOrganizationToken(parentOrgId);
    if orgToken is error {
        return createErrorResponse(500, "Failed to switch to organization token");
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
    string|error orgToken = switchToOrganizationToken(parentOrgId);
    if orgToken is error {
        return createErrorResponse(500, "Failed to switch to organization token");
    }

    OrganizationPatchOperation[] patchOps = [];

    if request.siteId is string {
        string siteId = <string>request.siteId;
        patchOps.push({operation: "REPLACE", path: "/name", value: siteId});
        patchOps.push({operation: "REPLACE", path: "/attributes/SiteId", value: siteId});
    }

    if request.region is string {
        string region = <string>request.region;
        patchOps.push({operation: "REPLACE", path: "/attributes/Region", value: region});
    }

    if request.country is string {
        string country = <string>request.country;
        patchOps.push({operation: "REPLACE", path: "/attributes/Country", value: country});
    }

    if request.city is string {
        string city = <string>request.city;
        patchOps.push({operation: "REPLACE", path: "/attributes/City", value: city});
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
    return patchSiteInManagedOrg(parentOrgId, orgId, request);
}

// DELETE functions
function deleteManagedOrg(string orgId) returns http:Response|error {
    string|error rootToken = getRootAccessToken();
    if rootToken is error {
        return createErrorResponse(500, "Failed to get root access token");
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
    return deleteManagedOrg(orgId);
}

function deleteSubOrg(string parentOrgId, string orgId) returns http:Response|error {
    string|error orgToken = switchToOrganizationToken(parentOrgId);
    if orgToken is error {
        return createErrorResponse(500, "Failed to switch to organization token");
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
    return deleteSubOrg(parentOrgId, orgId);
}

function deleteSiteFromSelfOrg(string parentOrgId, string orgId) returns http:Response|error {
    return deleteSubOrg(parentOrgId, orgId);
}

// Upgrade function
function upgradeSelfOrgToManaged(string orgId, SelfOrgUpgradeRequest request) returns CustomOrganizationResponse|http:Response|error {
    string|error rootToken = getRootAccessToken();
    if rootToken is error {
        return createErrorResponse(500, "Failed to get root access token");
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
        created: orgResponse.created,
        lastModified: orgResponse.lastModified,
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

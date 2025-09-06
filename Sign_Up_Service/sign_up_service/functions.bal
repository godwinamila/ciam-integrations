import ballerina/log;
import ballerina/lang.regexp as regexp;
import ballerina/lang.value;

// Function to normalize organization name
function normalizeOrganizationName(string businessName) returns string {
    // Convert to lowercase and replace spaces with hyphens
    string lowercaseName = businessName.toLowerAscii();
    regexp:RegExp spacePattern = re ` +`;
    string normalizedName = regexp:replaceAll(spacePattern, lowercaseName, "-");
    return string `${normalizedName}-org`;
}

// Function to get current access token using client credentials
function getCurrentAccessToken() returns string|error {
    string credentials = string `${asgardeoClientId}:${asgardeoClientSecret}`;
    string encodedCredentials = credentials.toBytes().toBase64();

    map<string|string[]> headers = {
        "Authorization": string `Basic ${encodedCredentials}`,
        "Content-Type": "application/x-www-form-urlencoded"
    };

    string requestBody = string `grant_type=client_credentials&scope=${asgardeoScopes}`;

    TokenSwitchResponse|error response = asgardeoClient->post("/oauth2/token", requestBody, headers = headers);

    if response is error {
        log:printError(string`Error getting current access token: - ${response.detail().toString()}`);
        return response;
    }

    log:printDebug("API Response - getCurrentAccessToken: " + value:toJsonString(response));
    return response.access_token;
}

// Function to switch token to organization context
function switchToOrganizationToken(string organizationId) returns string|error {
    // Get current access token
    string|error currentToken = getCurrentAccessToken();
    if currentToken is error {
        return currentToken;
    }

    string credentials = string `${asgardeoClientId}:${asgardeoClientSecret}`;
    string encodedCredentials = credentials.toBytes().toBase64();

    map<string|string[]> headers = {
        "Authorization": string `Basic ${encodedCredentials}`,
        "Content-Type": "application/x-www-form-urlencoded"
    };

    string requestBody = string `grant_type=organization_switch&token=${currentToken}&scope=${orgSwitchScopes}&switching_organization=${organizationId}`;

    TokenSwitchResponse|error response = asgardeoClient->post("/oauth2/token", requestBody, headers = headers);

    if response is error {
        log:printError(string`Error switching to organization token: - ${response.detail().toString()}`);
        return response;
    }

    log:printDebug("API Response - switchToOrganizationToken: " + value:toJsonString(response));
    log:printInfo("Successfully switched to organization token for org: " + organizationId);
    return response.access_token;
}

// Function to get Console application ID
function getConsoleApplicationId(string accessToken) returns string|error {
    string filterQuery = "excludeSystemPortals=false&filter=name+eq+Console";
    string endpoint = string `/o/api/server/v1/applications?${filterQuery}`;

    map<string|string[]> headers = {
        "Authorization": string `Bearer ${accessToken}`,
        "Accept": "application/json"
    };

    ApplicationsResponse|error response = asgardeoClient->get(endpoint, headers = headers);

    if response is error {
        log:printError(string`Error getting Console application: - ${response.detail().toString()}`);
        return response;
    }

    log:printDebug("API Response - getConsoleApplicationId: " + value:toJsonString(response));
    Application[] applications = response.applications;
    if applications.length() == 0 {
        return error("Console application not found");
    }

    string consoleAppId = applications[0].id;
    log:printInfo("Successfully retrieved Console application ID: " + consoleAppId);
    return consoleAppId;
}

// Function to get Console app roles
function getConsoleAppRoles(string consoleAppId, string accessToken) returns ConsoleAppRole[]|error {
    string filterQuery = string `count=10&excludedAttributes=users,groups,permissions,associatedApplications&filter=audience.value+eq+${consoleAppId}&startIndex=0`;
    string endpoint = string `/o/scim2/v2/Roles?${filterQuery}`;

    map<string|string[]> headers = {
        "Authorization": string `Bearer ${accessToken}`,
        "Accept": "application/json"
    };

    ConsoleAppRolesResponse|error response = asgardeoClient->get(endpoint, headers = headers);

    if response is error {
        log:printError(string`Error getting Console app roles: - ${response.detail().toString()}`);
        return response;
    }

    log:printDebug("API Response - getConsoleAppRoles: " + value:toJsonString(response));
    ConsoleAppRole[] roles = response.Resources;
    log:printInfo("Successfully retrieved Console app roles. Count: " + roles.length().toString());
    return roles;
}

// Function to find Administrator role ID from console app roles
function findAdministratorRoleId(ConsoleAppRole[] consoleAppRoles) returns string|error {
    foreach ConsoleAppRole role in consoleAppRoles {
        if role.displayName == "Administrator" {
            log:printInfo("Found Administrator role with ID: " + role.id);
            return role.id;
        }
    }
    return error("Administrator role not found in console app roles");
}

// Function to assign org-admins-group to Console Administrator role
function assignGroupToConsoleAdministratorRole(string administratorRoleId, string groupId, string accessToken) returns error? {
    json patchRequest = {
        Operations: [
            {
                op: "add",
                value: {
                    groups: [
                        {
                            value: groupId
                        }
                    ]
                }
            }
        ],
        schemas: ["urn:ietf:params:scim:api:messages:2.0:PatchOp"]
    };

    map<string|string[]> headers = {
        "Authorization": string `Bearer ${accessToken}`,
        "Content-Type": "application/json",
        "Accept": "application/json"
    };

    string endpoint = string `/o/scim2/v2/Roles/${administratorRoleId}`;

    PatchResponse|error response = asgardeoClient->patch(endpoint, patchRequest, headers = headers);

    if response is error {
        log:printError(string`Error assigning org-admins-group to Console Administrator role: - ${response.detail().toString()}`);
        return response;
    }

    log:printDebug("API Response - assignGroupToConsoleAdministratorRole: " + value:toJsonString(response));
    log:printInfo("Successfully assigned org-admins-group to Console Administrator role");
    return ();
}

// Function to create org-admin role in organization
function createOrgAdminRole(string organizationId, string accessToken) returns string|error {
    RoleCreateRequest roleRequest = {
        audience: {
            'type: "ORGANIZATION",
            value: organizationId
        },
        displayName: "org-admin",
        permissions: [
            {value: "internal_org_role_mgt_update"},
            {value: "internal_org_role_mgt_delete"},
            {value: "internal_org_role_mgt_create"},
            {value: "internal_org_role_mgt_view"},
            {value: "internal_org_governance_update"},
            {value: "internal_org_governance_view"},
            {value: "internal_org_user_mgt_delete"},
            {value: "internal_org_user_mgt_list"},
            {value: "internal_org_user_mgt_create"},
            {value: "internal_org_user_mgt_update"},
            {value: "internal_org_user_mgt_view"},
            {value: "internal_org_branding_preference_update"},
            {value: "internal_org_bulk_resource_create"},
            {value: "internal_org_notification_senders_view"},
            {value: "internal_org_notification_senders_create"},
            {value: "internal_org_notification_senders_update"},
            {value: "internal_org_notification_senders_delete"},
            {value: "internal_org_authenticator_view"},
            {value: "internal_org_session_view"},
            {value: "internal_org_session_delete"},
            {value: "internal_org_claim_meta_update"},
            {value: "internal_org_claim_meta_view"},
            {value: "internal_org_organization_discovery_view"},
            {value: "internal_org_offline_invite"},
            {value: "internal_org_group_mgt_update"},
            {value: "internal_org_group_mgt_delete"},
            {value: "internal_org_group_mgt_view"},
            {value: "internal_org_group_mgt_create"},
            {value: "internal_org_application_mgt_delete"},
            {value: "internal_org_application_mgt_create"},
            {value: "internal_org_application_mgt_view"},
            {value: "internal_org_application_mgt_update"},
            {value: "internal_org_idp_update"},
            {value: "internal_org_idp_delete"},
            {value: "internal_org_idp_create"},
            {value: "internal_org_idp_view"},
            {value: "internal_org_recovery_create"},
            {value: "internal_org_recovery_view"},
            {value: "internal_org_guest_mgt_invite_list"},
            {value: "internal_org_guest_mgt_invite_add"},
            {value: "internal_org_guest_mgt_invite_delete"},
            {value: "internal_org_idle_account_list"},
            {value: "internal_org_password_expired_user_view"},
            {value: "internal_org_organization_update"},
            {value: "internal_org_organization_delete"},
            {value: "internal_org_organization_view"},
            {value: "internal_org_organization_create"},
            {value: "internal_org_email_mgt_view"},
            {value: "internal_org_email_mgt_create"},
            {value: "internal_org_email_mgt_delete"},
            {value: "internal_org_email_mgt_update"},
            {value: "internal_org_userstore_update"},
            {value: "internal_org_userstore_view"},
            {value: "internal_org_userstore_delete"},
            {value: "internal_org_userstore_create"},
            {value: "internal_org_template_mgt_view"},
            {value: "internal_org_template_mgt_update"},
            {value: "internal_org_template_mgt_create"},
            {value: "internal_org_template_mgt_delete"},
            {value: "internal_org_api_resource_view"},
            {value: "internal_org_oauth2_introspect"},
            {value: "internal_org_dcr_delete"},
            {value: "internal_org_dcr_create"},
            {value: "internal_org_dcr_view"},
            {value: "internal_org_dcr_update"},
            {value: "internal_org_user_association_create"},
            {value: "internal_org_user_association_delete"},
            {value: "internal_org_user_association_view"},
            {value: "internal_org_user_shared_access_view"},
            {value: "internal_org_user_unshare"},
            {value: "internal_org_user_share"},
            {value: "internal_org_oidc_scope_mgt_view"},
            {value: "internal_org_custom_authenticator_update"},
            {value: "internal_org_custom_authenticator_create"},
            {value: "internal_org_custom_authenticator_delete"},
            {value: "internal_org_user_impersonate"},
            {value: "internal_org_async_operation_status_view"},
            {value: "internal_org_validation_rule_mgt_update"},
            {value: "internal_org_workflow_delete"},
            {value: "internal_org_workflow_view"},
            {value: "internal_org_workflow_update"},
            {value: "internal_org_workflow_create"},
            {value: "internal_org_action_mgt_update"},
            {value: "internal_org_action_mgt_view"},
            {value: "internal_org_action_mgt_delete"},
            {value: "internal_org_action_mgt_create"},
            {value: "internal_org_fed_user_association_bulk"},
            {value: "internal_org_workflow_instance_view"},
            {value: "internal_org_workflow_instance_delete"},
            {value: "internal_org_workflow_association_update"},
            {value: "internal_org_workflow_association_view"},
            {value: "internal_org_workflow_association_create"},
            {value: "internal_org_workflow_association_delete"},
            {value: "internal_org_user_code_mgt_create"},
            {value: "internal_org_user_code_mgt_update"},
            {value: "internal_org_user_code_mgt_delete"},
            {value: "internal_org_user_code_mgt_view"},
            {value: "internal_org_rule_metadata_view"},
            {value: "internal_org_approval_task_update"},
            {value: "internal_org_approval_task_view"}
        ],
        schemas: []
    };

    map<string|string[]> headers = {
        "Authorization": string `Bearer ${accessToken}`,
        "Content-Type": "application/json",
        "Accept": "application/json"
    };

    RoleCreateResponse|error response = asgardeoClient->post("/o/scim2/v2/Roles", roleRequest, headers = headers);

    if response is error {
        log:printError(string`Error creating org-admin role: - ${response.detail().toString()}`);
        return response;
    }

    log:printDebug("API Response - createOrgAdminRole: " + value:toJsonString(response));
    log:printInfo("Successfully created org-admin role: " + response.id);
    return response.id;
}

// Function to create org-admins-group
function createOrgAdminsGroup(string accessToken) returns string|error {
    GroupCreateRequest groupRequest = {
        displayName: "DEFAULT/org-admins-group",
        members: [],
        schemas: ["urn:ietf:params:scim:schemas:core:2.0:Group"]
    };

    map<string|string[]> headers = {
        "Authorization": string `Bearer ${accessToken}`,
        "Content-Type": "application/json",
        "Accept": "application/json"
    };

    Group|error response = asgardeoClient->post("/o/scim2/Groups", groupRequest, headers = headers);

    if response is error {
        log:printError(string`Error creating org-admins-group: - ${response.detail().toString()}`);
        return response;
    }

    log:printDebug("API Response - createOrgAdminsGroup: " + value:toJsonString(response));
    log:printInfo("Successfully created org-admins-group: " + response.id);
    return response.id;
}

// Function to get org-admins-group group ID
function getOrgAdminsGroupId(string accessToken) returns string|error {
    string filterQuery = "filter=displayName+eq+org-admins-group";
    string endpoint = string `/o/scim2/Groups?${filterQuery}`;

    map<string|string[]> headers = {
        "Authorization": string `Bearer ${accessToken}`,
        "Accept": "application/json"
    };

    GroupGetResponse|error response = asgardeoClient->get(endpoint, headers = headers);

    if response is error {
        log:printError(string`Error getting org-admins-group group: - ${response.detail().toString()}`);
        return response;
    }

    log:printDebug("API Response - getOrgAdminsGroupId: " + value:toJsonString(response));
    Group[] groups = response.Resources;
    if groups.length() == 0 {
        return error("Group org-admins-group not found");
    }

    string groupId = groups[0].id;
    log:printInfo("Successfully retrieved org-admins-group grouo ID: " + groupId);
    return groupId;
}

// Function to assign role to group
function assignRoleToGroup(string roleId, string groupId, string accessToken) returns error? {
    json patchRequest = {
        Operations: [
            {
                op: "add",
                value: {
                    groups: [
                        {
                            display: "org-admins-group",
                            value: groupId
                        }
                    ]
                }
            }
        ],
        schemas: ["urn:ietf:params:scim:api:messages:2.0:PatchOp"]
    };

    map<string|string[]> headers = {
        "Authorization": string `Bearer ${accessToken}`,
        "Content-Type": "application/json",
        "Accept": "application/json"
    };

    string endpoint = string `/o/scim2/v2/Roles/${roleId}`;

    PatchResponse|error response = asgardeoClient->patch(endpoint, patchRequest, headers = headers);

    if response is error {
        log:printError(string`Error assigning role to group: - ${response.detail().toString()}`);
        return response;
    }

    log:printDebug("API Response - assignRoleToGroup: " + value:toJsonString(response));
    log:printInfo("Successfully assigned org-admin role to org-admins-group");
    return ();
}

// Function to check if organization exists by business name
function checkOrganizationExists(string businessName) returns Organization?|error {
    // Get access token for organization management
    string|error accessToken = getCurrentAccessToken();
    if accessToken is error {
        return accessToken;
    }

    string filterQuery = string `filter=attributes.business-name+eq+${businessName}`;
    string endpoint = string `/api/server/v1/organizations?${filterQuery}`;

    map<string|string[]> headers = {
        "Authorization": string `Bearer ${accessToken}`,
        "Accept": "application/json"
    };

    OrganizationsResponse|error response = asgardeoClient->get(endpoint, headers = headers);

    if response is error {
        log:printError(string`Error checking organization existence: - ${response.detail().toString()}`);
        return response;
    }

    log:printDebug("API Response - checkOrganizationExists: " + value:toJsonString(response));
    Organization[]? organizations = response.organizations;
    if organizations is () {
        return ();
    }

    if organizations.length() == 0 {
        return ();
    }

    return organizations[0];
}

// Function to create a new organization
function createOrganization(string businessName, string organizationName) returns OrganizationCreateResponse|error {
    // Get access token for organization management
    string|error accessToken = getCurrentAccessToken();
    if accessToken is error {
        return accessToken;
    }

    OrganizationCreateRequest createRequest = {
        name: organizationName,
        attributes: [
            {
                key: "business-name",
                value: businessName
            },
            {
                key: "type",
                value: "self-managed-org"
            }
        ]
    };

    map<string|string[]> headers = {
        "Authorization": string `Bearer ${accessToken}`,
        "Content-Type": "application/json",
        "Accept": "application/json"
    };

    OrganizationCreateResponse|error response = asgardeoClient->post("/api/server/v1/organizations", createRequest, headers = headers);

    if response is error {
        log:printError(string`Error creating organization: - ${response.detail().toString()}`);
        return response;
    }

    log:printDebug("API Response - createOrganization: " + value:toJsonString(response));
    log:printInfo("Successfully created organization: " + response.name);
    return response;
}

// Function to create a new user with dynamic payload
function createUser(BusinessInfo userData, string orgToken) returns UserCreateResponse|error {
    // Start with base payload containing required fields
    map<anydata> userCreateRequest = {
        "schemas": ["urn:ietf:params:scim:schemas:core:2.0:User"]
    };

    // Add required email field
    if userData.emailAddress is string {
        string emailAddress = <string>userData.emailAddress;
        userCreateRequest["emails"] = [
            {
                "primary": true,
                "value": emailAddress
            }
        ];
        userCreateRequest["userName"] = "DEFAULT/" + emailAddress;
    } else {
        return error("Email address is required for user creation");
    }

    // Add required password field
    if userData.password is string {
        userCreateRequest["password"] = userData.password;
    } else {
        return error("Password is required for user creation");
    }

    // Conditionally add name fields if available
    if userData.givenName is string || userData.lastName is string {
        map<anydata> nameObject = {};
        if userData.givenName is string {
            nameObject["givenName"] = userData.givenName;
        }
        if userData.lastName is string {
            nameObject["familyName"] = userData.lastName;
        }
        userCreateRequest["name"] = nameObject;
    }

    // Conditionally add phone numbers if mobile is available
    if userData.mobile is string {
        userCreateRequest["phoneNumbers"] = [
            {
                "type": "mobile",
                "value": userData.mobile
            }
        ];
    }

    // Conditionally add WSO2 schema extension if country is available
    if userData.country is string {
        userCreateRequest["urn:scim:wso2:schema"] = {
            "verifyEmail": "true",
            "country": userData.country
        };
    }

    // Conditionally add custom schema extension if marketing consent is available
    if userData.marketingConsent is string {
        boolean marketingConsentValue = userData.marketingConsent == "yes";
        userCreateRequest["urn:scim:schemas:extension:custom:User"] = {
            "marketing_consent": marketingConsentValue
        };
    }

    map<string|string[]> headers = {
        "Authorization": string `Bearer ${orgToken}`,
        "Content-Type": "application/json",
        "Accept": "application/json"
    };

    UserCreateResponse|error userCreateResponse = asgardeoClient->post("/o/scim2/Users", userCreateRequest, headers = headers);

    if userCreateResponse is error {
        log:printError(string`Error creating user:  - ${userCreateResponse.detail().toString()}`);
        return userCreateResponse;
    }

    log:printDebug("API Response - createUser: " + value:toJsonString(userCreateResponse));
    log:printInfo("Successfully created user: " + userCreateResponse.id);
    return userCreateResponse;
}

// Function to assign user to group
function assignGroup(string username, string userId, string groupId, string orgToken) returns error? {
    
    json patchRequest = {
        Operations: [
            {
                op: "add",
                value: {
                    members: [
                        {
                            display: username,
                            value: userId
                        }
                    ]
                }
            }
        ],
        schemas: ["urn:ietf:params:scim:api:messages:2.0:PatchOp"]
    };

    map<string|string[]> headers = {
        "Authorization": string `Bearer ${orgToken}`,
        "Content-Type": "application/json",
        "Accept": "application/json"
    };

    string endpoint = string `/o/scim2/Groups/${groupId}`;

    PatchResponse|error response = asgardeoClient->patch(endpoint, patchRequest, headers = headers);

    if response is error {
        log:printError(string`Error assigning user to group:  - ${response.detail().toString()}`);
        return response;
    }

    log:printDebug("API Response - assignGroup: " + value:toJsonString(response));
    log:printInfo("Successfully assigned org-admins-group group to user");
    return ();
}

// Function to share user with subsequent orgs
function shareUser(string userId, string orgToken) returns error? {
    json patchRequest = {
        "userCriteria": {
            "userIds": [
                userId
            ]
        },
        "policy": "IMMEDIATE_EXISTING_AND_FUTURE_ORGS",
        "roles": [
            {
            "displayName": "Administrator",
            "audience": {
                "display": "Console",
                "type": "application"
            }
            }
        ]
    };

    map<string|string[]> headers = {
        "Authorization": string `Bearer ${orgToken}`,
        "Content-Type": "application/json",
        "Accept": "application/json"
    };

    string endpoint = "/o/api/server/v1/users/share-with-all";

    json|error response = asgardeoClient->post(endpoint, patchRequest, headers = headers);

    if response is error {
        log:printError(string`Error sharing user:  - ${response.detail().toString()}`);
        return response;
    }

    log:printDebug("API Response - shareUser: " + value:toJsonString(response));
    log:printInfo("Successfully shared user");
    return ();
}

// Function to handle user creation and sharing flow
function handleUserCreationFlow(BusinessInfo businessInfo, OrganizationInfo orgInfo) returns error? {
    
    // Create User
    UserCreateResponse|error createdUser = createUser(businessInfo, orgInfo.accessToken);
    if createdUser is error {
        return createdUser;
    }

    if (!orgInfo.isExistingOrg) {
        // Assign Admin Group to User
        error? assignGroupResult = assignGroup(createdUser.userName, createdUser.id, orgInfo.orgAdminGroupId, orgInfo.accessToken);
        if assignGroupResult is error {
            return assignGroupResult;
        }

        // Share user with all sub-orgs 
        error? usersharingResult = shareUser(createdUser.id, orgInfo.accessToken);
        if usersharingResult is error {
            return usersharingResult;
        }
    }
}

// Function to handle organization setting up logic
function handleOrganizationSetup(string? businessName) returns OrganizationInfo?|error {
    if businessName is () {
        return ();
    }

    boolean createUserInExistingOrg = false;
    string orgId = "";

    // Check if organization exists
    Organization?|error existingOrg = checkOrganizationExists(businessName);

    if existingOrg is error {
        return existingOrg;
    }

    if existingOrg is Organization {
        log:printInfo("Organization already exists: " + existingOrg.name);
        createUserInExistingOrg = true;
        orgId = existingOrg.id;
    }

    // Organization doesn't exist, create new one with normalized name
    if (!createUserInExistingOrg) {
        string organizationName = normalizeOrganizationName(businessName);
        log:printInfo("Creating organization with normalized name: " + organizationName);

        OrganizationCreateResponse|error newOrg = createOrganization(businessName, organizationName);

        if newOrg is error {
            return newOrg;
        }
        orgId = newOrg.id;
    }
    

    // Switch to organization token
    string|error orgToken = switchToOrganizationToken(orgId);
    if orgToken is error {
        return orgToken;
    }

    string adminRoleId = "";
    string adminGroupId = "";

    // If it's a new org, create org-admin role and org-admins-group. 
    if (!createUserInExistingOrg) {
        string|error roleId = createOrgAdminRole(orgId, orgToken);
        if roleId is error {
            return roleId;
        }
        adminRoleId = roleId;

        string|error groupId = createOrgAdminsGroup(orgToken);
        if groupId is error {
            return groupId;
        }
        adminGroupId = groupId;

        // Assign role to group
        error? assignmentResult = assignRoleToGroup(adminRoleId, adminGroupId, orgToken);
        if assignmentResult is error {
            return assignmentResult;
        }

        // Get Console application ID
        string|error consoleAppId = getConsoleApplicationId(orgToken);
        if consoleAppId is error {
            return consoleAppId;
        }

        // Get Console app roles
        ConsoleAppRole[]|error consoleAppRoles = getConsoleAppRoles(consoleAppId, orgToken);
        if consoleAppRoles is error {
            return consoleAppRoles;
        }

        // Find Administrator role ID
        string|error administratorRoleId = findAdministratorRoleId(consoleAppRoles);
        if administratorRoleId is error {
            return administratorRoleId;
        }

        // Assign org-admins-group to Console Administrator role
        error? adminAssignmentResult = assignGroupToConsoleAdministratorRole(administratorRoleId, groupId, orgToken);
        if adminAssignmentResult is error {
            return adminAssignmentResult;
        }
    }
    log:printInfo("Successfully completed full organization setup including Console Administrator role assignment");

    return {
        id: orgId,
        isExistingOrg: createUserInExistingOrg,
        orgAdminGroupId: adminGroupId,
        accessToken: orgToken
    };
}
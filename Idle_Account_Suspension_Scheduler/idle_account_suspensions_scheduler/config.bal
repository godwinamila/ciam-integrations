// Automation mode enum
public enum AutomationMode {
    LIST = "list",
    DISABLE = "disable",
    DELETE = "delete"
}

// API Configuration
configurable string asgardeoBaseUrl = "https://api.eu.asgardeo.io/t/pocabbgroup";
configurable string asgardeoClientId = ?;
configurable string asgardeoClientSecret = ?;
configurable string asgardeoScopes = "internal_idle_account_list internal_user_mgt_list internal_user_mgt_view internal_user_mgt_update internal_user_mgt_delete";

// API Configuration
configurable string inactiveUsersApiPath = "/api/idle-account-identification/v1/inactive-users";
configurable string usersApiPath = "/scim2/Users";

// Automation Configuration
configurable AutomationMode automationMode = LIST;
configurable int inactiveDaysThreshold = 12; // Days to consider user inactive

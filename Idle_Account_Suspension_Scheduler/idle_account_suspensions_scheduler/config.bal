// API Configuration
configurable string asgardeoBaseUrl = "https://api.eu.asgardeo.io/t/pocabbgroup";
configurable string asgardeoClientId = ?;
configurable string asgardeoClientSecret = ?;
configurable string asgardeoScopes = "SYSTEM";
configurable string orgSwitchScopes = "SYSTEM";

// API Configuration
configurable string b2cIncativeUsersApiPath = "/api/idle-account-identification/v1/inactive-users";
configurable string b2bIncativeUsersApiPath = "/o/api/idle-account-identification/v1/inactive-users";
configurable string b2cUsersApiPath = "/scim2/Users";
configurable string b2bUsersApiPath = "/o/scim2/Users";

// Operational Configuration
configurable OperationType operationType = B2C_LIST;
configurable int inactiveDaysThreshold = 3; // Days to consider user inactive


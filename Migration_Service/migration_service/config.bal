// Configurable parameters.
configurable string asgardeoUrl = "https://api.eu.asgardeo.io/t/pocabbgroup";
configurable string asgardeoTokenUrl = "https://api.eu.asgardeo.io/t/pocabbgroup/oauth2/token";
configurable string asgardeoClientId = ?;
configurable string asgardeoClientSecret = ?;


// Configurable parameters.
configurable string legacyIDPBaseUrl = ?;
configurable string legacyIDPClientId = ?;
configurable string legacyIDPClientSecret = ?;
configurable string legacyIDPCert = ?;

// Asgardeo scopes to invoke the APIs.
final string asgardeoScopes = "internal_user_mgt_view";

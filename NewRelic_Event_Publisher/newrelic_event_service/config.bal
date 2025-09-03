// Webhook service configuration
configurable string webhookSecret = ?;
configurable boolean skipSignatureVerification = true;

// New Relic Configuration
configurable string newRelicApiKey = ?;
configurable string newRelicAccountId = ?;
configurable string newRelicEventApiHostname = "https://insights-collector.eu01.nr-data.net";
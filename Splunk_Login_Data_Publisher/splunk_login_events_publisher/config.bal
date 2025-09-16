// Webhook service configuration
configurable string webhookSecret = "bchrbfchrbjr54674hncrcfvgtg";
configurable boolean skipSignatureVerification = true;

// Configuration for Splunk HEC endpoint
configurable string splunkUrl = ?;
configurable string hecToken = ?;
configurable string splunkServiceCert = "resources/cert/splunkcloud-chain.pem";
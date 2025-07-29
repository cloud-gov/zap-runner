// Enhanced OAuth2 authentication script for UAA with token refresh
var ScriptVars = Java.type("org.zaproxy.zap.extension.script.ScriptVars");

function authenticate(helper, paramsValues, credentials) {
  var AuthenticationHelper = Java.type(
    "org.zaproxy.zap.authentication.AuthenticationHelper"
  );
  var HttpRequestHeader = Java.type(
    "org.parosproxy.paros.network.HttpRequestHeader"
  );
  var HttpHeader = Java.type("org.parosproxy.paros.network.HttpHeader");
  var URI = Java.type("org.apache.commons.httpclient.URI");

  var clientId = paramsValues.get("clientId");
  var clientSecret = paramsValues.get("clientSecret");
  var tokenUrl = paramsValues.get("tokenUrl");
  var scope = paramsValues.get("scope") || "";

  // Check if we have a valid token in script vars
  var cachedToken = ScriptVars.getGlobalVar("uaa_token_" + clientId);
  var tokenExpiry = ScriptVars.getGlobalVar("uaa_token_expiry_" + clientId);

  if (cachedToken && tokenExpiry) {
    var now = new Date().getTime();
    var expiry = parseInt(tokenExpiry);

    if (now < expiry) {
      print("Using cached UAA token for client: " + clientId);
      return new AuthenticationHelper.AuthenticationCredentials(
        "Authorization: Bearer " + cachedToken
      );
    }
  }

  print("Requesting new UAA token for client: " + clientId);

  // Build token request
  var tokenUri = new URI(tokenUrl, true);
  var tokenRequest = helper.prepareMessage();

  tokenRequest.setRequestHeader(
    new HttpRequestHeader(HttpRequestHeader.POST, tokenUri, HttpHeader.HTTP11)
  );

  // Set form data
  var requestBody =
    "grant_type=client_credentials" +
    "&client_id=" +
    encodeURIComponent(clientId) +
    "&client_secret=" +
    encodeURIComponent(clientSecret);

  if (scope) {
    requestBody += "&scope=" + encodeURIComponent(scope);
  }

  tokenRequest.setRequestBody(requestBody);
  tokenRequest
    .getRequestHeader()
    .setHeader("Content-Type", "application/x-www-form-urlencoded");

  // Add Basic Auth header for UAA
  var basicAuth = java.util.Base64.getEncoder().encodeToString(
    (clientId + ":" + clientSecret).getBytes()
  );
  tokenRequest
    .getRequestHeader()
    .setHeader("Authorization", "Basic " + basicAuth);

  // Send request
  helper.sendAndReceive(tokenRequest);

  // Check response status
  var statusCode = tokenRequest.getResponseHeader().getStatusCode();
  if (statusCode != 200) {
    print("UAA token request failed with status: " + statusCode);
    print("Response: " + tokenRequest.getResponseBody().toString());
    return null;
  }

  // Parse response
  var response = tokenRequest.getResponseBody().toString();
  var jsonResponse = JSON.parse(response);
  var accessToken = jsonResponse.access_token;
  var expiresIn = jsonResponse.expires_in || 3600;

  // Cache token with expiry
  var expiryTime = new Date().getTime() + (expiresIn - 300) * 1000; // 5 min buffer
  ScriptVars.setGlobalVar("uaa_token_" + clientId, accessToken);
  ScriptVars.setGlobalVar("uaa_token_expiry_" + clientId, String(expiryTime));

  print(
    "UAA token obtained successfully, expires in: " + expiresIn + " seconds"
  );

  // Return the authentication credentials
  return new AuthenticationHelper.AuthenticationCredentials(
    "Authorization: Bearer " + accessToken
  );
}

function getRequiredParamsNames() {
  return ["clientId", "clientSecret", "tokenUrl"];
}

function getOptionalParamsNames() {
  return ["scope"];
}

function getCredentialsParamsNames() {
  return [];
}

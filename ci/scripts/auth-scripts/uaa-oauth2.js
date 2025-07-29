// OAuth2 authentication script for UAA
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

  tokenRequest.setRequestBody(requestBody);
  tokenRequest
    .getRequestHeader()
    .setHeader("Content-Type", "application/x-www-form-urlencoded");

  // Send request
  helper.sendAndReceive(tokenRequest);

  // Parse response
  var response = tokenRequest.getResponseBody().toString();
  var jsonResponse = JSON.parse(response);
  var accessToken = jsonResponse.access_token;

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

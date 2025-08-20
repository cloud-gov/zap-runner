// OAuth2 authentication script for UAA (simple client_credentials)
function authenticate(helper, paramsValues, credentials) {
  var AuthenticationHelper = Java.type("org.zaproxy.zap.authentication.AuthenticationHelper");
  var HttpRequestHeader = Java.type("org.parosproxy.paros.network.HttpRequestHeader");
  var HttpHeader = Java.type("org.parosproxy.paros.network.HttpHeader");
  var URI = Java.type("org.apache.commons.httpclient.URI");

  var clientId = paramsValues.get("clientId");
  var clientSecret = paramsValues.get("clientSecret");
  var tokenUrl = paramsValues.get("tokenUrl");

  var tokenUri = new URI(tokenUrl, true);
  var tokenRequest = helper.prepareMessage();
  tokenRequest.setRequestHeader(new HttpRequestHeader(HttpRequestHeader.POST, tokenUri, HttpHeader.HTTP11));
  var body = "grant_type=client_credentials&client_id=" + encodeURIComponent(clientId) + "&client_secret=" + encodeURIComponent(clientSecret);
  tokenRequest.setRequestBody(body);
  tokenRequest.getRequestHeader().setHeader("Content-Type", "application/x-www-form-urlencoded");
  helper.sendAndReceive(tokenRequest);
  var json = JSON.parse(tokenRequest.getResponseBody().toString());
  return new AuthenticationHelper.AuthenticationCredentials("Authorization: Bearer " + json.access_token);
}
function getRequiredParamsNames(){ return ["clientId","clientSecret","tokenUrl"]; }
function getOptionalParamsNames(){ return ["scope"]; }
function getCredentialsParamsNames(){ return []; }

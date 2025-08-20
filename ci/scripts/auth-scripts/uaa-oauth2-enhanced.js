// OAuth2 UAA with caching + expiry buffer
var ScriptVars = Java.type("org.zaproxy.zap.extension.script.ScriptVars");
function authenticate(helper, paramsValues, credentials) {
  var AuthenticationHelper = Java.type("org.zaproxy.zap.authentication.AuthenticationHelper");
  var HttpRequestHeader = Java.type("org.parosproxy.paros.network.HttpRequestHeader");
  var HttpHeader = Java.type("org.parosproxy.paros.network.HttpHeader");
  var URI = Java.type("org.apache.commons.httpclient.URI");
  var clientId = paramsValues.get("clientId");
  var clientSecret = paramsValues.get("clientSecret");
  var tokenUrl = paramsValues.get("tokenUrl");
  var scope = paramsValues.get("scope") || "";
  var cached = ScriptVars.getGlobalVar("uaa_token_" + clientId);
  var exp = ScriptVars.getGlobalVar("uaa_token_expiry_" + clientId);
  if (cached && exp && (new Date().getTime() < parseInt(exp))) {
    return new AuthenticationHelper.AuthenticationCredentials("Authorization: Bearer " + cached);
  }
  var tokenUri = new URI(tokenUrl, true);
  var req = helper.prepareMessage();
  req.setRequestHeader(new HttpRequestHeader(HttpRequestHeader.POST, tokenUri, HttpHeader.HTTP11));
  var body = "grant_type=client_credentials&client_id=" + encodeURIComponent(clientId) + "&client_secret=" + encodeURIComponent(clientSecret);
  if (scope) body += "&scope=" + encodeURIComponent(scope);
  req.setRequestBody(body);
  req.getRequestHeader().setHeader("Content-Type","application/x-www-form-urlencoded");
  helper.sendAndReceive(req);
  if (req.getResponseHeader().getStatusCode() != 200) return null;
  var j = JSON.parse(req.getResponseBody().toString());
  var token = j.access_token, ttl = (j.expires_in || 3600) - 300;
  ScriptVars.setGlobalVar("uaa_token_" + clientId, token);
  ScriptVars.setGlobalVar("uaa_token_expiry_" + clientId, String(new Date().getTime() + ttl*1000));
  return new AuthenticationHelper.AuthenticationCredentials("Authorization: Bearer " + token);
}
function getRequiredParamsNames(){ return ["clientId","clientSecret","tokenUrl"]; }
function getOptionalParamsNames(){ return ["scope"]; }
function getCredentialsParamsNames(){ return []; }

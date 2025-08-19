// placeholder for future SAML
function authenticate(helper, paramsValues, credentials) {
  print("SAML authentication not yet implemented");
  return null;
}
function getRequiredParamsNames(){ return ["samlEndpoint"]; }
function getOptionalParamsNames(){ return ["relayState","audienceRestriction"]; }
function getCredentialsParamsNames(){ return ["username","password"]; }

function authenticate(helper, paramsValues, credentials) {
    var tenant = paramsValues.get("tenant");
    var clientId = credentials.getParam("username");
    var clientSecret = credentials.getParam("password");

    var body = "client_id=" + encodeURIComponent(clientId) +
               "&client_secret=" + encodeURIComponent(clientSecret) +
               "&scope=" + encodeURIComponent(clientId + "/.default") +
               "&grant_type=client_credentials";

    var url = "https://login.microsoftonline.com/" + tenant + "/oauth2/v2.0/token";

    var msg = helper.prepareMessage();
    msg.getRequestHeader().setURI(new org.apache.commons.httpclient.URI(url, false));
    msg.getRequestHeader().setMethod("POST");
    msg.getRequestHeader().setHeader("Content-Type", "application/x-www-form-urlencoded");
    msg.getRequestBody().setBody(body);

    helper.sendAndReceive(msg);

    var status = msg.getResponseHeader().getStatusCode();
    if (status != 200) {
        print("Auth failed: " + status + " - " + msg.getResponseBody().toString());
        return null;
    }

    var json = JSON.parse(msg.getResponseBody().toString());
    var token = json["access_token"];

    var authMsg = helper.prepareMessage();
    authMsg.getRequestHeader().setHeader("Authorization", "Bearer " + token);
    return authMsg;
}

function getRequiredParamsNames() { return ["tenant"]; }
function getOptionalParamsNames() { return []; }
function getCredentialsParamsNames() { return ["username", "password"]; }

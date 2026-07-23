function sendingRequest(msg, initiator, helper) {
    var token = java.lang.System.getenv().get("AZURE_TOKEN");
    if (token != null && token.length() > 0) {
        msg.getRequestHeader().setHeader("Authorization", "Bearer " + token);
        var uri = msg.getRequestHeader().getURI().toString();
        java.lang.System.out.println("[AUTH-INJECTED] Added Bearer token to: " + uri.substring(0, 80));
    } else {
        java.lang.System.out.println("[AUTH-MISSING] AZURE_TOKEN env var not set!");
    }
}
function responseReceived(msg, initiator, helper) {
}

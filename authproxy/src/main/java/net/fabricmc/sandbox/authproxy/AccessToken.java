package net.fabricmc.sandbox.authproxy;

public record AccessToken(String realAccessToken, String sandboxToken) {
    public RequestProcessor.Header rewriteHeader(RequestProcessor.Header header) {
        if (header.key().equals("Authorization") && header.value().startsWith("Bearer ")) {
            String value = header.value();

            if (sandboxToken.equals(value.substring(7))) {
                return new RequestProcessor.Header("Authorization", "Bearer " + realAccessToken);
            }

            return header;
        }

        return header;
    }
}

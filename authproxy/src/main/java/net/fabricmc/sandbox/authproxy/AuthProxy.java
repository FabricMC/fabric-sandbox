package net.fabricmc.sandbox.authproxy;

import com.sun.net.httpserver.HttpExchange;

import java.io.IOException;
import java.io.InputStream;
import java.net.http.HttpClient;
import java.util.Arrays;
import java.util.List;
import java.util.Map;

public class AuthProxy implements RequestProcessor, AutoCloseable {
    private static final String SESSION_HOST = "https://sessionserver.mojang.com";
    private static final String SESSION_PATH = "/session";
    private static final String SESSION_SYSTEM_PROPERTY = "minecraft.api.session.host";

    private static final String SERVICES_HOST = "https://api.minecraftservices.com";
    private static final String SERVICES_PATH = "/api";
    private static final String SERVICES_SYSTEM_PROPERTY = "minecraft.api.services.host";

    private static final List<String> IGNORED_HEADERS = List.of("Connection", "Host", "Content-length");

    private static final HttpClient HTTP_CLIENT = HttpClient.newHttpClient();

    private final int port;
    private final AccessToken accessToken;
    private final AuthProxyServer server;

    private AuthProxy(int port, AccessToken accessToken, String sessionHost, String servicesHost) throws IOException {
        this.port = port;
        this.accessToken = accessToken;
        this.server = AuthProxyServer.create(port, Map.of(
                SESSION_PATH, new ProxyHttpHandler(this, SESSION_PATH, sessionHost, HTTP_CLIENT),
                SERVICES_PATH, new ProxyHttpHandler(this, SERVICES_PATH, servicesHost, HTTP_CLIENT)
        ));
        this.server.start();
    }

    public static AuthProxy create(int port, AccessToken accessToken) throws IOException {
        return create(port, accessToken, SESSION_HOST, SERVICES_HOST);
    }

    public static AuthProxy create(int port, AccessToken accessToken, String sessionHost, String servicesHost) throws IOException {
        return new AuthProxy(port, accessToken, sessionHost, servicesHost);
    }

    private String getProxyHost() {
        return "http://localhost:" + port;
    }

    public String getSessionProxyAddress() {
        return getProxyHost() + SESSION_PATH;
    }

    public String getApiProxyAddress() {
        return getProxyHost() + SERVICES_PATH;
    }

    public Map<String, String> getSystemProperties() {
        return Map.of(
            SESSION_SYSTEM_PROPERTY, getSessionProxyAddress(),
            SERVICES_SYSTEM_PROPERTY, getApiProxyAddress()
        );
    }

    // The list of arguments to pass to the Minecraft game to configure it to use the proxy
    public List<String> getArguments() {
        return List.of(
            "-D" + SESSION_SYSTEM_PROPERTY + "=" + getSessionProxyAddress(),
            "-D" + SERVICES_SYSTEM_PROPERTY + "=" + getApiProxyAddress()
        );
    }

    @Override
    public void close() throws Exception {
        server.close();
    }

    @Override
    public Request process(HttpExchange exchange) {
        return new Request() {
            @Override
            public String path() {
                return exchange.getRequestURI().getPath();
            }

            @Override
            public String method() {
                return exchange.getRequestMethod();
            }

            @Override
            public Header[] headers() {
                Header[] headers = Header.of(exchange.getRequestHeaders());
                return Arrays.stream(headers)
                        .filter(header -> !IGNORED_HEADERS.contains(header.key()))
                        .map(accessToken::rewriteHeader)
                        .toArray(Header[]::new);
            }

            @Override
            public byte[] body() throws IOException {
                byte[] body;

                try (InputStream is = exchange.getRequestBody()) {
                    body = is.readAllBytes();
                }

                if (body.length == 0) {
                    return null;
                }

                return body;
            }
        };
    }
}

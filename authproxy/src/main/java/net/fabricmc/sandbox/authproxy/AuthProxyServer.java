package net.fabricmc.sandbox.authproxy;

import com.sun.net.httpserver.HttpServer;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.util.Map;

public class AuthProxyServer implements AutoCloseable {
    private static final int BACKLOG = 8;

    private final HttpServer server;

    private AuthProxyServer(HttpServer server) {
        this.server = server;
    }

    public static AuthProxyServer create(int port, Map<String, ProxyHttpHandler> handlers) throws IOException {
        HttpServer server = HttpServer.create(new InetSocketAddress(port), BACKLOG);
        AuthProxyServer authProxyServer = new AuthProxyServer(server);
        handlers.forEach(server::createContext);
        server.setExecutor(null); // TODO might want to use a thread pool?
        return authProxyServer;
    }

    public void start() {
        server.start();
    }

    @Override
    public void close() throws Exception {
        server.stop(0);
    }
}

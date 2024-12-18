package net.fabricmc.sandbox.authproxy;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;
import java.io.InputStream;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.Arrays;

public class ProxyHttpHandler implements HttpHandler {
    private static final boolean ENABLE_SENSITIVE_LOGGING = false;
    private static final Logger LOGGER = LoggerFactory.getLogger(ProxyHttpHandler.class);

    private final RequestProcessor requestProcessor;
    private final String pathPrefix;
    private final String proxyHost;
    private final HttpClient httpClient;

    public ProxyHttpHandler(RequestProcessor requestProcessor, String pathPrefix, String proxyHost, HttpClient httpClient) {
        this.requestProcessor = requestProcessor;
        this.pathPrefix = pathPrefix;

        if (!proxyHost.startsWith("http://")  && !proxyHost.startsWith("https://")) {
            throw new IllegalArgumentException("Invalid proxy host: " + proxyHost);
        }

        this.proxyHost = proxyHost;
        this.httpClient = httpClient;

        LOGGER.info("Proxying requests with path prefix '{}' to '{}'", pathPrefix, proxyHost);
    }

    @Override
    public void handle(HttpExchange exchange) throws IOException {
        try {
            handleInternal(exchange);
        } catch (Exception e) {
            e.printStackTrace();
            exchange.sendResponseHeaders(500, 0);
        } finally {
            exchange.close();
        }
    }

    private void handleInternal(HttpExchange exchange) throws IOException {
        byte[] body;

        try (InputStream is = exchange.getRequestBody()) {
            body = is.readAllBytes();
        }

        if (body.length == 0) {
            body = null;
        }


        if (ENABLE_SENSITIVE_LOGGING) {
            LOGGER.warn("Incoming Request:");
            LOGGER.warn("  Path: {}", exchange.getRequestURI().toString());
            LOGGER.warn("  Method: {}", exchange.getRequestMethod());
            LOGGER.warn("  Headers: {}", exchange.getRequestHeaders());
            LOGGER.warn("  Body: {}", body != null ? new String(body) : "null");
        }

        RequestProcessor.Request request = requestProcessor.process(exchange, body);

        String path = request.path();
        if (!path.startsWith(pathPrefix)) {
            exchange.sendResponseHeaders(400, 0);
            return;
        }

        String pathWithoutPrefix = path.substring(pathPrefix.length());
        URI proxyUri = URI.create(proxyHost + pathWithoutPrefix);

        if (ENABLE_SENSITIVE_LOGGING) {
            LOGGER.warn("Proxy Outgoing Request:");
            LOGGER.warn("  Path: {}", proxyUri);
            LOGGER.warn("  Method: {}", request.method());
            LOGGER.warn("  Headers: {}", Arrays.toString(request.headers()));
            LOGGER.warn("  Body: {}", request.body() != null ? new String(request.body()) : "null");
        }

        body = request.body();

        HttpRequest.Builder proxyRequest = HttpRequest.newBuilder()
                .uri(proxyUri)
                .method(request.method(), body != null ? HttpRequest.BodyPublishers.ofByteArray(body) : HttpRequest.BodyPublishers.noBody())
                .headers(RequestProcessor.Header.toPairs(request.headers()));

        HttpResponse<byte[]> response;

        try {
            response = httpClient.send(proxyRequest.build(), HttpResponse.BodyHandlers.ofByteArray());
        } catch (InterruptedException e) {
            throw new RuntimeException(e);
        }

        if (ENABLE_SENSITIVE_LOGGING) {
            LOGGER.warn("Proxy Response:");
            LOGGER.warn("  Status: {}", response.statusCode());
            LOGGER.warn("  Headers: {}", response.headers());
            LOGGER.warn("  Body: {}", new String(response.body()));
        }

        exchange.sendResponseHeaders(response.statusCode(), response.body().length);

        if (response.body().length > 0) {
            exchange.getResponseBody().write(response.body());
        }
    }
}

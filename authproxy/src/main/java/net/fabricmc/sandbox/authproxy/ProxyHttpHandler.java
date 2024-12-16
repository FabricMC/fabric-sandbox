package net.fabricmc.sandbox.authproxy;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;

public class ProxyHttpHandler implements HttpHandler {
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
    }

    @Override
    public void handle(HttpExchange exchange) throws IOException {
        try {
            handleInternal(exchange);
        } catch (Exception e) {
//            e.printStackTrace();
            exchange.sendResponseHeaders(500, 0);
        } finally {
            exchange.close();
        }
    }

    private void handleInternal(HttpExchange exchange) throws IOException {
        RequestProcessor.Request request = requestProcessor.process(exchange);

        String path = request.path();
        if (!path.startsWith(pathPrefix)) {
            exchange.sendResponseHeaders(400, 0);
            return;
        }

        String pathWithoutPrefix = path.substring(pathPrefix.length());
        URI proxyUri = URI.create(proxyHost + pathWithoutPrefix);

        byte[] body = request.body();

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

        exchange.sendResponseHeaders(response.statusCode(), response.body().length);

        if (response.body().length > 0) {
            exchange.getResponseBody().write(response.body());
        }
    }
}

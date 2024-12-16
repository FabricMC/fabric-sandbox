package net.fabricmc.sandbox.authproxy;

import com.sun.net.httpserver.Headers;
import com.sun.net.httpserver.HttpExchange;

import java.io.IOException;
import java.util.stream.Stream;

public interface RequestProcessor {
    Request process(HttpExchange exchange);

    interface Request {
        String path();

        String method();

        Header[] headers();

        byte[] body() throws IOException;
    }

    record Header(String key, String value) {
        public static Header[] of(Headers headers) {
            return headers.entrySet().stream()
                    .flatMap(entry -> entry.getValue().stream().map(value -> new Header(entry.getKey(), value)))
                    .toArray(Header[]::new);
        }

        // Header key value pairs
        public static String[] toPairs(Header[] headers) {
            return java.util.Arrays.stream(headers)
                    .flatMap(header -> Stream.of(header.key(), header.value()))
                    .toArray(String[]::new);
        }
    }
}

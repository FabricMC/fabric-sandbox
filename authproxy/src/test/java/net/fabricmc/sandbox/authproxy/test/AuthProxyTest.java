package net.fabricmc.sandbox.authproxy.test;

import com.mojang.authlib.Environment;
import com.mojang.authlib.EnvironmentParser;
import com.mojang.authlib.HttpAuthenticationService;
import com.mojang.authlib.minecraft.client.MinecraftClient;
import io.javalin.Javalin;
import net.fabricmc.sandbox.authproxy.AccessToken;
import net.fabricmc.sandbox.authproxy.AuthProxy;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.net.Proxy;
import java.util.Locale;

import static org.junit.jupiter.api.Assertions.assertEquals;

public class AuthProxyTest {
    private static final AccessToken ACCESS_TOKEN = new AccessToken("6e5fc4e4-efa7-48e8-8837-ee658dad7f27", "00000000-0000-0000-0000-000000000000");

    protected Javalin javalin;
    protected AuthProxy authProxy;
    protected Environment environment;

    @BeforeEach
    void setUp() throws IOException {
        javalin = Javalin.create().start(8081);
        String javalinHost = "http://localhost:" + javalin.port();
        authProxy = AuthProxy.create(8080, ACCESS_TOKEN, javalinHost, javalinHost);
        authProxy.getSystemProperties().forEach(System::setProperty);
        environment = EnvironmentParser.getEnvironmentFromProperties().orElseThrow();
    }

    @AfterEach
    void tearDown() throws Exception {
        javalin.stop();
        authProxy.close();
    }

    @Test
    void getWithValidAccessToken() {
        MinecraftClient client = new MinecraftClient(ACCESS_TOKEN.sandboxToken(), Proxy.NO_PROXY);

        javalin.get("/test1", ctx -> {
            assertEquals("Bearer " + ACCESS_TOKEN.realAccessToken(), ctx.header("Authorization"));
            ctx.status(200);
        });

        client.get(HttpAuthenticationService.constantURL(environment.servicesHost() + "/test1"), Void.class);
    }

    @Test
    void postWithBody() {
        MinecraftClient client = new MinecraftClient(ACCESS_TOKEN.sandboxToken(), Proxy.NO_PROXY);

        javalin.post("/test2", ctx -> {
            assertEquals("Bearer " + ACCESS_TOKEN.realAccessToken(), ctx.header("Authorization"));
            String body = ctx.body().toUpperCase(Locale.ROOT);
            ctx.status(200);
            ctx.result(body);
        });

        String result = client.post(HttpAuthenticationService.constantURL(environment.servicesHost() + "/test2"), "hello world", String.class);
        assertEquals("HELLO WORLD", result);
    }

    @Test
    void forwardsUnknownTokens() {
        MinecraftClient client = new MinecraftClient("unknown", Proxy.NO_PROXY);

        javalin.get("/test3", ctx -> {
            assertEquals("Bearer unknown", ctx.header("Authorization"));
            ctx.status(200);
        });

        client.get(HttpAuthenticationService.constantURL(environment.servicesHost() + "/test3"), Void.class);
    }
}

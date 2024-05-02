package net.fabricmc.sandbox.utils;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.Locale;
import java.util.Objects;

public class LibraryLoader {
    private static final boolean ARM64 = System.getProperty("os.arch").toLowerCase(Locale.ROOT).equals("aarch64");
    private static final String BASE_PATH = "fabric-sandbox/%s/".formatted(ARM64 ? "aarch64" : "x86_64");

    public static void loadLibraries(String scope) throws IOException {
        Path nativePath = Files.createTempDirectory("fabric-sandbox-native");

        String dlls;
        try (InputStream is = LibraryLoader.class.getClassLoader().getResourceAsStream(BASE_PATH + scope + ".libs")) {
            if (is == null) throw new IOException("Could not read library list for scope: " + scope);
            dlls = new String(is.readAllBytes(), StandardCharsets.UTF_8);
        }

        for (String libraryName : dlls.split("\n")) {
            loadLibrary(nativePath, libraryName);
        }
    }

    private static void loadLibrary(Path dir, String name) throws IOException {
        final Path path = dir.resolve(name);

        try (InputStream is = LibraryLoader.class.getClassLoader().getResourceAsStream(BASE_PATH + name)) {
            Objects.requireNonNull(is, "Could not read library file: " + name);
            Files.copy(is, path, StandardCopyOption.REPLACE_EXISTING);
        }

        System.load(path.toAbsolutePath().toString());
    }
}

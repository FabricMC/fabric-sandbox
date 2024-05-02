package net.fabricmc.sandbox.runtime;

import net.fabricmc.sandbox.utils.LibraryLoader;

import java.io.IOException;
import java.io.UncheckedIOException;

public class Main {
    public static void main(String[] args) {
        try {
            LibraryLoader.loadLibraries("runtime");
        } catch (IOException e) {
            throw new UncheckedIOException("Failed to load runtime libraries", e);
        }

        String realMain = System.getProperty("fabric.sandbox.realMain");
        if (realMain == null) {
            throw new IllegalStateException("Unable to find real main");
        }

        try {
            Class<?> mainClass = Class.forName(realMain);
            mainClass.getMethod("main", String[].class).invoke(null, (Object) args);
        } catch (ReflectiveOperationException e) {
            throw new RuntimeException("Failed to invoke main method", e);
        }
    }
}

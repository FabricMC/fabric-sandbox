package net.fabricmc.sandbox;

import net.fabricmc.sandbox.utils.LibraryLoader;

import java.io.IOException;

public class Main {
    public static void main(String[] args) throws IOException {
        LibraryLoader.loadLibraries("sandbox");
        System.gc();
        nativeEntrypoint();
    }

    public static native void nativeEntrypoint();
}

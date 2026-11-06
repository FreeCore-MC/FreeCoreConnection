package com.freecore.connection;

import java.util.Locale;

/** Pure handshake-label classifier: never infer physical route or use remote addresses. */
public final class RouteLabels {
    private RouteLabels() {}
    public static String classify(String host, boolean bedrock, boolean identityReliable) {
        if (bedrock || !identityReliable || host == null) return "unknown";
        String normalized = host.toLowerCase(Locale.ROOT).replaceFirst("\\.$", "");
        return switch (normalized) {
            case "mc.freecore.cc", "dx.freecore.cc", "lt.freecore.cc", "yd.freecore.cc" -> "main";
            case "lx.freecore.cc" -> "lx";
            default -> "unknown";
        };
    }
}

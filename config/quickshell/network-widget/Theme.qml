// Colours for the network widget.
//
// The palette comes from wallust, so the panel follows the current wallpaper
// like the rest of the dots:
//   ~/.config/hypr/waybar/wallust/colors-waybar.css  (preferred: full palette)
//   ~/.config/quickshell/qml_color.json              (fallback roles)
// Both are watched, so a theme change repaints the panel without a restart.
//
// Surfaces, borders and muted text are mixed from the palette background and
// text colour instead of being taken from single palette slots: wallust dark
// palettes keep colour0-5 very dark, which would be unreadable as a surface.

import QtQuick
import Quickshell

Item {
    id: theme

    // Quickshell.env() returns null for an unset variable, not an empty string.
    readonly property string configHome: {
        var xdg = Quickshell.env("XDG_CONFIG_HOME");
        if (xdg) return xdg;
        var home = Quickshell.env("HOME");
        return (home ? home : "") + "/.config";
    }

    readonly property string paletteFile: configHome + "/hypr/waybar/wallust/colors-waybar.css"
    readonly property string jsonFile: configHome + "/quickshell/qml_color.json"

    property color bg: "#161618"
    property color surface: "#232326"
    property color surfaceAlt: "#2c2c30"
    property color hover: "#26262a"
    property color text: "#e6e1e8"
    property color muted: "#a9a3ab"
    property color accent: "#cba6f7"
    property color accentInk: "#161618"
    property color border: "#3a3a3f"
    property color good: "#a6e3a1"
    property color bad: "#f38ba8"

    property string fontFamily: "JetBrainsMono Nerd Font"
    property string iconFont: "JetBrainsMono Nerd Font"

    // Both sources arrive through FileView; keep them so either can rebuild
    // the palette without one clobbering the other.
    property string paletteText: ""
    property string jsonText: ""

    function applyPaletteCss(text) {
        theme.paletteText = text ? text : "";
        theme.rebuild();
    }

    function applyJson(text) {
        theme.jsonText = text ? text : "";
        theme.rebuild();
    }

    function parseChannel(text) {
        var value = text.trim();
        if (/^[0-9]+$/.test(value)) return parseInt(value, 10);
        if (/^[0-9a-fA-F]{2}$/.test(value)) return parseInt(value, 16);
        return NaN;
    }

    function parseColor(text) {
        var value = text.trim();
        var hex = /^#([0-9a-fA-F]{6})([0-9a-fA-F]{2})?$/.exec(value);
        if (hex) return Qt.color("#" + hex[1] + (hex[2] ? hex[2] : ""));
        var fn = /^rgba?\(([^)]*)\)$/.exec(value);
        if (!fn) return null;
        var parts = fn[1].split(",");
        if (parts.length < 3) return null;
        var r = theme.parseChannel(parts[0]);
        var g = theme.parseChannel(parts[1]);
        var b = theme.parseChannel(parts[2]);
        var a = parts.length > 3 ? parseFloat(parts[3]) : 1;
        if (isNaN(r) || isNaN(g) || isNaN(b) || isNaN(a)) return null;
        return Qt.rgba(r / 255, g / 255, b / 255, a);
    }

    function parsePalette(text) {
        var palette = {};
        if (!text) return palette;
        var pattern = /@define-color\s+([A-Za-z0-9_-]+)\s+([^;]+);/g;
        var match = pattern.exec(text);
        while (match !== null) {
            var color = theme.parseColor(match[2]);
            if (color !== null) palette[match[1]] = color;
            match = pattern.exec(text);
        }
        return palette;
    }

    // Colours can arrive as strings (#RRGGBB) or as color values; Qt.color
    // normalises both, which matters because a string has no .r/.g/.b.
    function luminance(value) {
        var color = Qt.color(value);
        return 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b;
    }

    // Blend from one colour to another; ratio 1 is fully `to`.
    function mix(fromValue, toValue, ratio) {
        var from = Qt.color(fromValue);
        var to = Qt.color(toValue);
        return Qt.rgba(
            from.r + (to.r - from.r) * ratio,
            from.g + (to.g - from.g) * ratio,
            from.b + (to.b - from.b) * ratio, 1);
    }

    function pickText(palette, bg) {
        var names = ["color7", "color15", "cursor", "foreground", "color6"];
        var bgLum = theme.luminance(bg);
        var best = null;
        var bestDistance = 0.28;
        for (var i = 0; i < names.length; i++) {
            var candidate = palette[names[i]];
            if (!candidate) continue;
            var distance = Math.abs(theme.luminance(candidate) - bgLum);
            if (distance > bestDistance) {
                bestDistance = distance;
                best = candidate;
            }
        }
        return best;
    }

    function pickAccent(palette, bg) {
        var bgLum = theme.luminance(bg);
        // color12 is the slot the dots' Wallust styles use as the accent.
        var preferred = palette["color12"];
        if (preferred && Math.abs(theme.luminance(preferred) - bgLum) > 0.16)
            return preferred;

        var names = ["color13", "color12", "color5", "color4", "color6", "color14", "color3"];
        var best = null;
        var bestScore = 0.32;
        for (var i = 0; i < names.length; i++) {
            var candidate = palette[names[i]];
            if (!candidate) continue;
            var maxChannel = Math.max(candidate.r, candidate.g, candidate.b);
            var minChannel = Math.min(candidate.r, candidate.g, candidate.b);
            var contrast = Math.abs(theme.luminance(candidate) - bgLum);
            var score = (maxChannel - minChannel) * 1.5 + contrast;
            if (score > bestScore) {
                bestScore = score;
                best = candidate;
            }
        }
        return best;
    }

    function applyRoles(bg, text, accent) {
        theme.bg = bg;
        theme.text = text;
        theme.accent = accent;
        // Derive from the assigned color properties so the maths gets colors,
        // not the raw strings the palette or JSON supplied.
        theme.muted = theme.mix(theme.bg, theme.text, 0.62);
        theme.surface = theme.mix(theme.bg, theme.text, 0.08);
        theme.surfaceAlt = theme.mix(theme.bg, theme.text, 0.15);
        theme.hover = theme.mix(theme.bg, theme.text, 0.10);
        theme.border = theme.mix(theme.bg, theme.text, 0.20);
        theme.accentInk = theme.luminance(theme.accent) > 0.55
            ? theme.mix(theme.bg, "#000000", 0.85) : "#ffffff";
    }

    function rebuild() {
        var palette = theme.parsePalette(theme.paletteText);
        var bg = palette["background"];
        var text = bg ? theme.pickText(palette, bg) : null;

        if (bg && text) {
            var accent = theme.pickAccent(palette, bg);
            theme.applyRoles(bg, text, accent ? accent : text);
            return;
        }

        // No wallust palette yet: fall back to the quickshell role file.
        if (theme.jsonText) {
            var config = null;
            try {
                config = JSON.parse(theme.jsonText);
            } catch (error) {
                return;
            }
            if (!config) return;
            function pick(key, fallback) {
                var value = config[key];
                if (typeof value !== "string") return fallback;
                var trimmed = value.trim();
                if (/^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(trimmed)) return "#" + trimmed;
                if (/^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(trimmed)) return trimmed;
                return fallback;
            }
            var jsonBg = pick("windowBackground", theme.bg);
            var jsonText = pick("surfaceText", theme.text);
            var jsonAccent = pick("borderPrimary", theme.accent);
            theme.applyRoles(jsonBg, jsonText, jsonAccent);
        }
    }
}

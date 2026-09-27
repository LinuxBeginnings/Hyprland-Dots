# How to Add Application Icons to Workspaces in Waybar (`ModulesWorkspaces`)

[Leer en español](./HOWTO-Add-New-Application-Icons-ModulesWorkspaces.es.md)

In **KoolDots (2026)**, Waybar layouts that use the dynamic workspace module can display unique, per-application icons for every open window within each workspace.

These workspace rules and icon mappings are defined in:

```
~/.config/hypr/waybar/ModulesWorkspaces
```
*(In the repository source tree: `config/hypr/waybar/ModulesWorkspaces`)*

This guide explains how window-rewrite rules work in Waybar, how to identify an application's `class` and `title`, how to add new icon mappings, and how to reload and troubleshoot your bar.

---

## 1. Overview & Architecture

### How Does Window Rewrite Work?
Waybar's `hyprland/workspaces` module supports dynamic window rewriting via regex rules. In `ModulesWorkspaces`, this is configured under the `"hyprland/workspaces#rw"` block:

```jsonc
"hyprland/workspaces#rw": {
    "format": "{icon} {windows}",
    "format-window-separator": " ",
    "window-rewrite-default": " <span foreground='#ff0000'>✘</span> ",
    "window-rewrite": {
        "class<firefox|org.mozilla.firefox>": " ",
        "class<kitty|konsole|[Aa]lacritty>": " ",
        "title<.*youtube.*>": " "
    }
}
```

- **`format`**: `{icon} {windows}` displays the workspace number/icon followed by icons for every window open in that workspace.
- **`window-rewrite-default`**: The fallback icon shown when an application does not match any rule (in KoolDots, this displays a terminal glyph with a red cross ` ✘`).
- **`window-rewrite`**: A JSON map of regex selectors pointing to icon strings.

### Which Waybar Layouts Support This?
Most standard and modern Waybar layouts in KoolDots include `"hyprland/workspaces#rw"`:
- `TOP-Default`, `BOT-Default`
- `TOP-Default-Laptop`, `TOP-Default-Laptop-glass`
- `TOP-Simple`, `BOT-Simple`
- `TOP-Everforest`, `TOP-Everforest-glass`
- `TOP-&-BOT-SummitSplit` (and variants `v2`, `v3`, `glass`)
- `TOP-&-Left-NorthWest`, `TOP-&-Right-NorthEast`
- `BOT-&-Left-SouthWest`, `BOT-&-Right-SouthEast`
- `TOP-ddubs-simple-bar`

You can switch to any of these layouts using **SUPER + ALT + B** (Waybar Layout menu) or via Quick Settings (**SUPER + SHIFT + E**).

---

## 2. Finding an Application's `class` and `title`

To create an accurate mapping, you need the window identifier reported by Hyprland.

### Method A: Inspect the Active Window (Quickest)
Open and focus the application, then run in a terminal:

```bash
hyprctl activewindow
```

Look at the `class:` and `title:` values. For example:
```
class: org.signal.Signal
title: Signal
initialClass: org.signal.Signal
initialTitle: Signal
```

### Method B: List All Open Windows
To view classes and titles for all open windows:

```bash
hyprctl clients -j | jq '.[] | {class: .class, title: .title, workspace: .workspace.name}'
```

> **Tip:** Matching by `class<...>` is usually more reliable than `title<...>` because window titles often change dynamically (e.g. browser tab names, file paths in editors, or document titles). Use `title<...>` when an app runs inside a browser or has a generic class.

---

## 3. Choosing an Icon

- Use glyphs from **Nerd Fonts** (Font Awesome, Material Design Icons, Octicons, etc.).
- Browse icons on [Nerd Fonts Cheat Sheet](https://www.nerdfonts.com/cheat-sheet).
- **Format:** Always include a trailing space after the glyph (e.g., `"󰍩 "` or `" "`). This prevents adjacent window icons from colliding.
- **Coloring:** You can optionally use Pango markup to color icons, for example:
  ```jsonc
  "class<brave-browser>": "<span foreground='#ff5722'>🦁</span> "
  ```

---

## 4. Step-by-Step: Adding a New Icon Mapping

### Step 1: Open `ModulesWorkspaces`
Open the file in your preferred text editor:

```bash
nano ~/.config/hypr/waybar/ModulesWorkspaces
# or
nvim ~/.config/hypr/waybar/ModulesWorkspaces
```

### Step 2: Locate `"hyprland/workspaces#rw"`
Search for `"hyprland/workspaces#rw"` (around line 169) and locate the `"window-rewrite"` block:

```jsonc
"window-rewrite": {
    "title<.*amazon.*>": " ",
    "title<.*reddit.*>": " ",
    ...
```

### Step 3: Add Your Rule
Insert your rule inside `"window-rewrite"`. For example, to add **Signal Desktop**:

```jsonc
"class<[Ss]ignal|signal-desktop|org.signal.Signal>": "󰍩 ",
"title<.*Signal.*>": "󰍩 ",
```

> **Important JSON syntax rule:** Every line inside the `"window-rewrite"` block must end with a comma `,`, **except** the very last entry before the closing brace `}`.

### Step 4: Save & Reload Waybar
Reload Waybar to apply the new configuration:

- **Keybind:** Press **SUPER + ALT + R**
- **Terminal:** Run:
  ```bash
  ~/.config/hypr/scripts/Refresh.sh
  ```

---

## 5. Practical Selector Examples

### Multiple Variants & Package Formats (Native, Flatpak, AUR)
Group multiple classes using the regex alternation pipe `|`:
```jsonc
"class<[Dd]iscord|discord-canary|[Ww]ebcord|[Vv]esktop|com.discordapp.Discord|dev.vencord.Vesktop>": " ",
"class<[Tt]elegram-desktop|org.telegram.desktop|io.github.tdesktop_x64.TDesktop>": " ",
"class<VSCode|code|code-url-handler|code-oss|codium|VSCodium>": "󰨞 ",
```

### Case-Insensitive Matching
Use character classes `[Ff]` to handle both lowercase and uppercase variations:
```jsonc
"class<[Ss]potify>": " ",
"class<[Kk]denlive|org.kde.kdenlive>": "🎬 ",
```

### Web Applications & Specific Titles
When applications share a browser window class (e.g., Chrome/Firefox web apps), match on the window title:
```jsonc
"title<.*ChatGPT.*>": "󰚩 ",
"title<.*YouTube.*>": " ",
"title<.*gmail.*>": "󰊫 ",
"title<.*github.*>": " ",
```

### Catching Wrapped or Specific Binary Names
Some containerized or wrapped applications have unique class prefixes:
```jsonc
"class<virt-manager|\.virt-manager-wrapped>": " ",
"class<com\.mitchellh\.ghostty>": " ",
```

---

## 6. Troubleshooting & Tips

1. **Window displays the red cross ` ✘`:**
   - The application does not match any rule and fell back to `window-rewrite-default`.
   - Re-check the exact class with `hyprctl activewindow`.
   - Ensure special regex characters in the class are properly escaped if needed.

2. **Waybar crashes or disappears after editing:**
   - Waybar failed to parse the JSON.
   - Check for missing or extra trailing commas in `ModulesWorkspaces`.
   - Verify all quotes `"` and brackets `{ }` are matched.
   - Run Waybar in a terminal to inspect the error message:
     ```bash
     waybar -c ~/.config/hypr/waybar/config -s ~/.config/hypr/waybar/style.css
     ```

3. **Icon renders as a missing rectangle or empty box:**
   - The font installed on your system does not contain that specific glyph.
   - Choose an alternative glyph from the standard Nerd Font range supported by KoolDots.

4. **Icons do not show on your active bar:**
   - Your active Waybar theme might be using a different workspace module (such as `#roman`, `#pacman`, `#kanji`, or `#numbers`).
   - Switch to a theme with `#rw` using **SUPER + ALT + B**, or edit your active config in `~/.config/hypr/waybar/configs/` to replace `"hyprland/workspaces"` with `"hyprland/workspaces#rw"`.

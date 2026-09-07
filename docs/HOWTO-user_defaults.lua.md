# How to Configure Default Applications in KoolDots (`user_defaults.lua`)

In **KoolDots (2026)** with the Lua configuration workflow, all personal default application overrides (terminal emulator, file manager, text editors, and default web search engine) are managed in:

```
~/.config/hypr/UserConfigs/user_defaults.lua
```

This guide explains how `user_defaults.lua` works, how system defaults interact with user overrides, and provides practical examples for setting your preferred programs.

---

## 1. Overview & Architecture

### System vs. User Defaults

- **System Defaults (`~/.config/hypr/lua/user_defaults.lua`)**:
  Initializes the global `KOOLDOTS_DEFAULTS` table with fallback defaults. If environment variables like `$EDITOR` or `$VISUAL` are set, they are read; otherwise, defaults like `nano`, `kitty`, and `thunar` are used.
- **User Defaults (`~/.config/hypr/UserConfigs/user_defaults.lua`)**:
  Loaded immediately after system defaults to override any key in `KOOLDOTS_DEFAULTS`. Any changes made here are preserved across KoolDots updates.

### Supported Keys

The `KOOLDOTS_DEFAULTS` table accepts the following configuration keys:

| Key | Type | Description | Default Fallback |
|---|---|---|---|
| `term` | string | Terminal emulator launched by shortcuts | `"kitty"` |
| `edit` | string | Command-line text editor (e.g. `nvim`, `nano`, `hx`, `micro`) | `$EDITOR` or `"nano"` |
| `visual` | string | Graphical text editor / IDE (e.g. `code`, `gedit`, `kate`) | `$VISUAL` or `""` |
| `files` | string | Graphical file manager (e.g. `thunar`, `nautilus`, `dolphin`, `yazi`) | `"thunar"` |
| `search_engine` | string | URL template for default web search (`{}` is replaced with query) | `"https://www.google.com/search?q={}"` |

---

## 2. Step-by-Step Instructions

### Step 1: Open `user_defaults.lua`
Open the file in your preferred editor or via terminal:

```bash
nano ~/.config/hypr/UserConfigs/user_defaults.lua
# or
nvim ~/.config/hypr/UserConfigs/user_defaults.lua
```

*(You can also press `SUPER + SHIFT + E` to open the Kool Quick Settings editor menu).*

### Step 2: Ensure the Defaults Table is Initialized
Ensure the base table definition exists:

```lua
KOOLDOTS_DEFAULTS = KOOLDOTS_DEFAULTS or {}
```

### Step 3: Add Your Custom Defaults
Assign your desired application names or search URL patterns to the `KOOLDOTS_DEFAULTS` keys.

```lua
KOOLDOTS_DEFAULTS = KOOLDOTS_DEFAULTS or {}

KOOLDOTS_DEFAULTS.term = "kitty"
KOOLDOTS_DEFAULTS.edit = "nvim"
KOOLDOTS_DEFAULTS.visual = "code"
KOOLDOTS_DEFAULTS.files = "thunar"
KOOLDOTS_DEFAULTS.search_engine = "https://duckduckgo.com/?q={}"
```

### Step 4: Save & Reload
1. Save the file.
2. Reload Hyprland configuration:
   ```bash
   hyprctl reload
   ```
   *(or press `SUPER + ALT + R`).*

---

## 3. Practical Examples

### Example A: Modern Terminal & TUI Setup (Neovim + Ghostty + Yazi)

```lua
KOOLDOTS_DEFAULTS = KOOLDOTS_DEFAULTS or {}

KOOLDOTS_DEFAULTS.term = "ghostty"
KOOLDOTS_DEFAULTS.edit = "nvim"
KOOLDOTS_DEFAULTS.visual = "nvim"
KOOLDOTS_DEFAULTS.files = "kitty -e yazi"
KOOLDOTS_DEFAULTS.search_engine = "https://duckduckgo.com/?q={}"
```

### Example B: GNOME / GTK Ecosystem (Nautilus + Text Editor)

```lua
KOOLDOTS_DEFAULTS = KOOLDOTS_DEFAULTS or {}

KOOLDOTS_DEFAULTS.term = "alacritty"
KOOLDOTS_DEFAULTS.edit = "micro"
KOOLDOTS_DEFAULTS.visual = "gnome-text-editor"
KOOLDOTS_DEFAULTS.files = "nautilus"
KOOLDOTS_DEFAULTS.search_engine = "https://www.google.com/search?q={}"
```

### Example C: KDE / Qt Ecosystem (Dolphin + Kate)

```lua
KOOLDOTS_DEFAULTS = KOOLDOTS_DEFAULTS or {}

KOOLDOTS_DEFAULTS.term = "foot"
KOOLDOTS_DEFAULTS.edit = "nano"
KOOLDOTS_DEFAULTS.visual = "kate"
KOOLDOTS_DEFAULTS.files = "dolphin"
KOOLDOTS_DEFAULTS.search_engine = "https://search.brave.com/search?q={}"
```

---

## 4. Troubleshooting & Verification

1. **Verify Syntax**:
   Test the Lua file syntax:
   ```bash
   luac -p ~/.config/hypr/UserConfigs/user_defaults.lua
   ```

2. **Check Application Launch**:
   Test launching your terminal (`SUPER + RETURN` or `SUPER + T`) and file manager (`SUPER + E`) to ensure they open the updated applications.

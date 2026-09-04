# How to Configure Window Rules in KoolDots (`user_window_rules.lua`)

In **KoolDots (2026)** with the Lua configuration workflow, all personal window rules (floating behaviors, custom sizes, positions, opacities, tags, and workspace assignments) are managed in:

```
~/.config/hypr/UserConfigs/user_window_rules.lua
```

This guide explains how window rules work in the Lua architecture, how to find window properties (`class`, `title`), and provides practical examples for common scenarios.

---

## 1. Overview & Architecture

### System vs. User Window Rules

- **System Window Rules (`~/.config/hypr/configs/system_window_rules.lua` & `lua/window_rules.lua`)**:
  Provides default styling, floating dialog definitions, tags, and rules for core applications across the entire KoolDots setup.
- **User Window Rules (`~/.config/hypr/UserConfigs/user_window_rules.lua`)**:
  Reserved exclusively for your custom application rules and overrides. Changes here are preserved during standard dotfiles updates.

### The `apply_window_rule` Helper

User window rules are registered using the table-based `apply_window_rule()` helper:

```lua
apply_window_rule({
  name = "unique-rule-name",
  match = {
    class = "regex_pattern",
    title = "regex_pattern",
  },
  float = true,
  center = true,
})
```

---

## 2. Finding Window `class` and `title`

To apply rules accurately, you need the exact `class` or `title` reported by Hyprland.

### Method A: Inspect the Active Window
Focus the target application and run in a terminal:

```bash
hyprctl activewindow
```

Look for the `class:` and `title:` fields, e.g.:
```
class: pavucontrol
title: Volume Control
initialClass: pavucontrol
initialTitle: Volume Control
```

### Method B: List All Open Windows
To view all open windows in JSON format:

```bash
hyprctl clients -j | jq '.[] | {class: .class, title: .title, workspace: .workspace.name}'
```

---

## 3. Supported Rule Properties & Syntax

A rule definition accepts match criteria and action attributes:

| Match Property | Type | Description |
|---|---|---|
| `class` | string (regex) | Matches the window's WM_CLASS (e.g. `^([Ff]irefox)$`) |
| `title` | string (regex) | Matches the window's current title (e.g. `^[Pp]icture-in-[Pp]icture$`) |
| `initial_class` | string (regex) | Matches the class when first mapped |
| `initial_title` | string (regex) | Matches the title when first mapped |
| `tag` | string | Matches windows with a specific tag (e.g. `browser`, `terminal`) |
| `fullscreen` | boolean / number | Matches fullscreen state (`true`, `0`, `1`) |

| Action Property | Type | Example / Values |
|---|---|---|
| `float` | boolean | `float = true` |
| `center` | boolean | `center = true` |
| `size` | string | `size = "800 600"` or `size = "(monitor_w*0.6) (monitor_h*0.6)"` |
| `move` | string | `move = "100 100"` or `move = "72% 7%"` |
| `workspace` | string | `workspace = "3"` or `workspace = "special:scratchpad"` |
| `opacity` | number / string | `opacity = 0.95` or `opacity = "0.90 0.80"` (active / inactive) |
| `pin` | boolean | `pin = true` (visible on all workspaces) |
| `tag` | string | `tag = "+mytag"` |
| `idle_inhibit` | string | `"fullscreen"`, `"always"`, `"focus"` |
| `no_blur` | boolean | `no_blur = true` (disables background blur for window) |
| `no_initial_focus` | boolean | `no_initial_focus = true` (prevents stealing focus when opened) |
| `keep_aspect_ratio` | boolean | `keep_aspect_ratio = true` |

---

## 4. Step-by-Step Examples

### A. Float and Center Utility Dialogs

```lua
apply_window_rule({
  name = "user-float-audio-control",
  match = {
    class = "^(pavucontrol|org.pulseaudio.pavucontrol|com.saivert.pwvucontrol)$",
  },
  float = true,
  center = true,
  size = "(monitor_w*0.5) (monitor_h*0.55)",
})

apply_window_rule({
  name = "user-float-bluetooth",
  match = {
    class = "^(blueman-manager)$",
  },
  float = true,
  center = true,
  size = "600 500",
})
```

### B. Pinning Picture-in-Picture Video to Corner

```lua
apply_window_rule({
  name = "user-pip-video",
  match = {
    title = "^[Pp]icture-in-[Pp]icture$",
  },
  float = true,
  pin = true,
  move = "72% 7%",
  size = "(monitor_w*0.25) (monitor_h*0.25)",
  keep_aspect_ratio = true,
})
```

### C. Assigning Applications to Specific Workspaces

```lua
-- Assign Spotify to workspace 9
apply_window_rule({
  name = "user-spotify-ws",
  match = {
    class = "^([Ss]potify)$",
  },
  workspace = "9",
})

-- Assign Discord to workspace 10
apply_window_rule({
  name = "user-discord-ws",
  match = {
    class = "^([Dd]iscord|[Ww]ebCord|[Vv]esktop)$",
  },
  workspace = "10",
})
```

### D. Custom Window Transparency / Opacity

You can provide a single opacity value or two values (`"active inactive"`):

```lua
apply_window_rule({
  name = "user-terminal-opacity",
  match = {
    class = "^(kitty|ghostty|Alacritty)$",
  },
  opacity = "0.90 0.80",
})
```

### E. Prevent Focus Stealing on Launch

Useful for background communication apps or heavy IDEs launching in background:

```lua
apply_window_rule({
  name = "user-no-focus-slack",
  match = {
    class = "^(Slack|slack)$",
  },
  no_initial_focus = true,
})
```

### F. Inhibit Idle / Screen Blanking During Fullscreen Video

```lua
apply_window_rule({
  name = "user-inhibit-idle-video",
  match = {
    class = "^(mpv|vlc)$",
  },
  idle_inhibit = "focus",
})
```

---

## 5. Applying Changes & Troubleshooting

1. **Reloading Configuration**:
   After saving changes to `user_window_rules.lua`, reload Hyprland:
   ```bash
   hyprctl reload
   ```

2. **Checking Lua Syntax**:
   Ensure there are no Lua syntax errors before reloading:
   ```bash
   luac -p ~/.config/hypr/UserConfigs/user_window_rules.lua
   ```

3. **Verifying Active Rules**:
   To see which rules are currently recognized by Hyprland:
   ```bash
   hyprctl rules
   ```

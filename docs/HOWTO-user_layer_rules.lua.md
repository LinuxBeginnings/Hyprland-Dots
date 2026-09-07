# How to Configure Layer Rules in KoolDots (`user_layer_rules.lua`)

In **KoolDots (2026)** with the Lua configuration workflow, all personal rules applied to layer surfaces (status bars like Waybar, application launchers like Rofi/Wofi, notification daemons, OSD popups) are managed in:

```
~/.config/hypr/UserConfigs/user_layer_rules.lua
```

This guide explains how layer rules function in Hyprland Lua, how to inspect layer surfaces, and provides practical examples for common UI components.

---

## 1. Overview & Architecture

### Windows vs. Layers in Hyprland

- **Regular Windows**: Managed by `user_window_rules.lua` (regular application client windows that tile or float).
- **Layer Surfaces**: Desktop panels, lock screens, notification centers, on-screen displays, and launchers that render on compositor layers (`background`, `bottom`, `top`, `overlay`).
- **User Layer Rules (`~/.config/hypr/UserConfigs/user_layer_rules.lua`)**:
  Applies custom visual effects (such as background blur, opacity override, or ignoring transparency alphas) to layer surfaces.

### The `apply_layer_rule()` Helper

Layer rules are registered using the table-based `apply_layer_rule()` function:

```lua
apply_layer_rule({
  name = "unique-rule-identifier",
  match = {
    namespace = "namespace_regex_or_exact",
  },
  blur = true,
  ignore_alpha = 0.2,
})
```

---

## 2. Finding Layer Namespaces

To inspect all running layer surfaces and find their exact `namespace`:

```bash
hyprctl layers
```

Sample output:
```
levels:
  top:
    (waybar): namespace: waybar
    (swaync-control-center): namespace: swaync-control-center
  overlay:
    (rofi): namespace: rofi
```

The string after `namespace:` is the target name used in `match = { namespace = "..." }`.

---

## 3. Supported Rule Properties

| Property | Type | Description |
|---|---|---|
| `name` | string | Unique name/identifier for the rule |
| `match.namespace` | string | Namespace regex or exact string (e.g. `"rofi"`, `"waybar"`, `"swaync.*"`) |
| `blur` | boolean | Enables background blur behind the layer surface |
| `ignore_alpha` | number | Ignores blur on pixels with alpha below threshold (`0.0` to `1.0`) |
| `no_anim` | boolean | Disables open/close animations for this layer |
| `order` | number | Optional ordering priority |

---

## 4. Step-by-Step Instructions

### Step 1: Open `user_layer_rules.lua`
Open the file in your preferred text editor:

```bash
nano ~/.config/hypr/UserConfigs/user_layer_rules.lua
# or
nvim ~/.config/hypr/UserConfigs/user_layer_rules.lua
```

### Step 2: Add Layer Rules
Define rules using `apply_layer_rule({...})`.

### Step 3: Save & Reload
Reload Hyprland immediately:

```bash
hyprctl reload
```
*(or press `SUPER + ALT + R`).*

---

## 5. Practical Examples

### Example A: Blur Rofi / Application Launcher

```lua
apply_layer_rule({
  name = "user-rofi-blur",
  match = { namespace = "rofi" },
  blur = true,
  ignore_alpha = 0.2,
})
```

### Example B: Blur Waybar Top Panel

```lua
apply_layer_rule({
  name = "user-waybar-blur",
  match = { namespace = "waybar" },
  blur = true,
  ignore_alpha = 0.1,
})
```

### Example C: Blur SwayNC Notification Center & Popups

```lua
apply_layer_rule({
  name = "user-swaync-control-center-blur",
  match = { namespace = "swaync-control-center" },
  blur = true,
  ignore_alpha = 0.2,
})

apply_layer_rule({
  name = "user-swaync-notification-blur",
  match = { namespace = "swaync-notification-window" },
  blur = true,
  ignore_alpha = 0.2,
})
```

### Example D: Disable Animations on Specific OSD / Notification Popups

```lua
apply_layer_rule({
  name = "user-dunst-noanim",
  match = { namespace = "dunst" },
  no_anim = true,
})
```

---

## 6. Troubleshooting

1. **Blur is not applying to the layer**:
   Ensure `decoration.blur.enabled = true` in `user_decorations.lua` (or system defaults) and check with `hyprctl layers` that the namespace matches.
2. **Transparent borders look glitchy or dark**:
   Adjust `ignore_alpha` (e.g. from `0.1` to `0.3`) to prevent Hyprland from blurring near-transparent border artifacts.
3. **Syntax validation**:
   ```bash
   luac -p ~/.config/hypr/UserConfigs/user_layer_rules.lua
   ```

# How to Fix Ventoy GUI on Wayland/Hyprland (with Passwordless Sudo/Polkit)

If you are using Wayland (such as Hyprland, Sway, or Wayfire) and have passwordless root privileges (e.g., your user is in the `wheel` group with NOPASSWD configured in sudo/polkit), you might encounter an issue where the Ventoy GUI app crashes silently or returns to the command line immediately when launched.

## The Problem
When `pkexec` elevates your privileges to root, it aggressively strips out environment variables for security reasons. On X11 this is sometimes fine, but on Wayland, GUI applications require specific environment variables to know how to connect to the display server. 

Because `pkexec` drops variables like `WAYLAND_DISPLAY` and `XDG_RUNTIME_DIR`, the Ventoy GUI (`ventoygui`) starts as root, cannot find a display server, and crashes immediately.

## The Solution

To fix this, we need to explicitly pass the necessary display variables back into the `pkexec` environment when launching Ventoy. 

There are two main ways you launch apps: from a GUI app launcher (like Rofi, Wofi, or your desktop environment's menu) and from the command line (Terminal). Here are the fixes for both.

### Part 1: Fix App Launchers (Rofi, Wofi, Application Menus)

App launchers use `.desktop` files. We will create a local override for the Ventoy `.desktop` file and point it to a custom wrapper script that preserves the environment variables.

#### 1. Create a Wrapper Script

Create a script in your local `bin` directory (create the directory if it doesn't exist):

```bash path=null start=null
mkdir -p ~/.local/bin
```

Create the wrapper script using your favorite text editor (e.g., `nano ~/.local/bin/ventoygui-wayland`) and add the following contents:

```sh path=null start=null
#!/bin/sh
pkexec env DISPLAY=$DISPLAY WAYLAND_DISPLAY=$WAYLAND_DISPLAY XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR /usr/bin/ventoygui "$@"
```

Make the script executable:

```bash path=null start=null
chmod +x ~/.local/bin/ventoygui-wayland
```

#### 2. Create the Desktop File Override

Copy the global Ventoy `.desktop` file to your local applications folder:

```bash path=null start=null
mkdir -p ~/.local/share/applications/
cp /usr/share/applications/ventoy.desktop ~/.local/share/applications/ventoy.desktop
```

Edit the local copy (`~/.local/share/applications/ventoy.desktop`) and change the `Exec=` line to point to the new script. **Make sure to replace `USERNAME` with your actual username:**

```ini path=null start=null
[Desktop Entry]
Type=Application
Icon=ventoy
Name=Ventoy
Exec=/home/USERNAME/.local/bin/ventoygui-wayland
Terminal=false
Hidden=false
Categories=Utility
Comment=Ventoy2Disk GUI
StartupWMClass=Ventoy2Disk.gtk3
```

Finally, update your desktop database so launchers like Rofi pick up the change immediately:

```bash path=null start=null
update-desktop-database ~/.local/share/applications
```

---

### Part 2: Fix the Command Line (Terminal)

If you type `ventoygui` into your terminal, it will still use the original failing binary. To fix this, we can set up a shell alias or function.

Add the appropriate snippet below to your shell's configuration file.

#### For Bash or Zsh
Add this to the bottom of `~/.bashrc` (for Bash) or `~/.zshrc` (for Zsh):

```bash path=null start=null
# Fix for VentoyGUI under Wayland/Hyprland
alias ventoygui='pkexec env DISPLAY=$DISPLAY WAYLAND_DISPLAY=$WAYLAND_DISPLAY XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR /usr/bin/ventoygui'
```

Apply the changes:
```bash path=null start=null
# For Bash
source ~/.bashrc

# For Zsh
source ~/.zshrc
```

#### For Fish
Add this to the bottom of `~/.config/fish/config.fish`:

```fish path=null start=null
# Fix for VentoyGUI under Wayland/Hyprland
function ventoygui
    sh -c 'pkexec env DISPLAY=$DISPLAY WAYLAND_DISPLAY=$WAYLAND_DISPLAY XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR /usr/bin/ventoygui $argv'
end
```

Apply the changes:
```fish path=null start=null
source ~/.config/fish/config.fish
```

## Success!
You should now be able to launch Ventoy GUI from your terminal or your application launcher seamlessly under Wayland.
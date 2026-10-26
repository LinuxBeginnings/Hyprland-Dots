# How to upgrade the KoolDots Installers and Dotfiles

- From Waybar, right-click the dots update icon (`custom/dot_update`)
  - It downloads the installer for your OS and the current `Hyprland-Dots`
    - Both land in a temp directory under `$HOME`
  - It runs the installer's `install-scripts/update-deps.sh` first
  - Then it runs `./copy.sh --tty --express-upgrade` for you
  - It opens a terminal, because `update-deps.sh` needs `sudo` and `copy.sh`
    asks questions
  - At the end it asks before removing the downloaded files
  - A left click on the same icon only checks whether an update exists
- Before you start, make sure your OS is up to date
  - On Debian, if Hyprland is built from source, make sure it is current too
    - [Debian-Hyprland: install and upgrade](https://github.com/LinuxBeginnings/Debian-Hyprland/blob/main/Debian-Hyprland-Install-Upgrade.md)

## Upgrading by hand

- On updates to dotfiles, update the installer first
  - This ensures that any new or updated dependencies get installed
    - Remove any old versions of your distro installer
      - I.e. `Arch-Hyprland` or `Debian-Hyprland`
      - `rm -r ~/Arch-Hyprland` (Or whatever distro you are using)
      - Clone the latest installer for your distro.

```sh
 git clone https://github.com/Linuxbeginnings/Arch-Hyprland --depth 1
 cd ~/Arch-Hyprland
 install-scripts/update-deps.sh
```

- Remove old `Hyprland-Dots` if applicable
  - Clone latest Hyprland-Dots

```sh
   git clone https://github.com/Linuxbeginnings/Hyprland-Dots  --depth 1
   cd ~/Hyprland-Dots
   ./copy.sh
   select `Express update`
```

- `Express update` is faster and many of the restore questions are no longer needed
- Especially moving from the old `Hyprlang` config files to `LUA` config files
- A handy shortcut is:
  `./copy.sh --express-upgrade`
  - A simple `TTY` menu is also available
    - `./copy.sh --tty --express-upgrade`

- Assuming no errors `reboot`

| Note: If you want to de-clutter your home directory you can move these directories

- For those more familiar with `git`
  - Run:
    - Arch here is example

    ```sh
      cd ~/Arch-Hyprland
      git stash && git pull
      install-scripts/update-deps.sh
      cd ~/Hyprland-Dots
      git stash && git pull
      ./copy.sh
      select Express Upgrade
    ```

  | Note: This method on occasion can generate `git` merge errors. Method above always works

## What an upgrade keeps

An upgrade replaces the repo-managed config with the copy from the repo, then
puts your own choices back on top. These survive:

- the rofi theme from the theme selector - the `@theme` line in
  `hypr/rofi/config.rasi`
- the wlogout preset from the wlogout picker - `wlogout/.current_theme`,
  including a saved `user_backup`
- your saved display layouts - `UserConfigs/display-layouts.json`
- everything in `UserConfigs/`, `UserScripts/` and `Monitor_Profiles/`
- `hyprlock.conf`, `hypridle.conf` and `wallpaper_effects/`

Anything you hand-edit inside a repo-managed file that the installer rewrites is
still replaced. Keep personal changes in the directories listed above.

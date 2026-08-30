# How to upgrade the KoolDots Installers and Dotfiles

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

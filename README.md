[![jp](https://img.shields.io/badge/lang-jp-blue.svg)](./i18n/README/README.jp.md)
[![ro](https://img.shields.io/badge/lang-ro-green.svg)](./i18n/README/README.ro.md)
[![ru](https://img.shields.io/badge/lang-ru-red.svg)](./i18n/README/README.ru.md)
[![ua](https://img.shields.io/badge/lang-ua-white.svg)](./i18n/README/README.ua.md)
[![de](https://img.shields.io/badge/lang-de-magenta.svg)](./i18n/README/README.de.md)
[![fr](https://img.shields.io/badge/lang-fr-cyan.svg)](./i18n/README/README.fr.md)

<h3 align="center">
<img align="center" width="80%" src=https://github.com/user-attachments/assets/bc18bd4d-944b-4d5f-a119-7578fa38f9b4 />
</h3>

<p align="center">
  <img src="https://raw.githubusercontent.com/LinuxBeginnings/Hyprland-Dots/main/assets/latte.png" width="400" />
</p>

<div align="center">
<br>
  <a href="#-installationupdate-instructions"><kbd> <br> Installation <br> </kbd></a>&ensp;&ensp;
  <a href="https://github.com/LinuxBeginnings/Hyprland-Dots/wiki"><kbd> <br> Wiki <br> </kbd></a>&ensp;&ensp;
  <a href="https://www.youtube.com/@LinuxBeginnings"><kbd> <br> Youtube <br> </kbd></a>&ensp;&ensp;
  <a href="https://discord.gg/RZJgC7KAKm"><kbd> <br> Discord <br> </kbd></a>&ensp;&ensp;
  <a href="https://www.youtube.com/playlist?list=PLDtGd5Fw5_GjXCznR0BzCJJDIQSZJRbxx"><kbd> <br> Legacy Jak Videos <br> </kbd></a>&ensp;&ensp;
</div><br>

<div align="center">

<br/>
</div>

<h3 align="center">
  <img src="https://github.com/LinuxBeginnings/Telegram-Animated-Emojis/blob/main/Activity/Sparkles.webp" alt="Sparkles" width="38" height="38" />
  KooL's Hyprland Dotfiles Showcase
  <img src="https://github.com/LinuxBeginnings/Telegram-Animated-Emojis/blob/main/Activity/Sparkles.webp" alt="Sparkles" width="38" height="38" />
</h3>

<div align="center">
  <https://github.com/user-attachments/assets/49bc12b2-abaf-45de-a21c-67aacd9bb872>
</div>

---

[![Typing SVG](https://readme-typing-svg.herokuapp.com?font=Fira+Code&weight=700&size=22&pause=1000&color=F7077E&vCenter=true&width=435&height=30&lines=INSTALLATION)](https://git.io/typing-svg)

### 🏁 Auto Distro-Hyprland install scripts cloning and starting

> [!CAUTION]
> If you are using FISH SHELL, DO NOT use this function. Clone the Distro-Hyprland and ran install.sh instead

- NOTE: you need package `curl` for this to work

```bash
sh <(curl -L https://raw.githubusercontent.com/LinuxBeginnings/Hyprland-Dots/main/Distro-Hyprland.sh)
```

- You can use the above command to automatically clone the `Distro-Hyprland` install scripts
- It will clone the install script and start the `install.sh`

### 👁️‍🗨️ My Hyprland install Scripts

Automated Hyprland Scripts for Distro of choice which will pull this dotfiles if opted to install these configurations

- [Arch-Linux](https://github.com/LinuxBeginnings/Arch-Hyprland)

- [OpenSUSE(Tumbleweed)](https://github.com/LinuxBeginnings/OpenSuse-Hyprland)

- [Fedora-Linux (43/Rawhide)](https://github.com/LinuxBeginnings/Fedora-Hyprland)

- [Debian-Linux (Trixie & SID)](https://github.com/LinuxBeginnings/Debian-Hyprland)

- [NixOS (25.05+)](https://github.com/LinuxBeginnings/NixOS-Hyprland)

- [Ubuntu 24.04 LTS](https://github.com/LinuxBeginnings/Ubuntu-Hyprland/tree/24.04)
- [Ubuntu 24.10 (deprecated)](https://github.com/LinuxBeginnings/Ubuntu-Hyprland/tree/24.10)
- [Ubuntu 25.04 (deprecated)](https://github.com/LinuxBeginnings/Ubuntu-Hyprland/tree/25.04)
- [Ubuntu 25.10](https://github.com/LinuxBeginnings/Ubuntu-Hyprland/tree/25.10)

---

### 🪧 Attention

- This repo does NOT contain or will NOT install any packages. These are only pre-configured-hyprland configs or dotfiles
- refer to install scripts what packages needed to install... but at least, Hyprland packages are required
- This repo will be pulled by the Distro-Hyprland install scripts above if you opt to download pre-configured dots

### 👀 Screenshots

- All screenshots are collected here [Screenshots](https://github.com/LinuxBeginnings/screenshots/tree/main/Hyprland-ScreenShots)

### 📦 What's new?

- To easily track changes, I will be updating the [CHANGELOGS](https://github.com/LinuxBeginnings/Hyprland-Dots/wiki/Changelogs) Screenshots will be included if worth mentioning the changes!

### 💥 Installation/Update instructions

- [`MORE INFO HERE`](https://github.com/LinuxBeginnings/Hyprland-Dots/wiki/Install_&_Update)
  > [!Note]
  > The auto copy script `copy.sh` will create backups of intended directories to be copied.
  > However, it's still a good idea to manually backup just incase script fails to backup your configuration.
  > If you already have a hyprland configuration, uninstall it first, or create a new user, and install it with that user

> To download from main branch
- Clone this repo by using `git`.
- Change directory, i.e. `cd Arch-Hyprland`
- Make `install.sh` executable `chmod +x ./install.sh`
- Run the script `./install.sh`

> To download from Master branch
> Note: Ubuntu is exception, it has version specific branches

```bash
git clone --depth=1 https://github.com/LinuxBeginnings/Hyprland-Dots.git && cd Hyprland-Dots
```

> To download from Development branch
> Not recommended for non-testing systems

```bash
git clone --depth=1 https://github.com/LinuxBeginnings/Hyprland-Dots.git -b development && cd Hyprland-Dots
```

- automatic copy/install of pre-configured dots (recommended for updating)

```bash
chmod +x copy.sh
./copy.sh
```

#### ⚠️ BACKUPS CREATED by SCRIPT

> [!CAUTION]
> `copy.sh` creates a backup!
> Kindly investigate manually contents on your `$HOME/.config`
> Delete manually any backups which you dont want.

#### 🛎️ a small note on wallpapers

- by default, only few wallpapers will be copied (1 each dark and light plus 3 more). You will be offered to download more wallpapers. You can preview/check the additional wallpapers from this [`LINK`](https://github.com/LinuxBeginnings/Wallpaper-Bank/tree/main/wallpapers)

#### ⚠️ after installing these dots

- NVIDIA Owners.
  - After installation, check [`THIS`](https://github.com/LinuxBeginnings/Hyprland-Dots/wiki/FAQ_NVIDIA)
  - Make sure to edit your `~/.config/hypr/UserConfigs/ENVariables.conf` (highly recommended).
- If you have already set your own keybinds, monitors, etc.... Just copy over from backup created before log-out or reboot. (recommended)

#### 🙋 QUESTIONS ?

- FAQ! Yes you can use these dotfiles to other distro! Just ensure to install proper packages first! If it makes you feel better, I use same config on my Gentoo:)
- QUICK HINT! Click the HINT! Waybar module (only available on some layouts). Also can be launched by keybind `SUPER + H`
- More question? click here browse through this [WIKI](https://github.com/LinuxBeginnings/Hyprland-Dots/wiki/)

#### ⌨ Keybinds

- Keybinds [`HERE`](https://github.com/LinuxBeginnings/Hyprland-Dots/wiki/Keybinds)

### ✍️ Contributing

- If you have improvements on the dotfiles or configuration, feel free to submit a PR for improvement.
- I always welcome improvements as I am also just learning just like you guys!
- Click [`HERE`](https://github.com/LinuxBeginnings/Hyprland-Dots/blob/main/CONTRIBUTING.md) for a guide how to contribute

> Thanks to all who have contributed code, or support on the Discord server. Your efforts are greatly appreciated

### 🔮 Discord Server
- Want to contribute? Click [`HERE`](https://github.com/LinuxBeginnings/Hyprland-Dots/blob/main/CONTRIBUTING.md) for a guide how to contribute
  > Thanks to all who have contributed code, or support on the Discord server. You efforts are greatly appreciated

- kindly join my [Discord](https://discord.gg/RZJgC7KAKm)

### 💖 Support

- a Star on my Github repos would be nice 🌟
- Subscribe to my Youtube Channel [YouTube](https://www.youtube.com/@LinuxBeginnings)

## 🫰 Thank you for the stars 🩷

### Document translations

- Spanish: [Código de Conducta](./i18n/CODE_OF_CONDUCT/CODE_OF_CONDUCT.es.md) · [Guía de mensajes de commit](./i18n/COMMIT_MESSAGE_GUIDELINES/COMMIT_MESSAGE_GUIDELINES.es.md) · [Guía de contribución](./i18n/CONTRIBUTING/CONTRIBUTING.es.md)

- French: [Code de Conduite](./i18n/CODE_OF_CONDUCT/CODE_OF_CONDUCT.fr.md) · [Directives pour les messages de commit](./i18n/COMMIT_MESSAGE_GUIDELINES/COMMIT_MESSAGE_GUIDELINES.fr.md) · [Guide de contribution](./i18n/CONTRIBUTING/CONTRIBUTING.fr.md)

{ config, pkgs, ... }:

{
  home.username = "sastauser";
  home.homeDirectory = "/home/sastauser";
  home.stateVersion = "25.05";
  home.enableNixpkgsReleaseCheck = false;

  # CRUCIAL FOR FEDORA: Fixes GL errors and icon issues
  targets.genericLinux.enable = true;

  # 1. Simple package installs go here (things you don't need to configure)
  home.packages = [
    pkgs.ripgrep  # Useful for Yazi's search
    pkgs.fd       # Useful for Yazi's file finding

    pkgs.neovim
    pkgs.lazygit
    pkgs.gh
    pkgs.bat
    pkgs.fzf
    pkgs.zoxide
    pkgs.btop
    pkgs.htop
    pkgs.fastfetch
    pkgs.kitty
  ];

  # 2. Programs with built-in Home Manager modules go here
  programs.yazi = {
    enable = true;
    enableZshIntegration = false;  # CRITICAL: Stops Nix from touching .zshrc   
    enableBashIntegration = false; # Or enableZshIntegration if you use Zsh
    settings = {
      manager = {
        show_hidden = true;
        sort_by = "mtime";
      };
    };
  };
 home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

 programs.bash.enable = false;
 programs.zsh.enable = false;
  # Let Home Manager install and manage itself.
 programs.home-manager.enable = true;
}

#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   KooLsDotsUpgrade.sh downloads the distro installer and Hyprland-Dots into a
#   temp directory under $HOME, runs the installer's update-deps.sh, then runs
#   copy.sh --tty --express-upgrade. This suite covers the parts that can be
#   wrong without a real install:
#
#     lib_dotfiles_upgrade.sh   distro and installer resolution, branch choice,
#                               the temp directory, the command lines and the
#                               version comparison
#     KooLsDotsUpgrade.sh       the guards, and the whole plan in --dry-run
#
#   git and notify-send are faked, so --dry-run can be exercised end to end
#   without a network, a clone, or a desktop notification.
# No `set -e`: the assertion helpers return non-zero on failure, and exiting on
# the first one would hide every later check in the run.
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"

# lib_test.sh sets SCRIPT_DIR to the scripts directory.
# shellcheck source=../lib_dotfiles_upgrade.sh
source "$SCRIPT_DIR/lib_dotfiles_upgrade.sh"

UPGRADE="$SCRIPT_DIR/KooLsDotsUpgrade.sh"
WORK="$(mktemp -d)"; trap 'rm -rf -- "$WORK"' EXIT

# --- fake commands ----------------------------------------------------------
# git answers ls-remote from FAKE_BRANCHES and never clones; notify-send is
# recorded instead of shown. Both are prepended to PATH, so the real curl,
# rsync and coreutils are still used.
BIN="$WORK/bin"
mkdir -p "$BIN"
export CALL_LOG="$WORK/calls.log"
: > "$CALL_LOG"

cat >"$BIN/git" <<'EOS'
#!/usr/bin/env bash
printf 'git %s\n' "$*" >> "${CALL_LOG:-/dev/null}"
if [ "${1:-}" = "ls-remote" ]; then
  for b in ${FAKE_BRANCHES:-main}; do printf 'refs/heads/%s\n' "$b"; done
  exit 0
fi
if [ "${1:-}" = "clone" ]; then
  exit "${FAKE_GIT_CLONE_EXIT:-0}"
fi
exit 0
EOS

cat >"$BIN/notify-send" <<'EOS'
#!/usr/bin/env bash
printf 'notify-send %s\n' "$*" >> "${CALL_LOG:-/dev/null}"
exit 0
EOS

chmod +x "$BIN"/*
export PATH="$BIN:$PATH"

# --- os-release fixtures ----------------------------------------------------
os_release_fixture() { # <name> <id> <id_like> <version_id>
  local file="$WORK/os-release-$1"
  {
    printf 'ID=%s\n' "$2"
    [ -n "$3" ] && printf 'ID_LIKE="%s"\n' "$3"
    [ -n "$4" ] && printf 'VERSION_ID="%s"\n' "$4"
  } >"$file"
  printf '%s' "$file"
}

DEBIAN_FIXTURE="$(os_release_fixture debian debian '' 13)"
UBUNTU_FIXTURE="$(os_release_fixture ubuntu ubuntu debian 26.04)"
NIXOS_FIXTURE="$(os_release_fixture nixos nixos '' 25.11)"
GENTOO_FIXTURE="$(os_release_fixture gentoo gentoo '' '')"
MINT_FIXTURE="$(os_release_fixture mint linuxmint 'ubuntu debian' 22.1)"
UBUNTU_2610_FIXTURE="$(os_release_fixture ubuntu-2610 ubuntu debian 26.10)"

# --- distro detection -------------------------------------------------------
assert_eq "Debian is debian" debian "$(kdu_distro_from_osrelease "$DEBIAN_FIXTURE")"
assert_eq "Ubuntu is ubuntu" ubuntu "$(kdu_distro_from_osrelease "$UBUNTU_FIXTURE")"
assert_eq "NixOS is nixos" nixos "$(kdu_distro_from_osrelease "$NIXOS_FIXTURE")"
assert_eq "Gentoo is gentoo" gentoo "$(kdu_distro_from_osrelease "$GENTOO_FIXTURE")"
assert_eq "Arch is arch" arch \
  "$(kdu_distro_from_osrelease "$(os_release_fixture arch arch '' '')")"
assert_eq "Fedora is fedora" fedora \
  "$(kdu_distro_from_osrelease "$(os_release_fixture fedora fedora '' 43)")"
assert_eq "openSUSE Tumbleweed is opensuse" opensuse \
  "$(kdu_distro_from_osrelease "$(os_release_fixture opensuse opensuse-tumbleweed suse '')")"
assert_eq "Alpine is unknown" unknown \
  "$(kdu_distro_from_osrelease "$(os_release_fixture alpine alpine '' 3.22)")"
assert_eq "Linux Mint is ubuntu" ubuntu "$(kdu_distro_from_osrelease "$MINT_FIXTURE")"
assert_eq "Zorin OS is ubuntu" ubuntu \
  "$(kdu_distro_from_osrelease "$(os_release_fixture zorin zorin ubuntu 18)")"
assert_eq "Pop!_OS follows ID_LIKE to ubuntu" ubuntu \
  "$(kdu_distro_from_osrelease "$(os_release_fixture pop pop 'ubuntu debian' 24.04)")"
assert_eq "Kali follows ID_LIKE to debian" debian \
  "$(kdu_distro_from_osrelease "$(os_release_fixture kali kali debian 2026.1)")"
assert_eq "CachyOS follows ID_LIKE to arch" arch \
  "$(kdu_distro_from_osrelease "$(os_release_fixture cachyos cachyos arch '')")"
assert_eq "a missing os-release is unknown" unknown \
  "$(kdu_distro_from_osrelease "$WORK/no-such-os-release")"
assert_eq "quoted values lose their quotes" "Debian GNU/Linux" \
  "$(printf 'NAME="Debian GNU/Linux"\nID=debian\n' >"$WORK/os-release-names" && kdu_os_release_value "$WORK/os-release-names" NAME)"

# --- installer and branch ---------------------------------------------------
assert_eq "Debian uses the Debian installer" Debian-Hyprland "$(kdu_repo_for_distro debian)"
assert_eq "Ubuntu uses the Ubuntu installer" Ubuntu-Hyprland "$(kdu_repo_for_distro ubuntu)"
assert_eq "Arch uses the Arch installer" Arch-Hyprland "$(kdu_repo_for_distro arch)"
assert_eq "Fedora uses the Fedora installer" Fedora-Hyprland "$(kdu_repo_for_distro fedora)"
assert_eq "openSUSE uses the openSUSE installer" OpenSUSE-Hyprland "$(kdu_repo_for_distro opensuse)"

it "NixOS, Gentoo and an unknown distro are all unsupported"
unsupported=0
for key in nixos gentoo unknown; do
  kdu_supported_distro "$key" && unsupported=1
done
if [ "$unsupported" -eq 0 ]; then pass_msg; else fail "an unsupported distro was accepted"; fi

it "NixOS and Gentoo can still upgrade the dots alone"
not_dotfiles_only=0
for key in nixos gentoo; do
  kdu_dotfiles_only_distro "$key" || not_dotfiles_only=1
done
if [ "$not_dotfiles_only" -eq 0 ]; then pass_msg; else fail "a dotfiles-only distro was rejected"; fi

it "a distro with an installer is never dotfiles-only"
wrongly_only=0
for key in debian ubuntu arch fedora opensuse unknown ''; do
  kdu_dotfiles_only_distro "$key" && wrongly_only=1
done
if [ "$wrongly_only" -eq 0 ]; then pass_msg; else fail "a distro with an installer was treated as dotfiles-only"; fi

# The real upstream branch list, as of the Ubuntu-Hyprland repository.
UBUNTU_BRANCHES="24.04 24.04-development 25.10 26.04 26.04-development main"
assert_eq "Ubuntu 26.04 takes the 26.04 branch" 26.04 \
  "$(kdu_branch_for_distro ubuntu 26.04 "$UBUNTU_BRANCHES")"
assert_eq "Ubuntu 24.04 takes the 24.04 branch" 24.04 \
  "$(kdu_branch_for_distro ubuntu 24.04 "$UBUNTU_BRANCHES")"
assert_eq "a release with only a -development branch takes it" 27.10-development \
  "$(kdu_branch_for_distro ubuntu 27.10 "27.10-development main")"
assert_eq "an unbranched release falls back to main" main \
  "$(kdu_branch_for_distro ubuntu 25.04 "$UBUNTU_BRANCHES")"
assert_eq "an empty branch list falls back to main" main \
  "$(kdu_branch_for_distro ubuntu 26.04 '')"
assert_eq "a non-Ubuntu installer always uses main" main \
  "$(kdu_branch_for_distro debian 13 "$UBUNTU_BRANCHES")"
assert_eq "Debian without a VERSION_ID uses main" main \
  "$(kdu_branch_for_distro debian '' '')"

# Mint and Zorin are Ubuntu 24.04 based; 26.10 still runs the 26.04 installer.
assert_eq "Mint takes the 24.04 installer branch" 24.04 "$(kdu_branch_override linuxmint 22.1)"
assert_eq "Zorin takes the 24.04 installer branch" 24.04 "$(kdu_branch_override zorin 18)"
assert_eq "Ubuntu 26.10 takes the 26.04 installer branch" 26.04 "$(kdu_branch_override ubuntu 26.10)"
assert_eq "Ubuntu 26.04 needs no override" "" "$(kdu_branch_override ubuntu 26.04)"
assert_eq "Debian needs no override" "" "$(kdu_branch_override debian 13)"
assert_eq "Ubuntu 26.10 warns that it is unsupported" \
  "Ubuntu 26.10 not officially supported. Use at own risk" "$(kdu_release_notice ubuntu 26.10)"
assert_eq "Ubuntu 26.04 carries no warning" "" "$(kdu_release_notice ubuntu 26.04)"
assert_eq "Mint carries no warning" "" "$(kdu_release_notice linuxmint 22.1)"

# --- temp directory ---------------------------------------------------------
TMP_ROOT="$WORK/tmp-root"
CREATED="$(kdu_tempdir_create "$TMP_ROOT")"

it "the temp directory is created under the requested root"
if [ -d "$CREATED" ] && [[ "$CREATED" == "$TMP_ROOT/kooldots-upgrade-"* ]]; then pass_msg
else fail "created '$CREATED', expected kooldots-upgrade-* under $TMP_ROOT"; fi

it "two runs never share a temp directory"
SECOND="$(kdu_tempdir_create "$TMP_ROOT")"
if [ -d "$SECOND" ] && [ "$CREATED" != "$SECOND" ]; then pass_msg
else fail "the same path was handed out twice: $CREATED"; fi

it "the dry-run label is a path, not a created directory"
LABEL="$(kdu_tempdir_label "$TMP_ROOT")"
if [ -d "$LABEL" ]; then fail "the label created $LABEL"; else pass_msg; fi

# --- command lines ----------------------------------------------------------
assert_eq "the dependency command runs the installer's script" \
  "bash \"$WORK/t/Debian-Hyprland/install-scripts/update-deps.sh\"" \
  "$(kdu_updatedeps_cmd Debian-Hyprland "$WORK/t")"
assert_eq "the dotfiles command is the tty express upgrade" \
  "cd \"$WORK/t/Hyprland-Dots\" && ./copy.sh --tty --express-upgrade" \
  "$(kdu_copy_cmd "$WORK/t")"
assert_eq "the clone URL is the LinuxBeginnings repository" \
  "https://github.com/LinuxBeginnings/Debian-Hyprland.git" \
  "$(kdu_repo_url Debian-Hyprland)"

it "the clone argument list carries the clone subcommand"
if [ "$(kdu_clone_args Debian-Hyprland main "$WORK/t/Debian-Hyprland" | head -n1)" = "clone" ]; then
  pass_msg
else fail "the first argument is not 'clone'; git would be called with no subcommand"; fi

it "a main-branch clone is not pinned with -b"
if kdu_clone_args Debian-Hyprland main "$WORK/t/Debian-Hyprland" | grep -qx -- '-b'; then
  fail "a -b was passed for main"
else pass_msg; fi

assert_eq "a main-branch clone is a complete git command line" \
  "clone
--depth=1
https://github.com/LinuxBeginnings/Debian-Hyprland.git
$WORK/t/Debian-Hyprland" \
  "$(kdu_clone_args Debian-Hyprland main "$WORK/t/Debian-Hyprland")"

assert_eq "a release branch clone pins the branch" \
  "clone
--depth=1
-b
26.04
https://github.com/LinuxBeginnings/Ubuntu-Hyprland.git
$WORK/t/Ubuntu-Hyprland" \
  "$(kdu_clone_args Ubuntu-Hyprland 26.04 "$WORK/t/Ubuntu-Hyprland")"

# --- version comparison -----------------------------------------------------
it "a higher upstream version is newer"
if kdu_version_is_newer v2.3.30 2.3.29; then pass_msg
else fail "2.3.30 should be newer than 2.3.29"; fi

it "an equal version is not newer"
if kdu_version_is_newer 2.3.29 v2.3.29; then fail "equal versions must not be newer"
else pass_msg; fi

it "a lower upstream version is not newer"
if kdu_version_is_newer 2.3.28 2.3.29; then fail "2.3.28 must not be newer than 2.3.29"
else pass_msg; fi

it "an empty version never counts as newer"
if kdu_version_is_newer '' 2.3.29 || kdu_version_is_newer 2.3.30 ''; then
  fail "an empty version was treated as newer"
else pass_msg; fi

it "a pre-release suffix still compares above the older release"
if kdu_version_is_newer 2.3.30-dev 2.3.29; then pass_msg
else fail "2.3.30-dev should be newer than 2.3.29"; fi

# --- installed version ------------------------------------------------------
CFG="$WORK/cfg"
mkdir -p "$CFG/hypr/lua"
printf 'hl.env("DOTS_VERSION", "2.3.29-dev")\n' >"$CFG/hypr/lua/env.lua"
assert_eq "DOTS_VERSION is read from env.lua" 2.3.29-dev "$(kdu_installed_dots_version "$CFG/hypr")"

rm -f "$CFG/hypr/lua/env.lua"
printf '' >"$CFG/hypr/v2.3.28"
assert_eq "the version marker file is the fallback" 2.3.28 "$(kdu_installed_dots_version "$CFG/hypr")"

rm -f "$CFG/hypr/v2.3.28"
assert_eq "with neither, the version is empty" "" "$(kdu_installed_dots_version "$CFG/hypr")"

# --- guards -----------------------------------------------------------------
it "running as root is refused"
root_out="$(KOOLDOTS_UPGRADE_UID=0 bash "$UPGRADE" --dry-run 2>&1)"
root_rc=$?
if [ "$root_rc" -ne 0 ] && [[ "$root_out" == *"must NOT be run as root"* ]]; then pass_msg
else fail "expected a root refusal, got rc=$root_rc: $root_out"; fi

it "a run without a terminal is refused"
tty_out="$(KOOLDOTS_OS_RELEASE="$DEBIAN_FIXTURE" bash "$UPGRADE" </dev/null 2>&1)"
tty_rc=$?
if [ "$tty_rc" -ne 0 ] && [[ "$tty_out" == *"terminal is required"* ]]; then pass_msg
else fail "expected a terminal refusal, got rc=$tty_rc: $tty_out"; fi

it "--help exits 0"
if bash "$UPGRADE" --help | grep -q '^Usage:'; then pass_msg; else fail "--help did not print usage"; fi

# --- the dots alone, on NixOS and Gentoo ------------------------------------
# There is no installer to clone and no update-deps.sh to run, so the plan is
# one clone and copy.sh, and the OS is told so before anything happens.
DRY_NIXOS="$WORK/dry-nixos.out"
: >"$CALL_LOG"
KOOLDOTS_OS_RELEASE="$NIXOS_FIXTURE" KOOLDOTS_UPGRADE_TMP_ROOT="$WORK/dry-root" \
  bash "$UPGRADE" --dry-run >"$DRY_NIXOS" 2>&1
nixos_rc=$?
assert_eq "the NixOS --dry-run exits 0" 0 "$nixos_rc"

it "NixOS is told that only the Hyprland-Dots can be updated"
assert_contains "$DRY_NIXOS" "Only the Hyprland-Dots can be updated" "the dotfiles-only notice" && pass_msg

it "NixOS is pointed at the Packages Required wiki page"
assert_contains "$DRY_NIXOS" "$KDU_PACKAGES_WIKI_URL" "the wiki URL" && pass_msg

it "the NixOS plan names no installer"
assert_contains "$DRY_NIXOS" "Installer : none (dotfiles only)" "the installer line" && pass_msg

# The notice names update-deps.sh in prose, so the check is for the command
# line the plan would print, which is the only thing that would actually run it.
it "the NixOS plan drops the dependency step and the installer clone"
if assert_not_contains "$DRY_NIXOS" "install-scripts/update-deps.sh" "the dependency step" &&
  assert_not_contains "$DRY_NIXOS" "Debian-Hyprland.git" "an installer clone"; then pass_msg; fi

it "the NixOS plan still clones the dots and runs copy.sh"
assert_contains "$DRY_NIXOS" "Hyprland-Dots.git" "the dotfiles clone" &&
  assert_contains "$DRY_NIXOS" "copy.sh --tty --express-upgrade" "the dotfiles step" && pass_msg

it "the NixOS plan is dry: no clone, no temp directory"
if grep -q '^git clone' "$CALL_LOG"; then fail "a clone was attempted: $(grep '^git clone' "$CALL_LOG")"
elif [ -e "$WORK/dry-root" ]; then fail "$WORK/dry-root was created"
else pass_msg; fi

it "Gentoo takes the same dotfiles-only path"
gentoo_out="$(KOOLDOTS_OS_RELEASE="$GENTOO_FIXTURE" bash "$UPGRADE" --dry-run 2>&1)"
assert_contains "$gentoo_out" "Only the Hyprland-Dots can be updated" "the dotfiles-only notice" &&
  assert_not_contains "$gentoo_out" "install-scripts/update-deps.sh" "the dependency step" && pass_msg

it "the dotfiles-only prompt defaults to yes"
if grep -qF 'Continue with the dotfiles-only upgrade? [Y/n]' "$UPGRADE"; then pass_msg
else fail "the dotfiles-only [Y/n] prompt is missing"; fi

it "the dotfiles-only run consults the packages wiki"
if grep -qF 'KDU_PACKAGES_WIKI_URL' "$UPGRADE"; then pass_msg
else fail "KooLsDotsUpgrade.sh never names the packages wiki"; fi

it "an unrecognised distro keeps the old check-only notice"
unknown_out="$(KOOLDOTS_OS_RELEASE="$(os_release_fixture alpine alpine '' 3.22)" bash "$UPGRADE" --dry-run 2>&1)"
unknown_rc=$?
if [ "$unknown_rc" -eq 0 ] && [[ "$unknown_out" == *"not available for this OS"* ]] &&
  [[ "$unknown_out" != *"Only the Hyprland-Dots can be updated"* ]]; then pass_msg
else fail "expected the old unsupported notice, got rc=$unknown_rc: $unknown_out"; fi

# --- the whole plan, on Debian ---------------------------------------------
DRY_OUT="$WORK/dry-debian.out"
: >"$CALL_LOG"
KOOLDOTS_OS_RELEASE="$DEBIAN_FIXTURE" KOOLDOTS_UPGRADE_TMP_ROOT="$WORK/dry-root" \
  bash "$UPGRADE" --dry-run >"$DRY_OUT" 2>&1
dry_rc=$?
assert_eq "--dry-run exits 0" 0 "$dry_rc"

it "the advisory asks for a current OS first"
assert_contains "$DRY_OUT" "fully up to date" "the OS advisory" && pass_msg

it "the advisory links the Debian Hyprland upgrade guide"
assert_contains "$DRY_OUT" "$KDU_DEBIAN_GUIDE_URL" "the guide URL" && pass_msg

it "the plan names the Debian installer and branch"
assert_contains "$DRY_OUT" "Installer : Debian-Hyprland (branch main)" "installer and branch" && pass_msg

it "the plan lists both commands, dependencies first"
assert_contains "$DRY_OUT" "install-scripts/update-deps.sh" "the dependency step" && pass_msg
assert_contains "$DRY_OUT" "copy.sh --tty --express-upgrade" "the dotfiles step" && pass_msg
assert_order "$DRY_OUT" "install-scripts/update-deps.sh" "copy.sh --tty --express-upgrade" && pass_msg

it "the plan names the temp directory and both clones"
assert_contains "$DRY_OUT" "kooldots-upgrade-<random>" "the temp directory" && pass_msg
assert_contains "$DRY_OUT" "Debian-Hyprland.git" "the installer clone" && pass_msg
assert_contains "$DRY_OUT" "Hyprland-Dots.git" "the dotfiles clone" && pass_msg

it "--dry-run downloads nothing and creates no temp directory"
if [ -e "$WORK/dry-root" ]; then fail "$WORK/dry-root was created"; else pass_msg; fi

it "--dry-run runs no git clone"
if grep -q '^git clone' "$CALL_LOG"; then fail "a clone was attempted: $(grep '^git clone' "$CALL_LOG")"
else pass_msg; fi

# --- the branch probe, on Ubuntu -------------------------------------------
DRY_UBUNTU="$WORK/dry-ubuntu.out"
: >"$CALL_LOG"
FAKE_BRANCHES="24.04 25.10 26.04 main" KOOLDOTS_OS_RELEASE="$UBUNTU_FIXTURE" \
  KOOLDOTS_UPGRADE_TMP_ROOT="$WORK/dry-root" \
  bash "$UPGRADE" --dry-run >"$DRY_UBUNTU" 2>&1

it "the Ubuntu plan resolves the branch for the running release"
assert_contains "$DRY_UBUNTU" "Installer : Ubuntu-Hyprland (branch 26.04)" "26.04 was chosen" && pass_msg

it "the Ubuntu plan pins the clone to that branch"
assert_contains "$DRY_UBUNTU" "-b 26.04" "the clone is pinned" && pass_msg

it "the Ubuntu plan asked upstream for its branches"
if grep -q 'ls-remote' "$CALL_LOG"; then pass_msg; else fail "no branch probe was made"; fi

# --- the fixed branches: Mint, Zorin and 26.10 ------------------------------
DRY_MINT="$WORK/dry-mint.out"
: >"$CALL_LOG"
FAKE_BRANCHES="24.04 26.04 main" KOOLDOTS_OS_RELEASE="$MINT_FIXTURE" \
  KOOLDOTS_UPGRADE_TMP_ROOT="$WORK/dry-root" \
  bash "$UPGRADE" --dry-run >"$DRY_MINT" 2>&1

it "Linux Mint is planned against the 24.04 branch"
assert_contains "$DRY_MINT" "Installer : Ubuntu-Hyprland (branch 24.04)" "24.04 was chosen" && pass_msg

it "Mint pins the clone to 24.04"
assert_contains "$DRY_MINT" "-b 24.04" "the clone is pinned" && pass_msg

it "a fixed branch needs no upstream probe"
if grep -q 'ls-remote' "$CALL_LOG"; then fail "a branch probe was made"
else pass_msg; fi

DRY_2610="$WORK/dry-2610.out"
KOOLDOTS_OS_RELEASE="$UBUNTU_2610_FIXTURE" KOOLDOTS_UPGRADE_TMP_ROOT="$WORK/dry-root" \
  bash "$UPGRADE" --dry-run >"$DRY_2610" 2>&1

it "Ubuntu 26.10 is planned against the 26.04 branch"
assert_contains "$DRY_2610" "Installer : Ubuntu-Hyprland (branch 26.04)" "26.04 was chosen" && pass_msg

it "Ubuntu 26.10 warns that it is not officially supported"
assert_contains "$DRY_2610" "Ubuntu 26.10 not officially supported. Use at own risk" "the warning" && pass_msg

# --- the entry point --------------------------------------------------------
it "KooLsDotsUpdate.sh offers the upgrade and launches a terminal"
if grep -q -- '--upgrade' "$SCRIPT_DIR/KooLsDotsUpdate.sh" &&
  grep -q 'launch_upgrade_terminal' "$SCRIPT_DIR/KooLsDotsUpdate.sh" &&
  grep -q 'LaunchTerminal.sh' "$SCRIPT_DIR/KooLsDotsUpdate.sh"; then pass_msg
else fail "the upgrade action is not wired into KooLsDotsUpdate.sh"; fi

it "the update window stops advertising the installer on NixOS and Gentoo"
if grep -q 'DOTFILES_ONLY' "$SCRIPT_DIR/KooLsDotsUpdate.sh" &&
  grep -q 'KDU_PACKAGES_WIKI_URL' "$SCRIPT_DIR/KooLsDotsUpdate.sh" &&
  grep -q 'Upgrade Dots only' "$SCRIPT_DIR/KooLsDotsUpdate.sh"; then pass_msg
else fail "KooLsDotsUpdate.sh still offers an installer run on NixOS/Gentoo"; fi

it "the Waybar module right-click starts the upgrade"
if grep -q 'KooLsDotsUpdate.sh --upgrade' "$SCRIPT_DIR/../waybar/ModulesCustom"; then pass_msg
else fail "custom/dot_update has no on-click-right for the upgrade"; fi

summary "dotfiles-upgrade"

#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   The network widget (config/quickshell/network-widget) reaches the desktop
#   only through QsNetworkPanel.sh, so that script is what these checks cover:
#   what it prints for Waybar, what it prints for the panel, and what it does
#   when the shell is not running yet.
#
#   Waybar runs `status` once a second, so the sandbox makes docker, podman and
#   tailscale present and then asserts that the per-second path never calls
#   them, while the panel's own `snapshot` still does.
#
#   The QML is checked for the behaviours that are easy to undo by accident: the
#   panel starts hidden, the dismissal target is declared before the card, and
#   the surface still collapses to a pixel while the panel is closed.
# No `set -e`: the assertion helpers return non-zero on failure, and exiting on
# the first one would hide every later check in the run.
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"

ROOT="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"
WIDGET="$ROOT/config/quickshell/network-widget"
SCRIPT="$SCRIPT_DIR/QsNetworkPanel.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

export WORK
export XDG_CONFIG_HOME="$WORK/config"
export XDG_RUNTIME_DIR="$WORK/runtime"
export CALL_LOG="$WORK/calls.log"
mkdir -p "$XDG_CONFIG_HOME/hypr/scripts" "$XDG_RUNTIME_DIR" "$WORK/bin"
: >"$CALL_LOG"

# --------------------------------------------------------------- the sandbox --
# nmcli answers the four calls the snapshot makes, with one wired and one
# wireless device on a connected link.
cat >"$WORK/bin/nmcli" <<'EOS'
#!/usr/bin/env bash
printf 'nmcli %s\n' "$*" >>"$CALL_LOG"
case "$*" in
  "radio wifi") printf 'enabled\n' ;;
  *"device status"*)
    cat <<'TXT'
DEVICE:ens18
TYPE:ethernet
STATE:connected
CONNECTION:Wired connection 1
DEVICE:wlan0
TYPE:wifi
STATE:connected
CONNECTION:Linux-Da-Bomb
TXT
    ;;
  *"device show ens18"*)
    cat <<'TXT'
GENERAL.HWADDR:                 52:54:00:11:22:33
IP4.ADDRESS[1]:                 192.168.40.72/24
IP4.GATEWAY:                    192.168.40.1
IP4.DNS[1]:                     192.168.40.3
TXT
    ;;
  *"device show wlan0"*)
    cat <<'TXT'
GENERAL.HWADDR:                 AA:BB:CC:DD:EE:FF
IP4.ADDRESS[1]:                 192.168.40.80/24
IP4.GATEWAY:                    192.168.40.1
IP4.DNS[1]:                     192.168.40.3
TXT
    ;;
  *"device wifi list"*)
    cat <<'TXT'
IN-USE:*
SSID:Linux-Da-Bomb
SIGNAL:84
SECURITY:WPA2
IN-USE:
SSID:Summer0035
SIGNAL:67
SECURITY:WPA2 WPA3
TXT
    ;;
esac
exit 0
EOS

# bluetoothctl: one adapter, one connected device that reports a battery.
cat >"$WORK/bin/bluetoothctl" <<'EOS'
#!/usr/bin/env bash
printf 'bluetoothctl %s\n' "$*" >>"$CALL_LOG"
case "$*" in
  "show")
    cat <<'TXT'
Controller 11:22:33:44:55:66 (public)
	Name: da-bomb
	Alias: da-bomb
	Powered: yes
	Discovering: no
TXT
    ;;
  "devices Connected") printf 'Device AA:11:22:33:44:55 Headphones\n' ;;
  "devices Paired")
    printf 'Device AA:11:22:33:44:55 Headphones\n'
    printf 'Device BB:11:22:33:44:55 Keyboard\n'
    ;;
  "devices")
    printf 'Device AA:11:22:33:44:55 Headphones\n'
    printf 'Device BB:11:22:33:44:55 Keyboard\n'
    printf 'Device CC:11:22:33:44:55 Speaker\n'
    ;;
  "info AA:11:22:33:44:55")
    printf '\tPaired: yes\n\tBattery Percentage: 0x44 (68)\n\tIcon: audio-headphones\n'
    ;;
  "info"*) printf '\tPaired: no\n' ;;
esac
exit 0
EOS

# Present, and every one of them logs: the point of the per-second checks is
# that they are never called, not that they are missing.
cat >"$WORK/bin/docker" <<'EOS'
#!/usr/bin/env bash
printf 'docker %s\n' "$*" >>"$CALL_LOG"
case "$*" in
  logs*) printf 'hello from the container\n' ;;
esac
exit 0
EOS
cat >"$WORK/bin/podman" <<'EOS'
#!/usr/bin/env bash
printf 'podman %s\n' "$*" >>"$CALL_LOG"
exit 0
EOS
cat >"$WORK/bin/tailscale" <<'EOS'
#!/usr/bin/env bash
printf 'tailscale %s\n' "$*" >>"$CALL_LOG"
case "$*" in
  "status --json") printf '{"BackendState":"Running","Peer":{}}\n' ;;
  "status") printf '100.64.0.1 da-bomb user linux active; direct\n' ;;
esac
exit 0
EOS

# A shell that only answers IPC once it has been started, so a cold toggle has
# to launch it and a warm one must not.
cat >"$WORK/bin/quickshell" <<'EOS'
#!/usr/bin/env bash
printf 'quickshell %s\n' "$*" >>"$CALL_LOG"
if [ "${1:-}" = "ipc" ]; then
  [ -e "$WORK/instance" ] && exit 0
  exit 1
fi
: >"$WORK/instance"
exit 0
EOS

# Stays alive long enough for LaunchTerminal.sh to see it running, and logs the
# payload so the container actions can be checked.
cat >"$WORK/bin/kitty" <<'EOS'
#!/usr/bin/env bash
printf 'kitty %s\n' "$*" >>"$CALL_LOG"
sleep 1
exit 0
EOS

# Stands in for the log viewer, so the chain is checked the same way whether
# or not lnav is installed on the host running the tests.
cat >"$WORK/bin/lnav" <<'EOS'
#!/usr/bin/env bash
printf 'lnav %s\n' "$*" >>"$CALL_LOG"
sleep 1
exit 0
EOS

# A stand-in for $EDITOR, the second choice in the viewer chain.
cat >"$WORK/bin/myedit" <<'EOS'
#!/usr/bin/env bash
printf 'myedit %s\n' "$*" >>"$CALL_LOG"
sleep 1
exit 0
EOS

cat >"$WORK/bin/notify-send" <<'EOS'
#!/usr/bin/env bash
printf 'notify-send %s\n' "$*" >>"$CALL_LOG"
exit 0
EOS
chmod +x "$WORK/bin"/*

# Container logs are written under the runtime directory, so keep them in the
# sandbox instead of the live session's directory.
mkdir -p "$WORK/run"
export XDG_RUNTIME_DIR="$WORK/run"

export PATH="$WORK/bin:$PATH"

if [ ! -d "$WIDGET" ]; then
  printf 'the widget is not at %s\n' "$WIDGET" >&2
  exit 1
fi

# ------------------------------------------------------------------ status --
# Waybar's per-second call: the module icon and tooltip, and nothing else.
: >"$CALL_LOG"
status_out="$(bash "$SCRIPT" status)"
printf '%s' "$status_out" >"$WORK/status.json"

assert_json_eq "$WORK/status.json" '.class' "ethernet"

it "status names the wireless link and the connected device in the tooltip"
tooltip="$(jq -r '.tooltip' -- "$WORK/status.json" 2>/dev/null || true)"
if [[ $tooltip == *"Wi-Fi · Linux-Da-Bomb (84%)"* ]] &&
  [[ $tooltip == *"Bluetooth · Headphones 68%"* ]]; then
  pass_msg
else
  fail "the tooltip reads: $tooltip"
fi

it "status leaves the container and tailnet probes alone"
if grep -qE '^(docker|podman|tailscale) ' "$CALL_LOG"; then
  fail "a per-second status ran: $(grep -E '^(docker|podman|tailscale) ' "$CALL_LOG" | tr '\n' ' ')"
else
  pass_msg
fi

# ---------------------------------------------------------------- snapshot --
: >"$CALL_LOG"
snapshot_out="$(bash "$SCRIPT" snapshot)"

it "snapshot still reports the containers and the tailnet"
if grep -q '^docker ps' "$CALL_LOG" && grep -q '^tailscale status' "$CALL_LOG"; then
  pass_msg
else
  fail "the panel snapshot no longer probes them: $(tr '\n' ' ' <"$CALL_LOG")"
fi

it "snapshot says whether each container engine answers"
if grep -q $'^BOXENGINE\tdocker\t1$' <<<"$snapshot_out" &&
  grep -q $'^BOXENGINE\tpodman\t1$' <<<"$snapshot_out"; then
  pass_msg
else
  fail "the engine records are missing"
fi

it "snapshot lists both devices and the connected network"
if grep -q $'^DEV\tens18\tethernet\tconnected\tWired connection 1\t' <<<"$snapshot_out" &&
  grep -q $'^DEV\twlan0\twifi\tconnected\tLinux-Da-Bomb\t' <<<"$snapshot_out" &&
  grep -q $'^WIFI\tLinux-Da-Bomb\t84\tWPA2\t1$' <<<"$snapshot_out"; then
  pass_msg
else
  fail "the device or network records are missing"
fi

it "snapshot carries the device battery and the tailnet state"
if grep -q $'^BTDEV\tAA:11:22:33:44:55\tHeadphones\t1\t1\t68\taudio-headphones$' <<<"$snapshot_out" &&
  grep -q $'^TS-STATE\tRunning$' <<<"$snapshot_out" &&
  grep -q $'^TSPEER\tda-bomb\t' <<<"$snapshot_out"; then
  pass_msg
else
  fail "the bluetooth or tailnet records are missing"
fi

# -------------------------------------------------------- container actions --
: >"$CALL_LOG"
log_dir="$WORK/run/quickshell-network-widget"
rm -rf "$log_dir"
it "container logs are written to a file and opened in lnav"
if bash "$SCRIPT" container docker logs odysseus-ntfy-1 >/dev/null 2>&1 &&
  grep -qF 'docker logs --tail 2000 odysseus-ntfy-1' "$CALL_LOG" &&
  grep -qF "$log_dir/docker-odysseus-ntfy-1.log" "$CALL_LOG" &&
  grep -qF 'lnav ' "$CALL_LOG" &&
  grep -qF 'hello from the container' "$log_dir/docker-odysseus-ntfy-1.log"; then
  pass_msg
else
  fail "logs were not captured and opened: $(tr '\n' ' ' <"$CALL_LOG")"
fi

: >"$CALL_LOG"
# A PATH without lnav, so the editor branch is reached on a host that has it
# installed as well as on one that does not.
mkdir -p "$WORK/nolnav"
ln -sf /usr/bin/* "$WORK/nolnav/" 2>/dev/null
rm -f "$WORK/nolnav/lnav" "$WORK/nolnav/docker" "$WORK/nolnav/kitty" "$WORK/nolnav/myedit"
ln -sf "$WORK/bin/docker" "$WORK/bin/kitty" "$WORK/bin/myedit" "$WORK/bin/notify-send" "$WORK/nolnav/"
it "container logs fall back to \$EDITOR when lnav is missing"
if PATH="$WORK/nolnav" EDITOR=myedit bash "$SCRIPT" container docker logs odysseus-ntfy-1 >/dev/null 2>&1 &&
  grep -qF 'myedit ' "$CALL_LOG"; then
  pass_msg
else
  fail "the editor fallback was not used: $(tr '\n' ' ' <"$CALL_LOG")"
fi

: >"$CALL_LOG"
it "container shell tries bash and falls back to sh in a terminal"
if bash "$SCRIPT" container docker shell odysseus-ntfy-1 >/dev/null 2>&1 &&
  grep -qF 'docker exec -it' "$CALL_LOG" &&
  grep -qF 'odysseus-ntfy-1' "$CALL_LOG" &&
  grep -qF 'exec bash' "$CALL_LOG" &&
  grep -qF 'exec sh' "$CALL_LOG"; then
  pass_msg
else
  fail "shell did not reach a terminal: $(tr '\n' ' ' <"$CALL_LOG")"
fi

: >"$CALL_LOG"
it "container logs live follows the stream through lnav"
if bash "$SCRIPT" container docker logs odysseus-ntfy-1 live >/dev/null 2>&1 &&
  grep -qF -- '--tail 2000 -f' "$CALL_LOG" &&
  grep -qF '| lnav' "$CALL_LOG"; then
  pass_msg
else
  fail "live logs did not follow the stream: $(tr '\n' ' ' <"$CALL_LOG")"
fi

: >"$CALL_LOG"
it "container podman start, stop and restart reach podman"
if bash "$SCRIPT" container podman stop web1 >/dev/null 2>&1 &&
  bash "$SCRIPT" container podman start web1 >/dev/null 2>&1 &&
  bash "$SCRIPT" container podman restart web1 >/dev/null 2>&1 &&
  grep -qF 'podman stop web1' "$CALL_LOG" &&
  grep -qF 'podman start web1' "$CALL_LOG" &&
  grep -qF 'podman restart web1' "$CALL_LOG"; then
  pass_msg
else
  fail "podman actions did not reach it: $(tr '\n' ' ' <"$CALL_LOG")"
fi

: >"$CALL_LOG"
it "container podman logs uses podman and its own capture file"
if bash "$SCRIPT" container podman logs web1 >/dev/null 2>&1 &&
  grep -qF 'podman logs --tail 2000 web1' "$CALL_LOG" &&
  grep -qF "$log_dir/podman-web1.log" "$CALL_LOG"; then
  pass_msg
else
  fail "podman logs went elsewhere: $(tr '\n' ' ' <"$CALL_LOG")"
fi

# ------------------------------------------------------- viewer setting --
: >"$CALL_LOG"
it "the snapshot reports the log viewer preference"
# snapshot is captured first: the suite runs with pipefail, and a probe that
# exits non-zero would fail the pipeline even when the record is there.
snap_text="$(bash "$SCRIPT" snapshot 2>/dev/null || true)"
if printf '%s' "$snap_text" | grep -qF "$(printf 'SETTING\tlogViewer\tlnav')"; then
  pass_msg
else
  fail "no SETTING record in the snapshot"
fi

: >"$CALL_LOG"
it "set-log-viewer editor is honoured for container logs"
bash "$SCRIPT" set-log-viewer editor >/dev/null 2>&1
snap_text="$(bash "$SCRIPT" snapshot 2>/dev/null || true)"
if printf '%s' "$snap_text" | grep -qF "$(printf 'SETTING\tlogViewer\teditor')" &&
  EDITOR=myedit bash "$SCRIPT" container docker logs odysseus-ntfy-1 >/dev/null 2>&1 &&
  grep -qF 'myedit ' "$CALL_LOG" &&
  ! grep -qF 'lnav ' "$CALL_LOG"; then
  pass_msg
else
  fail "the editor preference was ignored: $(tr '\n' ' ' <"$CALL_LOG")"
fi

: >"$CALL_LOG"
it "set-log-viewer rejects an unknown value"
if bash "$SCRIPT" set-log-viewer vim >/dev/null 2>&1; then
  fail "an unknown viewer was accepted"
elif printf '%s' "$(bash "$SCRIPT" snapshot 2>/dev/null || true)" | grep -qF "$(printf 'SETTING\tlogViewer\teditor')"; then
  pass_msg
else
  fail "a rejected value still changed the preference"
fi

: >"$CALL_LOG"
it "a missing editor viewer is reported"
if bash "$SCRIPT" set-log-viewer editor >/dev/null 2>&1 &&
  EDITOR=ghost-editor bash "$SCRIPT" container docker logs odysseus-ntfy-1 >/dev/null 2>&1 &&
  grep -qF 'viewer app not found' "$CALL_LOG"; then
  pass_msg
else
  fail "a missing editor was not reported: $(tr '\n' ' ' <"$CALL_LOG")"
fi

: >"$CALL_LOG"
it "the logs window carries its own class"
if bash "$SCRIPT" set-log-viewer lnav >/dev/null 2>&1 &&
  bash "$SCRIPT" container docker logs odysseus-ntfy-1 >/dev/null 2>&1 &&
  grep -qF -- '--class qs-network-viewer' "$CALL_LOG"; then
  pass_msg
else
  fail "no viewer class in the launch: $(tr '\n' ' ' <"$CALL_LOG")"
fi

# Added here rather than beside the other stubs: earlier checks must see the
# systemctl the host really has, not one that answers for every unit.
cat >"$WORK/bin/systemctl" <<'EOS'
#!/usr/bin/env bash
printf 'systemctl %s\n' "$*" >>"$CALL_LOG"
exit 0
EOS
chmod +x "$WORK/bin/systemctl"

: >"$CALL_LOG"
it "container-engine stops docker through its unit"
if bash "$SCRIPT" container-engine docker off >/dev/null 2>&1 &&
  grep -qF 'systemctl --user stop docker' "$CALL_LOG"; then
  pass_msg
else
  fail "docker was not stopped: $(tr '\n' ' ' <"$CALL_LOG")"
fi

: >"$CALL_LOG"
it "container-engine starts podman through its socket unit"
if bash "$SCRIPT" container-engine podman on >/dev/null 2>&1 &&
  grep -qF 'systemctl --user start podman.socket' "$CALL_LOG"; then
  pass_msg
else
  fail "podman.socket was not started: $(tr '\n' ' ' <"$CALL_LOG")"
fi

# ------------------------------------------------------------------ panel --
rm -f "$WORK/instance"
: >"$CALL_LOG"

it "a cold toggle starts the shell and then opens the panel"
if ! bash "$SCRIPT" toggle >/dev/null 2>&1; then
  fail "toggle failed with no shell running"
elif ! grep -qF "quickshell -p $WIDGET --daemonize" "$CALL_LOG"; then
  fail "the shell was not started: $(tr '\n' ' ' <"$CALL_LOG")"
elif ! grep -qF 'call network-widget ready' "$CALL_LOG"; then
  fail "the readiness probe is not the ready call: $(tr '\n' ' ' <"$CALL_LOG")"
elif ! grep -qF 'call network-widget open' "$CALL_LOG"; then
  fail "the panel was not opened: $(tr '\n' ' ' <"$CALL_LOG")"
else
  pass_msg
fi

: >"$CALL_LOG"
it "a warm toggle drives the running shell over IPC"
if bash "$SCRIPT" toggle >/dev/null 2>&1 &&
  grep -qF 'call network-widget toggle' "$CALL_LOG" &&
  ! grep -qF -- '--daemonize' "$CALL_LOG"; then
  pass_msg
else
  fail "a second shell was started, or no IPC was sent: $(tr '\n' ' ' <"$CALL_LOG")"
fi

: >"$CALL_LOG"
it "close only asks the running shell"
if bash "$SCRIPT" close >/dev/null 2>&1 &&
  grep -qF 'call network-widget close' "$CALL_LOG"; then
  pass_msg
else
  fail "close did not reach the shell: $(tr '\n' ' ' <"$CALL_LOG")"
fi

# -------------------------------------------------------------------- qml --
it "the panel starts hidden"
if grep -qF 'property bool shown: false' "$WIDGET/Panel.qml"; then
  pass_msg
else
  fail "Panel.qml does not start with shown false"
fi

it "the dismissal target is declared before the card"
assert_order "$WIDGET/Panel.qml" 'onClicked: panel.shown = false' 'id: card' && pass_msg

it "the surface collapses to a pixel while the panel is closed"
if grep -qF 'implicitHeight: panel.shown ? 0 : 1' "$WIDGET/Panel.qml" &&
  grep -qF 'anchors.bottom: panel.shown' "$WIDGET/Panel.qml"; then
  pass_msg
else
  fail "the window no longer shrinks to a single pixel"
fi

it "the panel names its layer-shell surface"
if grep -qF 'WlrLayershell.namespace: "quickshell:network-widget"' "$WIDGET/Panel.qml"; then
  pass_msg
else
  fail "no namespace, so hyprctl layers cannot name the surface"
fi

it "the readiness probe is a real IPC call"
if grep -qF 'function ready(): string' "$WIDGET/shell.qml" &&
  grep -qF 'qs_ipc ready' "$SCRIPT"; then
  pass_msg
else
  fail "the shell does not answer ready, or launch_panel does not ask"
fi

# ---------------------------------------------------- tailscale host ssh --
it "tailscale-list-terminals identifies available terminals"
terms_out="$(bash "$SCRIPT" tailscale-list-terminals)"
if [[ -n $terms_out ]]; then
  pass_msg
else
  fail "no terminals returned from tailscale-list-terminals"
fi

it "tailscale-export and tailscale-import work with JSON config"
mkdir -p "$XDG_CONFIG_HOME/hypr/UserConfigs"
exp_file="$WORK/test-export.json"
cat >"$XDG_CONFIG_HOME/hypr/UserConfigs/tailscale-hosts.json" <<'EOF'
{"version":1,"hosts":{"100.64.0.5":{"hostname":"node-a","ip":"100.64.0.5","port":22,"user":"testuser","terminal":"kitty","auth_type":"key","key_path":"~/.ssh/id_ed25519"}}}
EOF
if bash "$SCRIPT" tailscale-export "$exp_file" >/dev/null 2>&1 && [[ -s $exp_file ]]; then
  pass_msg
else
  fail "tailscale-export failed to produce $exp_file"
fi

it "tailscale-import merges imported host config"
imp_src="$WORK/import-src.json"
cat >"$imp_src" <<'EOF'
{"version":1,"hosts":{"100.64.0.9":{"hostname":"node-b","ip":"100.64.0.9","port":2222,"user":"otheruser","terminal":"ghostty","auth_type":"password","key_path":""}}}
EOF
if bash "$SCRIPT" tailscale-import "$imp_src" >/dev/null 2>&1 &&
   grep -q 'node-b' "$XDG_CONFIG_HOME/hypr/UserConfigs/tailscale-hosts.json" &&
   grep -q 'node-a' "$XDG_CONFIG_HOME/hypr/UserConfigs/tailscale-hosts.json"; then
  pass_msg
else
  fail "tailscale-import did not merge host records"
fi

it "tailscale-logs formats text and json"
log_target="$WORK/state/hypr/tailscale-ssh.log"
mkdir -p "$(dirname "$log_target")"
cat >"$log_target" <<'EOF'
[2026-11-14 10:00:00] [INFO] Connection test succeeded for test-host (100.64.0.1:22)
[2026-11-14 10:05:00] [ERROR] Host: test-host (100.64.0.1:22) User: test - Port 22 unreachable
EOF
export XDG_STATE_HOME="$WORK/state"
logs_txt="$(bash "$SCRIPT" tailscale-logs text)"
logs_json="$(bash "$SCRIPT" tailscale-logs json)"
if grep -q 'Port 22 unreachable' <<<"$logs_txt" && jq -e '.[1].level == "ERROR"' <<<"$logs_json" >/dev/null 2>&1; then
  pass_msg
else
  fail "tailscale-logs output did not match expected structure"
fi

it "tailscale-ssh-test logs errors on unreachable port"
if bash "$SCRIPT" tailscale-ssh-test "deadhost" "127.0.0.1" 65432 "testuser" "key" "/dev/null" >/dev/null 2>&1; then
  fail "tailscale-ssh-test succeeded unexpectedly on closed port"
elif grep -q "deadhost" "$log_target"; then
  pass_msg
else
  fail "tailscale-ssh-test did not record error to log"
fi

it "open_auth_url_if_found captures Tailscale authentication link and opens browser"
cat >"$WORK/bin/xdg-open" <<'EOS'
#!/usr/bin/env bash
printf 'xdg-open %s\n' "$*" >>"$CALL_LOG"
exit 0
EOS
chmod +x "$WORK/bin/xdg-open"
fake_auth="To authenticate, visit: https://login.tailscale.com/a/sample12345"
if bash -c ". '$SCRIPT'; open_auth_url_if_found '$fake_auth'" >/dev/null 2>&1 &&
   grep -q 'xdg-open https://login.tailscale.com/a/sample12345' "$CALL_LOG"; then
  pass_msg
else
  fail "did not capture and open auth URL"
fi

if command -v qmllint >/dev/null 2>&1; then
  it "the applet's QML parses"
  if qmllint "$WIDGET"/*.qml >"$WORK/qmllint.log" 2>&1; then
    pass_msg
  else
    fail "$(head -n 3 "$WORK/qmllint.log" | tr '\n' ' ')"
  fi
else
  it "the applet's QML parses"
  printf 'skip: qmllint is not installed\n'
  pass_msg
fi

summary "test-qs-network"

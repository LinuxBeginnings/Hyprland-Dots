#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Tests for Tak0-Layout-Tracker.py (adapted from tak0-layout:
#   https://github.com/tak0dan/QoL-Script-For-Hyprland-By-Tak00/tree/main/layout-tracker).
#   A fake Hyprland stands in for hyprctl, so nothing here touches the session
#   or switches a real layout.
# No `set -e`: the assertion helpers return non-zero on failure.
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib_test.sh
source "$HERE/lib_test.sh"
TRACKER="$HERE/../Tak0-Layout-Tracker.py"
WORK="$(mktemp -d)"; trap 'rm -rf -- "$WORK"' EXIT

if ! command -v python3 >/dev/null 2>&1; then
  printf 'python3 not found, skipping\n'
  summary "test-layout-tracker"
  exit 0
fi

# Runs one scenario against the tracker. $1 is the scenario name; it prints OK
# on success and a reason on failure.
run_py() {
  TRACKER="$TRACKER" WORK="$WORK" python3 -I - "$1" <<'PY'
import importlib.machinery, importlib.util, json, os, sys, time
loader = importlib.machinery.SourceFileLoader("tracker", os.environ["TRACKER"])
spec = importlib.util.spec_from_loader("tracker", loader)
t = importlib.util.module_from_spec(spec); loader.exec_module(t)

class Fake:
    def __init__(s): s.idx = 0; s.codes = ["us", "es", "ua"]; s.nm = ["English (US)", "Spanish", "Ukrainian"]
    def keyboard(s): return s.codes, s.nm[s.idx]
    def switch(s, i): s.idx = i
    def json(s, *a): return [] if a[0] == "clients" else {}

def spend(d, n):
    for _ in range(n):
        d.last_tick -= t.TICK
        d.tick()

def make(name):
    stats = t.Stats(os.path.join(os.environ["WORK"], name + ".json"))
    h = Fake(); d = t.Daemon(h, stats); d.refresh_layouts()
    return h, stats, d

case = sys.argv[1]
if case == "calibrate":
    h, s, d = make(case)
    assert d.names == {"English (US)": "us", "Spanish": "es", "Ukrainian": "ua"}, d.names
    assert h.idx == 0, "calibration must restore the layout"
elif case == "new-window-default":
    h, s, d = make(case)
    d.on_event("openwindow", "aaa,1,kitty,t"); d.on_event("activewindowv2", "aaa")
    d.on_event("activelayout", "kb,Ukrainian"); spend(d, 20)
    d.on_event("openwindow", "bbb,1,kitty,t")
    assert d.win_layout["0xbbb"] == "ua", d.win_layout
elif case == "own-events-ignored":
    h, s, d = make(case)
    d.on_event("openwindow", "aaa,1,kitty,t"); d.on_event("openwindow", "bbb,1,foot,t")
    d.on_event("activewindowv2", "aaa"); d.on_event("activelayout", "kb,Ukrainian")
    d.on_event("activewindowv2", "bbb")            # restores bbb's layout (us)
    d.on_event("activelayout", "kb,English (US)")   # the echo of our own switch
    assert d.win_layout["0xbbb"] == "us" and d.win_layout["0xaaa"] == "ua", d.win_layout
elif case == "per-window-restore":
    h, s, d = make(case)
    d.on_event("openwindow", "aaa,1,kitty,t"); d.on_event("openwindow", "bbb,1,foot,t")
    d.on_event("activewindowv2", "aaa"); d.on_event("activelayout", "kb,Ukrainian")
    d.on_event("activewindowv2", "bbb"); assert h.idx == 0, "bbb keeps its own layout"
    d.on_event("activewindowv2", "aaa"); assert h.idx == 2, "aaa gets ua back"
elif case == "unused-layout-kept":
    h, s, d = make(case)
    d.on_event("openwindow", "aaa,1,kitty,t"); d.on_event("activewindowv2", "aaa")
    d.on_event("activelayout", "kb,Ukrainian"); spend(d, 30)
    s.save(time.time(), {"us", "es"})               # ua is no longer configured
    saved = json.load(open(s.path))
    assert "ua" in saved["global"], saved["global"]
    # only the removed layout has history: no prediction, the daemon uses the first configured one
    assert s.predict("kitty", time.time(), {"us", "es"}) is None
    d.layouts = ["us", "es"]
    assert d.default_for("kitty") == "us"
elif case == "compaction":
    stats = t.Stats(os.path.join(os.environ["WORK"], "compact.json")); now = time.time()
    for i in range(400):
        stats.add_time(f"app{i}", "us", 10, now - 30 * 86400)   # stale and tiny
    stats.add_time("busy", "es", 900, now)
    stats.save(now, {"us", "es"})
    saved = json.load(open(stats.path))
    assert list(saved["apps"]) == ["busy"], list(saved["apps"])[:5]
    assert saved["global"]["us"]["seconds"] == 4000, saved["global"]
else:
    raise SystemExit("unknown case " + case)
print("OK")
PY
}

for c in calibrate new-window-default own-events-ignored per-window-restore unused-layout-kept compaction; do
  it "tracker: $c"
  out="$(run_py "$c" 2>&1)"
  [[ $out == OK ]] && pass_msg || fail "$out"
done

it "wrapper still parses and keeps the listener fallback"
bash -n "$HERE/../Tak0-Per-Window-Switch.sh" \
  && assert_contains "$HERE/../Tak0-Per-Window-Switch.sh" 'subscribe()' \
  && pass_msg || fail "Tak0-Per-Window-Switch.sh is broken"

summary "test-layout-tracker"

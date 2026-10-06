#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Purpose:
#   Pure data model for display layouts: monitor identity, monitor-set
#   fingerprint, the layout store, geometry, resolution and generation.
#
#   This file never touches session state. No hyprctl, no focus, no Waybar.
#   Everything here takes JSON in and prints JSON out, which is what lets the
#   whole model be tested from fixtures with no monitors attached.
#
#   Sourced by DisplayProfile.sh, DisplayProfileMenu.sh and
#   DisplayProfileSetup.sh. Not executable on its own.

DS_JQ="${DS_JQ:-jq}"

ds_log() { printf 'lib_display_store: %s\n' "$*" >&2; }

# --- identity and fingerprint ----------------------------------------------
# ds_normalize <monitors.json>
#   Turns `hyprctl -j monitors all` into the shape the rest of the system uses,
#   sorted by port so every derived value is order-independent.
#
#   Monitor identity is defined HERE and nowhere else. It is make|model|serial,
#   deliberately excluding the port name: that is what lets a monitor moved
#   from one port to another still be recognised. A monitor reporting neither
#   make nor model has no stable identity, so it falls back to its port name
#   and is port-dependent by necessity.
ds_normalize() {
  "$DS_JQ" -c '
    [ .[] | {
        port: .name,
        make: (.make // ""), model: (.model // ""), serial: (.serial // ""),
        identity: (
          if ((.make // "") == "" and (.model // "") == "")
          then .name
          else ((.make // "") + "|" + (.model // "") + "|" + (.serial // ""))
          end
        ),
        description: (.description // ""),
        disabled: (.disabled // false),
        focused: (.focused // false),
        width: (.width // 0), height: (.height // 0),
        refreshRate: (.refreshRate // 0),
        x: (.x // 0), y: (.y // 0),
        scale: (.scale // 1), transform: (.transform // 0),
        modes: [ (.availableModes // [])[] | sub("Hz$"; "") ]
      } ]
    | sort_by(.port)
  ' -- "$1"
}

# ds_fingerprint <normalized.json> -> the key of this monitor set.
#   The sorted identities joined with " + ", used directly as the store's JSON
#   key. Not hashed: a longer key that a human can read beats a short one with
#   a hash implementation that can be wrong.
ds_fingerprint() { "$DS_JQ" -r '[ .[].identity ] | sort | join(" + ")' -- "$1"; }

ds_count() { "$DS_JQ" -r 'length' -- "$1"; }

# --- the store: status, reading, writability -------------------------------
DS_VERSION=1

# ds_store_status <path> -> missing | ok | malformed | future   (always exit 0)
#   Writes are gated on this. A malformed store is never written to, because
#   overwriting it would destroy every layout the user saved.
ds_store_status() {
  local f=$1 v
  [[ -f $f ]] || { printf 'missing\n'; return 0; }
  if ! "$DS_JQ" -e . -- "$f" >/dev/null 2>&1; then printf 'malformed\n'; return 0; fi
  v="$("$DS_JQ" -r '.version // 0' -- "$f" 2>/dev/null || printf '0')"
  if [[ $v =~ ^[0-9]+$ ]] && (( v > DS_VERSION )); then printf 'future\n'; return 0; fi
  printf 'ok\n'
}

# ds_store_read <path> -> the store, or an empty one. Never fails: a missing or
#   unreadable store must leave the system in zero-config mode, not broken.
ds_store_read() {
  local f=$1
  case "$(ds_store_status "$f")" in
    ok | future)
      "$DS_JQ" -c '{ version: (.version // 1), fingerprints: (.fingerprints // {}) }' -- "$f"
      ;;
    *) printf '{"version":%s,"fingerprints":{}}\n' "$DS_VERSION" ;;
  esac
}

ds_store_writable() {
  case "$(ds_store_status "$1")" in ok | missing) return 0 ;; *) return 1 ;; esac
}

# --- names -----------------------------------------------------------------
# Layout names and the monitor-set label are the only free-text inputs in the
# system. A name may look like an option (-n), so every consumer passes it
# after `--`; validation's job is only to keep shell and JSON metacharacters
# out of it.
ds_name_valid() {
  local n=${1-}
  [[ $n =~ ^[A-Za-z0-9\ _.-]{1,32}$ ]]
}

# --- layout validation -----------------------------------------------------
# ds_validate_layout <layout.json> -> 0, or 1 with one line on stderr.
#   Called before anything touches the session, so a hand-edited store cannot
#   black out the screen.
ds_validate_layout() {
  local f=$1 reason
  reason="$("$DS_JQ" -r '
    if type != "object" then "not an object"
    elif (.monitors | type) != "array" then "monitors is not an array"
    elif (.monitors | length) == 0 then "monitors is empty"
    elif ([ .monitors[] | select(.enabled == true) ] | length) == 0
      then "every monitor is disabled"
    elif ([ .monitors[] | select((.identity | type) != "string" or .identity == "") ] | length) > 0
      then "a monitor has no identity"
    elif ([ .monitors[] | select((.scale | tonumber? // 0) <= 0) ] | length) > 0
      then "a monitor has a scale of zero or less"
    elif ([ .monitors[] | select(((.mode // "") | test("^[1-9][0-9]*x[1-9][0-9]*@[0-9]+(\\.[0-9]+)?$")) | not) ] | length) > 0
      then "a monitor mode is not WIDTHxHEIGHT@REFRESH with non-zero dimensions"
    elif ([ .monitors[] | select(has("x") and ((.x | type) != "number")) ] | length) > 0
      then "a monitor x is not a number"
    elif ([ .monitors[] | select(has("y") and ((.y | type) != "number")) ] | length) > 0
      then "a monitor y is not a number"
    elif ([ .monitors[] | select(((.transform // 0) | tonumber? // -1) as $t | $t < 0 or $t > 7) ] | length) > 0
      then "a monitor transform is outside 0-7"
    elif (((.waybar.mode // "all") | IN("all","primary","selected")) | not)
      then "waybar.mode is not all, primary or selected"
    else "" end
  ' -- "$f" 2>/dev/null || printf 'unreadable layout')"
  if [[ -n $reason ]]; then ds_log "invalid layout: $reason"; return 1; fi
  return 0
}

# --- geometry ---------------------------------------------------------------
# ds_logical_size "WxH@R" <scale> [transform] -> "LOGICAL_W LOGICAL_H"
#   The logical size is what Hyprland lays out in, so it is what positions must
#   be computed from. A 90/270 degree transform swaps the two.
ds_logical_size() {
  local mode=$1 scale=$2 transform=${3:-0} wh w h
  wh=${mode%@*}; w=${wh%x*}; h=${wh#*x}
  awk -v w="$w" -v h="$h" -v s="$scale" -v t="$transform" 'BEGIN {
    if (s + 0 <= 0) exit 3
    lw = w / s; lh = h / s
    tm = t % 4
    if (tm == 1 || tm == 3) { tmp = lw; lw = lh; lh = tmp }
    printf "%d %d\n", int(lw + 0.5), int(lh + 0.5)
  }'
}

# ds_apply_grid <layout.json> -> the layout with x/y recomputed from each
#   monitor's grid (row, order within row, vertical alignment).
#
#   The grid is an INPUT METHOD only. x/y are the single source of truth when
#   applying, because drag-and-drop produces arbitrary coordinates that need
#   not sit on any grid. This function is what turns grid input into those
#   coordinates; nothing reads .grid at apply time.
#
#   Only enabled monitors occupy space. The running x within a row accumulates
#   un-rounded and is rounded only when printed, so a column of fractional
#   logical widths cannot drift into an overlap.
#
#   Reads its argument twice: pass a real file, never /dev/stdin.
ds_apply_grid() {
  local layout=$1 rows coords map
  rows="$("$DS_JQ" -r '
    .monitors | to_entries[]
    | select(.value.enabled == true)
    | [ .key,
        (.value.grid.row    // 1),
        (.value.grid.order  // (.key + 1)),
        (.value.grid.valign // "top"),
        .value.mode,
        (.value.scale // 1),
        (.value.transform // 0) ]
    | @tsv' -- "$layout")"

  coords="$(printf '%s\n' "$rows" | awk -F'\t' '
    NF >= 7 {
      n++; idx[n] = $1; row[n] = $2 + 0; ord[n] = $3 + 0; va[n] = $4
      split($5, m, "@"); split(m[1], d, "x")
      s = $6 + 0; tm = ($7 + 0) % 4
      lw = d[1] / s; lh = d[2] / s
      if (tm == 1 || tm == 3) { tmp = lw; lw = lh; lh = tmp }
      w[n] = lw; h[n] = lh
      if (lh > rowh[row[n]]) rowh[row[n]] = lh
      seen[row[n]] = 1
    }
    END {
      nr = 0
      for (r in seen) { nr++; rl[nr] = r + 0 }
      for (i = 1; i <= nr; i++)
        for (j = i + 1; j <= nr; j++)
          if (rl[j] < rl[i]) { t = rl[i]; rl[i] = rl[j]; rl[j] = t }
      ry = 0
      for (i = 1; i <= nr; i++) {
        r = rl[i]; c = 0
        for (k = 1; k <= n; k++) if (row[k] == r) { c++; mem[c] = k }
        for (a = 1; a <= c; a++)
          for (b = a + 1; b <= c; b++)
            if (ord[mem[b]] < ord[mem[a]]) { t = mem[a]; mem[a] = mem[b]; mem[b] = t }
        cx = 0
        for (a = 1; a <= c; a++) {
          k = mem[a]; y = ry
          if (va[k] == "center")      y = ry + (rowh[r] - h[k]) / 2
          else if (va[k] == "bottom") y = ry + rowh[r] - h[k]
          printf "%s\t%d\t%d\n", idx[k], int(cx + 0.5), int(y + 0.5)
          cx += w[k]
        }
        ry += rowh[r]
      }
    }')"

  map="$(printf '%s\n' "$coords" | awk -F'\t' '
    BEGIN { printf "{" }
    NF == 3 { printf "%s\"%s\":[%s,%s]", (c++ ? "," : ""), $1, $2, $3 }
    END { printf "}" }')"

  "$DS_JQ" -c --argjson coords "$map" '
    .monitors = ( .monitors | to_entries | map(
        .value + ( ($coords[.key | tostring]) as $c
                   | if $c then { x: $c[0], y: $c[1] } else {} end )
      ) )
  ' -- "$layout"
}

# --- inheritance, generation, port assignment, resolution -------------------
# ds_inherit <identity> <store.json> <field> -> the value, or empty.
#   When a monitor set has never been saved, generation must not invent a scale
#   the user has already told us about for that exact device. The search order
#   is fixed so the result is reproducible: larger monitor sets first, then by
#   key, and within a fingerprint its default layout before the rest by name.
ds_inherit() {
  local identity=$1 store=$2 field=$3
  ds_store_read "$store" | "$DS_JQ" -r --arg id "$identity" --arg field "$field" '
    [ .fingerprints | to_entries[]
      | { key: .key,
          count: (.key | split(" + ") | length),
          dflt: (.value.default // ""),
          layouts: (.value.layouts // {}) } ]
    | sort_by(-.count, .key)
    | map( . as $fp
           | ( [ $fp.dflt ] + ( $fp.layouts | keys | sort ) )
           # bind the name: inside `$fp.layouts | has(...)` the dot would
           # already be the layouts object, not the name.
           | map(select(. as $n | $n != "" and ($fp.layouts | has($n))))
           | unique_by(.)
           | map(. as $n | $fp.layouts[$n]) )
    | flatten
    | map(.monitors[]? | select(.identity == $id) | .[$field])
    | map(select(. != null))
    | if length > 0 then (.[0] | tostring) else "" end
  '
}

# ds_generate <normalized.json> <store.json> -> a layout for a monitor set that
#   has none saved. Everything on, best mode, one row by port order, and any
#   per-device scale/transform the user has already chosen elsewhere.
#   Never written to the store on its own; the menu offers to save it.
ds_generate() {
  local norm=$1 store=$2 tmp layout ids id sc tr
  tmp="$(mktemp)"
  "$DS_JQ" -c '
    def best_mode:
      if ((.modes // []) | length) > 0
      then ( .modes
             | map( . as $m
                    | ($m | split("@")) as $p
                    | ($p[0] | split("x")) as $d
                    | { mode: $m,
                        area: (($d[0] | tonumber) * ($d[1] | tonumber)),
                        rr: ($p[1] | tonumber) } )
             | sort_by(-.area, -.rr) | .[0].mode )
      elif ((.width // 0) > 0 and (.height // 0) > 0)
      then ( (.width | tostring) + "x" + (.height | tostring) + "@"
             + ((.refreshRate * 100 | round) / 100 | tostring) )
      else "preferred"
      end;
    { monitors: [ to_entries[] | .key as $i | .value |
        { identity, port, enabled: true,
          mode: best_mode, scale: 1, transform: 0, x: 0, y: 0,
          grid: { row: 1, order: ($i + 1), valign: "top" } } ],
      primary: (.[0].identity // ""),
      waybar: { mode: "all", outputs: [] } }
  ' -- "$norm" >"$tmp"

  ids="$("$DS_JQ" -r '.monitors[].identity' -- "$tmp")"
  while IFS= read -r id; do
    [[ -n $id ]] || continue
    sc="$(ds_inherit "$id" "$store" scale)"
    tr="$(ds_inherit "$id" "$store" transform)"
    if [[ $sc =~ ^[0-9.]+$ ]]; then
      "$DS_JQ" -c --arg id "$id" --argjson v "$sc" \
        '.monitors |= map(if .identity == $id then .scale = $v else . end)' -- "$tmp" >"$tmp.n" \
        && mv -f -- "$tmp.n" "$tmp"
    fi
    if [[ $tr =~ ^[0-7]$ ]]; then
      "$DS_JQ" -c --arg id "$id" --argjson v "$tr" \
        '.monitors |= map(if .identity == $id then .transform = $v else . end)' -- "$tmp" >"$tmp.n" \
        && mv -f -- "$tmp.n" "$tmp"
    fi
  done <<<"$ids"

  layout="$(ds_apply_grid "$tmp")"
  rm -f -- "$tmp" "$tmp.n"
  printf '%s\n' "$layout"
}

# ds_assign_ports <layout.json> <normalized.json>
#   Re-points every monitor entry at the port it currently occupies, and drops
#   entries whose device is not connected. Identity first; among devices that
#   share an identity (two identical monitors with no serial), the stored port;
#   failing that, ascending port order so the result is at least deterministic.
ds_assign_ports() {
  local layout=$1 norm=$2
  "$DS_JQ" -c --slurpfile live "$norm" '
    ( $live[0] ) as $live
    | .monitors = (
        ( reduce .monitors[] as $m ( { taken: [], out: [] };
            . as $st
            | ( [ $live[] | select(.identity == $m.identity) | .port ]
                | map(select(. as $p | ($st.taken | index($p)) == null)) ) as $free
            | if ($free | length) == 0 then $st
              elif ($free | index($m.port)) != null
                then { taken: ($st.taken + [$m.port]), out: ($st.out + [$m]) }
              else ( ($free | sort | .[0]) as $p
                     | { taken: ($st.taken + [$p]), out: ($st.out + [$m + { port: $p }]) } )
              end
          ) ).out
      )'  -- "$layout"
}

# ds_layout_names <normalized.json> <store.json> -> this monitor set's layout
#   names, ascending, one per line.
ds_layout_names() {
  local norm=$1 store=$2 fp
  fp="$(ds_fingerprint "$norm")"
  ds_store_read "$store" | "$DS_JQ" -r --arg fp "$fp" \
    '(.fingerprints[$fp].layouts // {}) | keys | sort | .[]'
}

# ds_resolve <normalized.json> <store.json>
#   -> {fingerprint, name, source: stored|generated, layout}
#   Exit 2 when nothing is connected: with no monitors there is no fingerprint
#   to look up and nothing safe to apply, so the caller must stand down.
ds_resolve() {
  local norm=$1 store=$2 fp fpdata name layout source tmp
  [[ "$(ds_count "$norm")" -gt 0 ]] || { ds_log "no monitors connected; nothing to resolve"; return 2; }
  fp="$(ds_fingerprint "$norm")"
  fpdata="$(ds_store_read "$store" | "$DS_JQ" -c --arg fp "$fp" '.fingerprints[$fp] // null')"

  name=""
  if [[ $fpdata != null ]]; then
    name="$(printf '%s' "$fpdata" | "$DS_JQ" -r '
      (.default // "") as $d
      | if ($d != "" and ((.layouts // {}) | has($d))) then $d
        else ((.layouts // {}) | keys | sort | .[0] // "") end')"
  fi

  if [[ -n $name ]]; then
    source=stored
    tmp="$(mktemp)"
    printf '%s' "$fpdata" | "$DS_JQ" -c --arg n "$name" '.layouts[$n]' >"$tmp"
    layout="$(ds_assign_ports "$tmp" "$norm")"
    rm -f -- "$tmp"
  else
    source=generated
    name='(auto)'
    layout="$(ds_generate "$norm" "$store")"
  fi

  "$DS_JQ" -cn --arg fp "$fp" --arg name "$name" --arg source "$source" \
    --argjson layout "$layout" \
    '{ fingerprint: $fp, name: $name, source: $source, layout: $layout }'
}

# --- capture and writes -----------------------------------------------------
# ds_capture <normalized.json> -> a layout describing the live state.
#   This is how an arrangement made by dragging in nwg-displays becomes a saved
#   layout: the coordinates are taken as they are, and the grid metadata is
#   recovered by clustering monitors whose y differs by at most a pixel into
#   rows, so reopening the parameter table shows something sensible.
# best_live_mode: the mode string to record for a monitor as hyprctl reports it.
#   A DISABLED monitor reports width/height/refreshRate as 0 while keeping its
#   availableModes, so the live values cannot be trusted. Recording "0x0@0"
#   would store a mode Hyprland cannot match and a logical width of zero, which
#   lays every such monitor at x=0.
ds__best_live_mode_def='
  def best_live_mode:
    if ((.width // 0) > 0 and (.height // 0) > 0)
    then ((.width | tostring) + "x" + (.height | tostring) + "@"
          + ((((.refreshRate // 0) * 100) | round) / 100 | tostring))
    elif (((.modes // []) | length) > 0)
    then ( .modes
           | map( . as $m
                  | ($m | split("@")) as $p
                  | ($p[0] | split("x")) as $d
                  | { mode: $m,
                      area: (($d[0] | tonumber) * ($d[1] | tonumber)),
                      rr: ($p[1] | tonumber) } )
           | sort_by(-.area, -.rr) | .[0].mode )
    else "preferred" end;
'

ds_capture() {
  "$DS_JQ" -c "$ds__best_live_mode_def"'
    ( [ .[] | select(.disabled != true) ] | sort_by(.y, .x) ) as $on
    | ( reduce $on[] as $m ( { rows: {}, n: 0, prev: null };
          if (.prev == null) or ((($m.y - .prev) | fabs) > 1)
          then { rows: (.rows + { ($m.port): (.n + 1) }), n: (.n + 1), prev: $m.y }
          else { rows: (.rows + { ($m.port): .n }),       n: .n,       prev: .prev }
          end ) ).rows as $rowof
    | ( [ .[] | select(.focused == true) | .identity ] | first ) as $focus
    | ( [ .[] | {
            identity, port,
            enabled: (.disabled != true),
            mode: best_live_mode,
            scale: .scale, transform: (.transform // 0),
            x: .x, y: .y,
            row: ($rowof[.port] // 1)
          } ] ) as $mons
    | { monitors: [ $mons | group_by(.row)[] | sort_by(.x) | to_entries[]
                    | .value + { grid: { row: .value.row,
                                         order: (.key + 1),
                                         valign: "top" } }
                    | del(.row) ],
        primary: ($focus // ($mons[0].identity // "")),
        waybar: { mode: "all", outputs: [] } }
  ' -- "$1"
}

# Atomic write: a temp file in the same directory, validated, then renamed.
# Reads the new store from stdin.
ds__write() {
  local path=$1 tmp
  tmp="$(mktemp -- "$(dirname -- "$path")/.display-layouts.XXXXXX")" || return 1
  if cat >"$tmp" && "$DS_JQ" -e . -- "$tmp" >/dev/null 2>&1; then
    mv -f -- "$tmp" "$path"
    return 0
  fi
  rm -f -- "$tmp"
  ds_log "refusing to write invalid JSON to $path"
  return 1
}

# Writes are gated: a malformed store, or one written by a newer version, is
# never overwritten. Losing every saved layout is worse than refusing a write.
ds__guard() {
  ds_store_writable "$1" && return 0
  ds_log "store is $(ds_store_status "$1"); refusing to write $1"
  return 1
}

ds_store_set() {
  local store=$1 fp=$2 name=$3 layout=$4
  ds__guard "$store" || return 1
  # A layout that cannot be applied has no business in the store.
  ds_validate_layout "$layout" || return 1
  ds_store_read "$store" | "$DS_JQ" -c --arg fp "$fp" --arg n "$name" \
    --slurpfile l "$layout" '
      .fingerprints[$fp] //= { label: "", default: "", layouts: {} }
      | .fingerprints[$fp].layouts[$n] = $l[0]
      | if (.fingerprints[$fp].default // "") == ""
        then .fingerprints[$fp].default = $n else . end
    ' | ds__write "$store"
}

ds_store_default() {
  local store=$1 fp=$2 name=$3
  ds__guard "$store" || return 1
  if ! ds_store_read "$store" | "$DS_JQ" -e --arg fp "$fp" --arg n "$name" \
        '(.fingerprints[$fp].layouts // {}) | has($n)' >/dev/null; then
    ds_log "no layout named $name for this monitor set"
    return 1
  fi
  ds_store_read "$store" | "$DS_JQ" -c --arg fp "$fp" --arg n "$name" \
    '.fingerprints[$fp].default = $n' | ds__write "$store"
}

ds_store_delete() {
  local store=$1 fp=$2 name=$3
  ds__guard "$store" || return 1
  ds_store_read "$store" | "$DS_JQ" -c --arg fp "$fp" --arg n "$name" '
      del(.fingerprints[$fp].layouts[$n])
      | if ((.fingerprints[$fp].layouts // {}) | length) == 0
        then del(.fingerprints[$fp])
        elif (.fingerprints[$fp].default // "") == $n
        then .fingerprints[$fp].default =
               (.fingerprints[$fp].layouts | keys | sort | .[0])
        else . end
    ' | ds__write "$store"
}

ds_store_label() {
  local store=$1 fp=$2 text=$3
  ds__guard "$store" || return 1
  ds_store_read "$store" | "$DS_JQ" -c --arg fp "$fp" --arg t "$text" '
      .fingerprints[$fp] //= { label: "", default: "", layouts: {} }
      | .fingerprints[$fp].label = $t
    ' | ds__write "$store"
}

# Prints the backup path. Used before the menu's Reset, which is the only
# writer allowed to touch a malformed store.
# ds_from_nwg_conf <nwg.conf> <normalized.json> -> a layout built from what
# nwg-displays wrote. nwg on Hyprland only writes this file; it never applies
# anything at runtime, and the Lua fork never reads the file. This bridge is
# what turns a drag-and-drop in nwg into one of our layouts.
#
#   monitor=<name>,<WxH@R>,<XxY>,<scale>[,extras]
#   monitor=<name>,transform,<n>        (separate line)
#   monitor=<name>,disable              (separate line)
#
# <name> is `desc:<hyprctl .description>` (with '#' doubled) or a port name.
ds_from_nwg_conf() {
  local conf=$1 norm=$2 raw
  # Parse the nwg lines into one JSON object per monitor name.
  raw="$(awk -F',' '
    /^[[:space:]]*monitor=/ {
      line = $0; sub(/^[[:space:]]*monitor=/, "", line)
      n = split(line, a, ",")
      name = a[1]; gsub(/##/, "#", name)
      if (a[2] == "transform") { tr[name] = a[3] + 0; next }
      if (a[2] == "disable")   { dis[name] = 1; if (!(name in seen)) { order[++cnt] = name; seen[name] = 1 } next }
      mode[name] = a[2]; pos[name] = a[3]; scale[name] = a[4]
      if (!(name in seen)) { order[++cnt] = name; seen[name] = 1 }
    }
    END {
      printf "["
      for (i = 1; i <= cnt; i++) {
        name = order[i]; np = pos[name]; split(np, p, "x")
        printf "%s{\"name\":%s,\"mode\":%s,\"x\":%d,\"y\":%d,\"scale\":%s,\"transform\":%d,\"enabled\":%s}",
          (i > 1 ? "," : ""),
          json_str(name),
          json_str(mode[name] == "" ? "" : mode[name]),
          (np == "" ? 0 : p[1]) + 0, (np == "" ? 0 : p[2]) + 0,
          (scale[name] == "" ? "1" : scale[name]),
          (name in tr ? tr[name] : 0),
          (name in dis ? "false" : "true")
      }
      printf "]"
    }
    function json_str(x) { gsub(/\\/, "\\\\", x); gsub(/"/, "\\\"", x); return "\"" x "\"" }
  ' "$conf")"

  # Join each parsed entry to a connected monitor, by description (desc:form)
  # or by port name, and emit a layout. A trailing space on a description (as
  # hyprctl sometimes reports) is tolerated by comparing trimmed values.
  [[ -n ${raw//[[:space:]]/} && $raw != "[]" ]] || { ds_log "no monitors parsed from nwg config"; return 1; }
  "$DS_JQ" -cn --slurpfile live "$norm" --argjson raw "$raw" '
    def trim: sub("^\\s+";"") | sub("\\s+$";"");
    ( $live[0] ) as $live
    | ( [ $raw[]
          | . as $e
          | ( if ($e.name | startswith("desc:"))
              then ( ($e.name[5:] | trim) as $d
                     | [ $live[] | select((.description | trim) == $d) ] )
              else [ $live[] | select(.port == $e.name) ]
              end ) as $cands
          | if ($cands | length) == 0 then empty
            else ($cands[0]) as $m
              | ( ($e.scale | tonumber) as $s
                  | if $s == ($s | floor) then ($s | floor) else $s end ) as $scale
              | { identity: $m.identity, port: $m.port,
                  enabled: $e.enabled,
                  mode: $e.mode, scale: $scale,
                  transform: $e.transform, x: $e.x, y: $e.y }
            end ] ) as $mons
    | if ($mons | length) == 0 then error("no monitors parsed from nwg config") else . end
    | ( [ $mons[] | select(.enabled) ] | group_by(.y) | to_entries
        | map( .key as $row | .value | sort_by(.x) | to_entries
               | map( { port: .value.port, row: ($row + 1), order: (.key + 1) } ) )
        | flatten ) as $grid
    | { monitors: [ $mons[]
          | . as $m
          | ( [ $grid[] | select(.port == $m.port) ] | .[0] ) as $g
          | $m + { grid: { row: ($g.row // 1), order: ($g.order // 1), valign: "top" } } ],
        primary: ( ([ $live[] | select(.focused) | .identity ] | .[0])
                   // ($mons[0].identity) ),
        waybar: { mode: "all", outputs: [] } }
  '
}

# Prints the backup path, and fails loudly if the copy did not happen: the one
# caller allowed to overwrite a damaged store must be able to tell.
DS_CP="${DS_CP:-cp}"
ds_store_backup() {
  local store=$1 bak
  bak="$store.bak-$(date +%Y%m%d-%H%M%S)-$$"
  if "$DS_CP" -- "$store" "$bak" 2>/dev/null && [[ -s $bak ]]; then
    printf '%s\n' "$bak"
    return 0
  fi
  ds_log "could not back $store up to $bak"
  return 1
}

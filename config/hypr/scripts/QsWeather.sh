#!/usr/bin/env bash
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
# Weather backend and daemon driver for Quickshell weather applet
# (~/.config/quickshell/weather) and Waybar module (custom/qs-weather).
#
# Features:
#   - Real-time weather polling with Open-Meteo API and wttr.in fallback
#   - Waybar status JSON with condition glyphs, temperatures (C, F, or C/F), and tooltips
#   - Multi-location side-by-side management with single auto-locate enforcement
#   - Forward geocoding search and IP auto-geolocation
#   - Persistent config in ~/.config/hypr/UserConfigs/weather.json (protected by copy.sh)
#   - Quickshell IPC daemon controls (toggle, open, close, refresh)

set -uo pipefail

# Ensure we use bash if invoking subshells
BASH_BIN="${BASH:-$(command -v bash 2>/dev/null || echo "/usr/bin/env bash")}"

show_help() {
  cat << 'EOF'
Usage: QsWeather.sh [COMMAND] [ARGS...]

Commands:
  status                     Emit Waybar JSON (icon, temperature, tooltip, class)
  snapshot                   Emit full structured JSON for Quickshell QML
  toggle | open | close      Show or hide Quickshell weather applet
  isOpen | ready             Query Quickshell applet state
  refresh                    Invalidate cache and fetch fresh weather data
  search <query>             Search geocoding for city, state, country, or coords
  locate                     Auto-locate via IP and print detected location
  add-location <name> <lat> <lon>
                             Add a manual location
  remove-location <id>       Remove a location by ID
  set-active <id>            Set the active location tab
  set-auto-locate <id> <1|0> Toggle auto-locate for a location (only one allowed)
  set-unit <c|f|both>        Set temperature unit display mode
  set-provider <open-meteo|wttr>
                             Set primary weather API provider
  help                       Show this help message
EOF
}

case "${1:-status}" in
  -h|--help|help)
    show_help
    exit 0
    ;;
esac

# Execute embedded Python engine
exec python3 - "$@" << 'PY_EOF'
import sys
import os
import json
import time
import urllib.request
import urllib.parse
from pathlib import Path
from typing import Dict, List, Optional, Any, Tuple

CONFIG_HOME = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
HYPR_DIR = CONFIG_HOME / "hypr"
USER_CONFIGS_DIR = HYPR_DIR / "UserConfigs"
WEATHER_CONFIG_PATH = USER_CONFIGS_DIR / "weather.json"
WEATHER_CACHE_PATH = CACHE_DIR / "qs_weather_cache.json"
CACHE_TTL = 900  # 15 minutes

WIDGET_DIR = CONFIG_HOME / "quickshell" / "weather"
QS_TARGET = "weather"

WMO_MAP = {
    0: ("Clear sky", "sunnyDay", "clearNight"),
    1: ("Mainly clear", "sunnyDay", "clearNight"),
    2: ("Partly cloudy", "cloudyFoggyDay", "cloudyFoggyNight"),
    3: ("Overcast", "cloudy", "cloudy"),
    45: ("Foggy", "fog", "fog"),
    48: ("Rime fog", "fog", "fog"),
    51: ("Light drizzle", "rainyDay", "rainyNight"),
    53: ("Drizzle", "rainyDay", "rainyNight"),
    55: ("Dense drizzle", "rainyDay", "rainyNight"),
    56: ("Freezing drizzle", "snowyIcyDay", "snowyIcyNight"),
    57: ("Freezing drizzle", "snowyIcyDay", "snowyIcyNight"),
    61: ("Slight rain", "rainyDay", "rainyNight"),
    63: ("Moderate rain", "rainyDay", "rainyNight"),
    65: ("Heavy rain", "rainyDay", "rainyNight"),
    66: ("Freezing rain", "snowyIcyDay", "snowyIcyNight"),
    67: ("Heavy freezing rain", "snowyIcyDay", "snowyIcyNight"),
    71: ("Slight snow", "snowyIcyDay", "snowyIcyNight"),
    73: ("Moderate snow", "snowyIcyDay", "snowyIcyNight"),
    75: ("Heavy snow", "snowyIcyDay", "snowyIcyNight"),
    77: ("Snow grains", "snowyIcyDay", "snowyIcyNight"),
    80: ("Rain showers", "rainyDay", "rainyNight"),
    81: ("Moderate showers", "rainyDay", "rainyNight"),
    82: ("Violent rain showers", "rainyDay", "rainyNight"),
    85: ("Snow showers", "snowyIcyDay", "snowyIcyNight"),
    86: ("Heavy snow showers", "snowyIcyDay", "snowyIcyNight"),
    95: ("Thunderstorm", "severe", "severe"),
    96: ("Thunderstorm with hail", "severe", "severe"),
    99: ("Severe thunderstorm", "severe", "severe"),
}

WEATHER_ICONS = {
    "sunnyDay": "󰖙",
    "clearNight": "󰖔",
    "cloudyFoggyDay": "",
    "cloudyFoggyNight": "",
    "cloudy": "",
    "fog": "",
    "rainyDay": "",
    "rainyNight": "",
    "snowyIcyDay": "",
    "snowyIcyNight": "",
    "severe": "",
    "default": "",
}


def c_to_f(c: float) -> float:
    return (c * 9.0 / 5.0) + 32.0


def f_to_c(f: float) -> float:
    return (f - 32.0) * 5.0 / 9.0


def get_icon(wmo_code: int, is_day: bool = True) -> str:
    info = WMO_MAP.get(wmo_code)
    if not info:
        return WEATHER_ICONS["default"]
    tag = info[1] if is_day else info[2]
    return WEATHER_ICONS.get(tag, WEATHER_ICONS["default"])


def get_condition(wmo_code: int) -> str:
    info = WMO_MAP.get(wmo_code)
    return info[0] if info else "Unknown"


def http_get_json(url: str, timeout: int = 6) -> Optional[Dict[str, Any]]:
    req = urllib.request.Request(url, headers={"User-Agent": "KoolDots-Weather/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except Exception:
        return None


def auto_locate_ip() -> Tuple[str, float, float]:
    # Try ip-api first
    data = http_get_json("http://ip-api.com/json/?fields=city,regionName,country,lat,lon", timeout=4)
    if data and "lat" in data and "lon" in data:
        parts = [p for p in [data.get("city"), data.get("regionName"), data.get("country")] if p]
        name = ", ".join(parts) or "Current Location"
        return name, float(data["lat"]), float(data["lon"])

    # Fallback to ipinfo
    data2 = http_get_json("https://ipinfo.io/json", timeout=4)
    if data2 and "loc" in data2:
        try:
            lat_str, lon_str = data2["loc"].split(",")
            parts = [p for p in [data2.get("city"), data2.get("region"), data2.get("country")] if p]
            name = ", ".join(parts) or "Current Location"
            return name, float(lat_str), float(lon_str)
        except Exception:
            pass

    return "Default (New York)", 40.7128, -74.0060


def load_config() -> Dict[str, Any]:
    default_config = {
        "unit": "c",  # "c", "f", or "both"
        "provider": "open-meteo",
        "active_location_id": "loc-1",
        "locations": [
            {
                "id": "loc-1",
                "name": "Auto Location",
                "is_auto": True,
                "lat": None,
                "lon": None,
            }
        ],
    }

    if not WEATHER_CONFIG_PATH.is_file():
        USER_CONFIGS_DIR.mkdir(parents=True, exist_ok=True)
        save_config(default_config)
        return default_config

    try:
        with open(WEATHER_CONFIG_PATH, "r", encoding="utf-8") as f:
            data = json.load(f)
            # Ensure required keys exist
            for k, v in default_config.items():
                if k not in data:
                    data[k] = v
            if not data.get("locations"):
                data["locations"] = default_config["locations"]
            return data
    except Exception:
        return default_config


def save_config(cfg: Dict[str, Any]) -> None:
    try:
        USER_CONFIGS_DIR.mkdir(parents=True, exist_ok=True)
        with open(WEATHER_CONFIG_PATH, "w", encoding="utf-8") as f:
            json.dump(cfg, f, indent=2)
    except Exception as e:
        sys.stderr.write(f"Failed to save weather config: {e}\n")


def load_cache() -> Dict[str, Any]:
    if not WEATHER_CACHE_PATH.is_file():
        return {}
    try:
        with open(WEATHER_CACHE_PATH, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}


def save_cache(cache: Dict[str, Any]) -> None:
    try:
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        with open(WEATHER_CACHE_PATH, "w", encoding="utf-8") as f:
            json.dump(cache, f)
    except Exception:
        pass


def fetch_open_meteo(lat: float, lon: float) -> Optional[Dict[str, Any]]:
    url = (
        f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}"
        "&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m"
        "&hourly=temperature_2m,weather_code,precipitation_probability"
        "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"
        "&timezone=auto&forecast_days=7"
    )
    raw = http_get_json(url)
    if not raw or "current" not in raw:
        return None

    cur = raw["current"]
    hourly = raw.get("hourly", {})
    daily = raw.get("daily", {})

    temp_c = round(float(cur.get("temperature_2m", 0.0)), 1)
    feels_c = round(float(cur.get("apparent_temperature", temp_c)), 1)
    code = int(cur.get("weather_code", 0))
    is_day = bool(cur.get("is_day", 1))

    # Process hourly (next 24 hours)
    hourly_items = []
    times = hourly.get("time", [])
    temps = hourly.get("temperature_2m", [])
    codes = hourly.get("weather_code", [])
    pops = hourly.get("precipitation_probability", [])

    now_ts = time.time()
    for idx, t_str in enumerate(times):
        if len(hourly_items) >= 24:
            break
        # Format "YYYY-MM-DDTHH:MM" -> "HH:MM"
        time_part = t_str.split("T")[-1] if "T" in t_str else t_str
        hc = round(float(temps[idx]), 1) if idx < len(temps) else temp_c
        w_code = int(codes[idx]) if idx < len(codes) else code
        pop_val = int(pops[idx]) if idx < len(pops) else 0
        hourly_items.append({
            "time": time_part,
            "temp_c": round(hc),
            "temp_f": round(c_to_f(hc)),
            "icon": get_icon(w_code, is_day=True),
            "pop": pop_val,
        })

    # Process daily (7 days)
    daily_items = []
    d_times = daily.get("time", [])
    d_max = daily.get("temperature_2m_max", [])
    d_min = daily.get("temperature_2m_min", [])
    d_codes = daily.get("weather_code", [])
    d_pops = daily.get("precipitation_probability_max", [])

    for idx, d_str in enumerate(d_times):
        max_c = round(float(d_max[idx]), 1) if idx < len(d_max) else temp_c
        min_c = round(float(d_min[idx]), 1) if idx < len(d_min) else temp_c
        d_code = int(d_codes[idx]) if idx < len(d_codes) else code
        d_pop = int(d_pops[idx]) if idx < len(d_pops) else 0

        # Day label: Today for day 0
        day_label = "Today" if idx == 0 else time.strftime("%a", time.strptime(d_str, "%Y-%m-%d"))

        daily_items.append({
            "day": day_label,
            "date": d_str,
            "temp_max_c": round(max_c),
            "temp_max_f": round(c_to_f(max_c)),
            "temp_min_c": round(min_c),
            "temp_min_f": round(c_to_f(min_c)),
            "icon": get_icon(d_code, is_day=True),
            "condition": get_condition(d_code),
            "pop": d_pop,
        })

    return {
        "current": {
            "temp_c": round(temp_c),
            "temp_f": round(c_to_f(temp_c)),
            "feels_c": round(feels_c),
            "feels_f": round(c_to_f(feels_c)),
            "condition": get_condition(code),
            "icon": get_icon(code, is_day=is_day),
            "humidity": int(cur.get("relative_humidity_2m", 0)),
            "wind_speed": round(float(cur.get("wind_speed_10m", 0.0))),
            "wind_unit": "km/h",
            "is_day": 1 if is_day else 0,
        },
        "hourly": hourly_items,
        "daily": daily_items,
    }


def fetch_wttr_fallback(lat: float, lon: float) -> Optional[Dict[str, Any]]:
    url = f"https://wttr.in/{lat},{lon}?format=j1"
    raw = http_get_json(url)
    if not raw or "current_condition" not in raw:
        return None

    try:
        cur = raw["current_condition"][0]
        temp_c = float(cur.get("temp_C", 0))
        temp_f = float(cur.get("temp_F", c_to_f(temp_c)))
        feels_c = float(cur.get("FeelsLikeC", temp_c))
        feels_f = float(cur.get("FeelsLikeF", c_to_f(feels_c)))
        desc = cur.get("weatherDesc", [{}])[0].get("value", "Clear")
        humidity = int(cur.get("humidity", 0))
        wind = int(cur.get("windspeedKmph", 0))

        # Basic fallback hourly/daily from wttr.in weather array
        daily_items = []
        hourly_items = []
        for d_idx, day in enumerate(raw.get("weather", [])[:7]):
            max_c = float(day.get("maxtempC", temp_c))
            min_c = float(day.get("mintempC", temp_c))
            d_date = day.get("date", "")
            d_label = "Today" if d_idx == 0 else time.strftime("%a", time.strptime(d_date, "%Y-%m-%d")) if d_date else f"Day {d_idx}"
            daily_items.append({
                "day": d_label,
                "date": d_date,
                "temp_max_c": round(max_c),
                "temp_max_f": round(c_to_f(max_c)),
                "temp_min_c": round(min_c),
                "temp_min_f": round(c_to_f(min_c)),
                "icon": "",
                "condition": desc,
                "pop": 20,
            })
            if d_idx == 0:
                for h in day.get("hourly", []):
                    h_time = str(int(h.get("time", "0")) // 100).zfill(2) + ":00"
                    hc = float(h.get("tempC", temp_c))
                    hourly_items.append({
                        "time": h_time,
                        "temp_c": round(hc),
                        "temp_f": round(c_to_f(hc)),
                        "icon": "",
                        "pop": int(h.get("chanceofrain", 0)),
                    })

        return {
            "current": {
                "temp_c": round(temp_c),
                "temp_f": round(temp_f),
                "feels_c": round(feels_c),
                "feels_f": round(feels_f),
                "condition": desc,
                "icon": "",
                "humidity": humidity,
                "wind_speed": wind,
                "wind_unit": "km/h",
                "is_day": 1,
            },
            "hourly": hourly_items,
            "daily": daily_items,
        }
    except Exception:
        return None


def get_location_weather(loc: Dict[str, Any], cache: Dict[str, Any], force: bool = False) -> Dict[str, Any]:
    loc_id = loc.get("id", "loc-1")
    cached = cache.get(loc_id)
    now = time.time()

    if not force and cached and (now - cached.get("timestamp", 0) < CACHE_TTL):
        return cached["data"]

    lat = loc.get("lat")
    lon = loc.get("lon")

    if loc.get("is_auto") or lat is None or lon is None:
        name, auto_lat, auto_lon = auto_locate_ip()
        lat, lon = auto_lat, auto_lon
        loc["lat"] = lat
        loc["lon"] = lon
        loc["resolved_name"] = name

    # Fetch from Open-Meteo with wttr.in fallback
    data = fetch_open_meteo(lat, lon)
    if not data:
        data = fetch_wttr_fallback(lat, lon)

    if not data:
        # Fallback dummy data if offline
        data = {
            "current": {
                "temp_c": 20,
                "temp_f": 68,
                "feels_c": 20,
                "feels_f": 68,
                "condition": "Offline / Unavailable",
                "icon": "",
                "humidity": 50,
                "wind_speed": 0,
                "wind_unit": "km/h",
                "is_day": 1,
            },
            "hourly": [],
            "daily": [],
        }

    cache[loc_id] = {
        "timestamp": now,
        "data": data,
    }
    save_cache(cache)
    return data


def format_temp_str(temp_c: int, temp_f: int, unit_mode: str) -> str:
    if unit_mode == "f":
        return f"{temp_f}°F"
    elif unit_mode == "both":
        return f"{temp_c}°C / {temp_f}°F"
    else:
        return f"{temp_c}°C"


def cmd_status():
    cfg = load_config()
    cache = load_cache()
    locations = cfg.get("locations", [])
    active_id = cfg.get("active_location_id")
    unit_mode = cfg.get("unit", "c").lower()

    active_loc = None
    for loc in locations:
        if loc.get("id") == active_id:
            active_loc = loc
            break
    if not active_loc and locations:
        active_loc = locations[0]

    if not active_loc:
        print(json.dumps({"text": " --°C", "tooltip": "No weather location configured"}))
        return

    weather = get_location_weather(active_loc, cache)
    cur = weather.get("current", {})
    temp_c = cur.get("temp_c", 0)
    temp_f = cur.get("temp_f", c_to_f(temp_c))
    icon = cur.get("icon", "")
    condition = cur.get("condition", "Weather")
    loc_name = active_loc.get("resolved_name") or active_loc.get("name", "Location")

    temp_text = format_temp_str(temp_c, temp_f, unit_mode)
    waybar_text = f"{icon}  {temp_text}"

    tooltip_lines = [
        f"{loc_name}",
        f"{icon}  {temp_text} - {condition}",
        f"Feels like: {format_temp_str(cur.get('feels_c', temp_c), cur.get('feels_f', temp_f), unit_mode)}",
        f"Humidity: {cur.get('humidity', 0)}%  •  Wind: {cur.get('wind_speed', 0)} {cur.get('wind_unit', 'km/h')}",
    ]

    daily = weather.get("daily", [])
    if daily:
        tooltip_lines.append("")
        tooltip_lines.append("7-Day Forecast:")
        for d in daily[:5]:
            d_temp = format_temp_str(d['temp_max_c'], d['temp_max_f'], unit_mode)
            tooltip_lines.append(f"  {d['day']:<5} {d['icon']}  {d_temp:<12} {d.get('condition', '')}")

    print(json.dumps({
        "text": waybar_text,
        "alt": condition,
        "tooltip": "\n".join(tooltip_lines),
        "class": f"weather {'day' if cur.get('is_day', 1) else 'night'}",
    }, ensure_ascii=False))


def cmd_snapshot():
    cfg = load_config()
    cache = load_cache()
    locations = cfg.get("locations", [])
    unit_mode = cfg.get("unit", "c").lower()

    output_locations = []
    for loc in locations:
        weather = get_location_weather(loc, cache)
        output_locations.append({
            "id": loc.get("id"),
            "name": loc.get("resolved_name") or loc.get("name", "Location"),
            "is_auto": bool(loc.get("is_auto", False)),
            "lat": loc.get("lat"),
            "lon": loc.get("lon"),
            "current": weather.get("current", {}),
            "hourly": weather.get("hourly", []),
            "daily": weather.get("daily", []),
        })

    snapshot_data = {
        "settings": {
            "unit": unit_mode,
            "unit_c": unit_mode in ("c", "both"),
            "unit_f": unit_mode in ("f", "both"),
            "active_location_id": cfg.get("active_location_id"),
            "provider": cfg.get("provider", "open-meteo"),
        },
        "locations": output_locations,
    }
    print(json.dumps(snapshot_data, indent=2, ensure_ascii=False))


def cmd_search(query: str):
    q = query.strip()
    if not q:
        print(json.dumps([]))
        return

    # Check if query is latitude, longitude
    parts = [p.strip() for p in q.split(",")]
    if len(parts) == 2:
        try:
            lat = float(parts[0])
            lon = float(parts[1])
            print(json.dumps([{
                "name": f"Coordinates ({lat:.2f}, {lon:.2f})",
                "lat": lat,
                "lon": lon,
            }], ensure_ascii=False))
            return
        except ValueError:
            pass

    results = []

    # 1. Try Open-Meteo geocoding
    encoded = urllib.parse.quote(q)
    url = f"https://geocoding-api.open-meteo.com/v1/search?name={encoded}&count=5&language=en&format=json"
    raw = http_get_json(url)
    if raw and "results" in raw:
        for r in raw["results"]:
            name = r.get("name", "")
            admin = r.get("admin1", "")
            country = r.get("country", "")
            display_parts = [p for p in [name, admin, country] if p]
            results.append({
                "name": ", ".join(display_parts),
                "lat": float(r.get("latitude", 0)),
                "lon": float(r.get("longitude", 0)),
            })

    # 2. If no results and query has multiple tokens, fall back to OpenStreetMap Nominatim
    if not results:
        url_nom = f"https://nominatim.openstreetmap.org/search?q={encoded}&format=json&limit=5"
        req_nom = urllib.request.Request(url_nom, headers={"User-Agent": "KoolDots-Weather/1.0 (Linux; Hyprland)"})
        try:
            with urllib.request.urlopen(req_nom, timeout=5) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                for r in data:
                    display = r.get("display_name", "")
                    d_parts = [x.strip() for x in display.split(",")]
                    short_name = ", ".join(d_parts[:3]) if len(d_parts) >= 3 else display
                    results.append({
                        "name": short_name,
                        "lat": float(r.get("lat", 0)),
                        "lon": float(r.get("lon", 0)),
                    })
        except Exception:
            pass

    print(json.dumps(results, ensure_ascii=False))


def cmd_locate():
    name, lat, lon = auto_locate_ip()
    print(json.dumps({"name": name, "lat": lat, "lon": lon}))


def cmd_add_location(name: str, lat: float, lon: float):
    cfg = load_config()
    loc_id = f"loc-{int(time.time() * 1000)}"
    cfg.setdefault("locations", []).append({
        "id": loc_id,
        "name": name,
        "is_auto": False,
        "lat": lat,
        "lon": lon,
    })
    cfg["active_location_id"] = loc_id
    save_config(cfg)
    print(json.dumps({"status": "ok", "id": loc_id}))


def cmd_remove_location(loc_id: str):
    cfg = load_config()
    locs = cfg.get("locations", [])
    if len(locs) <= 1:
        print(json.dumps({"status": "error", "message": "Cannot remove the only location"}))
        return

    cfg["locations"] = [l for l in locs if l.get("id") != loc_id]
    if cfg.get("active_location_id") == loc_id:
        cfg["active_location_id"] = cfg["locations"][0].get("id")
    save_config(cfg)
    print(json.dumps({"status": "ok"}))


def cmd_set_auto_locate(loc_id: str, enable: bool):
    cfg = load_config()
    locs = cfg.get("locations", [])
    for l in locs:
        if l.get("id") == loc_id:
            l["is_auto"] = enable
            if enable:
                l["lat"] = None
                l["lon"] = None
        else:
            # Enforce single auto-locate rule: disable on all other locations
            if enable:
                l["is_auto"] = False
    save_config(cfg)
    print(json.dumps({"status": "ok"}))


def cmd_set_unit(unit_mode: str):
    unit_mode = unit_mode.lower().strip()
    if unit_mode not in ("c", "f", "both"):
        unit_mode = "c"
    cfg = load_config()
    cfg["unit"] = unit_mode
    save_config(cfg)
    print(json.dumps({"status": "ok", "unit": unit_mode}))


def cmd_set_active(loc_id: str):
    cfg = load_config()
    cfg["active_location_id"] = loc_id
    save_config(cfg)
    print(json.dumps({"status": "ok", "active": loc_id}))


def qs_ipc(cmd: str) -> bool:
    res = os.system(f'quickshell ipc -p "{WIDGET_DIR}" call "{QS_TARGET}" "{cmd}" >/dev/null 2>&1')
    return res == 0


def launch_panel() -> bool:
    os.system(f'quickshell -p "{WIDGET_DIR}" --daemonize >/dev/null 2>&1')
    for _ in range(50):
        time.sleep(0.1)
        if qs_ipc("ready"):
            return True
    return False


def main():
    args = sys.argv[1:]
    cmd = args[0] if args else "status"

    if cmd == "status":
        cmd_status()
    elif cmd == "snapshot":
        cmd_snapshot()
    elif cmd == "search":
        q = " ".join(args[1:]) if len(args) > 1 else ""
        cmd_search(q)
    elif cmd == "locate":
        cmd_locate()
    elif cmd == "add-location":
        if len(args) >= 4:
            cmd_add_location(args[1], float(args[2]), float(args[3]))
        else:
            print(json.dumps({"status": "error", "message": "Usage: add-location <name> <lat> <lon>"}))
    elif cmd == "remove-location":
        if len(args) >= 2:
            cmd_remove_location(args[1])
    elif cmd == "set-auto-locate":
        if len(args) >= 3:
            enable = args[2].lower() in ("1", "true", "yes", "on")
            cmd_set_auto_locate(args[1], enable)
    elif cmd == "set-unit":
        if len(args) >= 2:
            cmd_set_unit(args[1])
    elif cmd == "set-active":
        if len(args) >= 2:
            cmd_set_active(args[1])
    elif cmd == "refresh":
        if WEATHER_CACHE_PATH.is_file():
            WEATHER_CACHE_PATH.unlink()
        qs_ipc("refresh")
        cmd_status()
    elif cmd == "toggle":
        if qs_ipc("toggle"):
            sys.exit(0)
        if launch_panel() and qs_ipc("open"):
            sys.exit(0)
    elif cmd == "open":
        if qs_ipc("open"):
            sys.exit(0)
        if launch_panel() and qs_ipc("open"):
            sys.exit(0)
    elif cmd == "close":
        qs_ipc("close")
    elif cmd in ("isOpen", "ready"):
        res = qs_ipc(cmd)
        sys.exit(0 if res else 1)
    else:
        sys.stderr.write(f"Unknown command: {cmd}\n")
        sys.exit(1)


if __name__ == "__main__":
    main()
PY_EOF

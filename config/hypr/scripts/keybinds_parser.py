#!/usr/bin/env python3
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
import sys
import re
import os

def normalize_combo(combo):
    return combo.replace(" ", "").replace("\t", "")

def extract_combo(line):
    # Remove comments and whitespace
    line = re.sub(r'\s*#.*$', '', line).strip()
    
    if '=' not in line:
        return None
        
    try:
        rhs = line.split('=', 1)[1]
        parts = [p.strip() for p in rhs.split(',')]
        if len(parts) < 2:
            return None
            
        mods = parts[0]
        key = parts[1]
        return f"{mods},{key}"
    except Exception:
        return None

def parse_files(files):
    # Data structures to match original logic
    binding_map = {}        # combo -> effective line
    source_map = {}         # combo -> source file
    user_bind_map = {}      # combo -> user bind line
    unbound_user = {}       # combo -> True if explicitly unbound in user file
    seen_any_bind = {}      # combo -> True if seen
    default_seen = {}       # combo -> True if default bind exists
    
    # We assume the last file in the list is the user config (UserKeybinds.conf)
    # This matches the bash script logic where user_keybinds_conf is passed last
    if not files:
        return [], []
        
    user_conf_path = files[-1] if len(files) > 1 else None

    for file_path in files:
        if not os.path.exists(file_path):
            continue
            
        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                for line in f:
                    line = line.rstrip('\n')
                    if not line or line.strip().startswith('#'):
                        continue
                        
                    is_bind = re.match(r'^\s*bind[a-z]*\s*=', line)
                    is_unbind = re.match(r'^\s*unbind\s*=', line)
                    
                    if is_bind:
                        combo_raw = extract_combo(line)
                        if not combo_raw:
                            continue
                        combo = normalize_combo(combo_raw)
                        seen_any_bind[combo] = True
                        
                        is_user_file = (file_path == user_conf_path)
                        
                        if not is_user_file:
                            default_seen[combo] = True
                            
                        # prefer user bind, else first seen
                        if combo not in source_map:
                            binding_map[combo] = line
                            source_map[combo] = file_path
                            
                        if is_user_file:
                            user_bind_map[combo] = line
                            binding_map[combo] = line
                            source_map[combo] = file_path
                            
                    elif is_unbind:
                        combo_raw = extract_combo(line)
                        if not combo_raw:
                            continue
                        combo = normalize_combo(combo_raw)
                        
                        if file_path == user_conf_path:
                            unbound_user[combo] = True
                            
                        # If unbind is found, we should remove the bind from our map
                        # so it doesn't show up in the menu.
                        if combo in binding_map:
                            del binding_map[combo]
                        if combo in source_map:
                            del source_map[combo]
                            
        except Exception as e:
            # Silently ignore read errors to mimic bash behavior or log to stderr
            sys.stderr.write(f"Error reading {file_path}: {e}\n")
            continue

    # Build results
    raw_keybinds = []
    missing_unbind_suggestions = []
    
    for combo in seen_any_bind:
        eff_line = binding_map.get(combo)
        src = source_map.get(combo)
        
        if not eff_line:
            continue
            
        raw_keybinds.append(eff_line)
        
        # Check for missing unbind suggestions
        # If user overrides a default but didn't unbind in user file
        if (src == user_conf_path and 
            combo in default_seen and 
            combo not in unbound_user):
            
            # Create suggestion: replace 'bind' with 'unbind'
            suggest = re.sub(r'^\s*bind[a-z]*', 'unbind', eff_line)
            missing_unbind_suggestions.append(suggest)
            
    return raw_keybinds, missing_unbind_suggestions
def _parse_lua_string(value):
    value = value.strip()
    if len(value) < 2:
        return None
    if (value[0] == value[-1]) and value[0] in ("'", '"'):
        quote = value[0]
        body = value[1:-1]
        if quote == '"':
            body = body.replace('\\"', '"')
        else:
            body = body.replace("\\'", "'")
        body = body.replace("\\\\", "\\")
        return body
    return None

def _split_lua_args(arg_text):
    args = []
    current = []
    depth = 0
    in_string = None
    escape = False
    for ch in arg_text:
        if in_string:
            current.append(ch)
            if escape:
                escape = False
            elif ch == '\\':
                escape = True
            elif ch == in_string:
                in_string = None
            continue
        if ch in ("'", '"'):
            in_string = ch
            current.append(ch)
            continue
        if ch in "([{":
            depth += 1
            current.append(ch)
            continue
        if ch in ")]}":
            depth = max(depth - 1, 0)
            current.append(ch)
            continue
        if ch == ',' and depth == 0:
            args.append("".join(current).strip())
            current = []
            continue
        current.append(ch)
    if current:
        args.append("".join(current).strip())
    return args

def _find_lua_calls(text, function_names):
    calls = []
    pattern = re.compile(r'\b(' + "|".join(re.escape(name) for name in function_names) + r')\s*\(')
    pos = 0
    while True:
        match = pattern.search(text, pos)
        if not match:
            break
        fn = match.group(1)
        start = match.end()
        idx = start
        depth = 1
        in_string = None
        escape = False
        while idx < len(text):
            ch = text[idx]
            if in_string:
                if escape:
                    escape = False
                elif ch == '\\':
                    escape = True
                elif ch == in_string:
                    in_string = None
            else:
                if ch in ("'", '"'):
                    in_string = ch
                elif ch == '(':
                    depth += 1
                elif ch == ')':
                    depth -= 1
                    if depth == 0:
                        calls.append((fn, text[start:idx]))
                        pos = idx + 1
                        break
            idx += 1
        else:
            break
    return calls

def _find_lua_block(text, start_idx, open_char="{", close_char="}"):
    depth = 0
    in_string = None
    escape = False
    for idx in range(start_idx, len(text)):
        ch = text[idx]
        if in_string:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == in_string:
                in_string = None
            continue
        if ch in ("'", '"'):
            in_string = ch
            continue
        if ch == open_char:
            depth += 1
        elif ch == close_char:
            depth -= 1
            if depth == 0:
                return text[start_idx + 1:idx], idx + 1
    return None, None

def _extract_lua_bind_calls(text):
    binds = []
    calls = _find_lua_calls(text, ["bind", "bindm", "hl.bind"])
    for fn, args_text in calls:
        args = _split_lua_args(args_text)
        if len(args) < 2:
            continue
        mods = _parse_lua_string(args[0])
        key = _parse_lua_string(args[1])
        if mods is None or key is None:
            continue
        description = None
        desc_match = re.search(r'description\s*=\s*(\"(?:\\.|[^\"])*\"|\'(?:\\.|[^\'])*\')', args_text, re.DOTALL)
        if desc_match:
            description = _parse_lua_string(desc_match.group(1))
        elif fn == "bindm" and len(args) >= 4:
            description = _parse_lua_string(args[3])
        binds.append({
            "mods": mods,
            "key": key,
            "description": description or "",
        })
    return binds

def _extract_lua_bind_tables(text):
    binds = []
    pattern = re.compile(r'\bapp_binds\s*=\s*\{', re.MULTILINE)
    for match in pattern.finditer(text):
        block, end_idx = _find_lua_block(text, match.end() - 1)
        if block is None:
            continue
        idx = 0
        depth = 0
        in_string = None
        escape = False
        entry_start = None
        while idx < len(block):
            ch = block[idx]
            if in_string:
                if escape:
                    escape = False
                elif ch == "\\":
                    escape = True
                elif ch == in_string:
                    in_string = None
                idx += 1
                continue
            if ch in ("'", '"'):
                in_string = ch
                idx += 1
                continue
            if ch == "{":
                depth += 1
                if depth == 1:
                    entry_start = idx + 1
            elif ch == "}":
                if depth == 1 and entry_start is not None:
                    entry_text = block[entry_start:idx]
                    args = _split_lua_args(entry_text)
                    if len(args) >= 4:
                        mods = _parse_lua_string(args[0])
                        key = _parse_lua_string(args[1])
                        description = _parse_lua_string(args[3])
                        if mods is not None and key is not None:
                            binds.append({
                                "mods": mods,
                                "key": key,
                                "description": description or "",
                            })
                    entry_start = None
                depth = max(depth - 1, 0)
            idx += 1
    return binds

def _extract_lua_binds(text):
    binds = []
    binds.extend(_extract_lua_bind_calls(text))
    binds.extend(_extract_lua_bind_tables(text))
    return binds

def _format_lua_binds(binds):
    formatted_lines = []
    for bind in binds:
        mods = bind["mods"].replace("$mainMod", "SUPER")
        mods = re.sub(r'[ \t]+', '+', mods.strip())
        key = bind["key"].strip()
        if mods and key:
            combo_str = f"{mods}+{key}"
        elif key:
            combo_str = key
        else:
            combo_str = mods
        desc = (bind.get("description") or "").strip()
        if desc:
            formatted_lines.append(f"{combo_str} — {desc}")
        else:
            formatted_lines.append(combo_str)
    return formatted_lines

def parse_lua_files(files):
    order = []
    bind_map = {}
    for file_path in files:
        if not os.path.exists(file_path):
            continue
        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                binds = _extract_lua_binds(f.read())
        except Exception as e:
            sys.stderr.write(f"Error reading {file_path}: {e}\n")
            continue
        for bind in binds:
            combo_key = normalize_combo(f"{bind['mods']},{bind['key']}")
            if combo_key in bind_map:
                try:
                    order.remove(combo_key)
                except ValueError:
                    pass
            bind_map[combo_key] = bind
            order.append(combo_key)
    effective_binds = [bind_map[key] for key in order if key in bind_map]
    return _format_lua_binds(effective_binds)

def format_for_rofi(raw_binds):
    formatted_lines = []
    
    for line in raw_binds:
        # line is like "bind = MODS, KEY, DISPATCHER, PARAMS" or "bindd = ..."
        # Parsing logic from awk script:
        
        # 1. Cleaner binder
        match = re.match(r'^\s*(bind[a-z]*)\s*=(.*)', line)
        if not match:
            continue
            
        binder = match.group(1).replace(" ", "").replace("\t", "")
        rhs = match.group(2).strip()
        
        # "bind" ends in d, but doesn't have a description. "bindd" does.
        # Original script logic `index(binder, "d")>0` was likely buggy for "bind".
        # We'll assume strict check for bindd or similar if needed, 
        # but avoiding "bind" having a description is crucial for correct output.
        has_desc = 'd' in binder and binder != 'bind'

        # Split by comma regex (handling spaces)
        parts = [p.strip() for p in rhs.split(',')]
        
        if len(parts) < 2:
            continue
            
        mods = parts[0]
        key = parts[1]
        
        desc = ""
        dispatcher = ""
        params = ""
        
        start_idx = 0
        
        if has_desc:
            desc = parts[2] if len(parts) >= 3 else ""
            dispatcher = parts[3] if len(parts) >= 4 else ""
            start_idx = 4
        else:
            dispatcher = parts[2] if len(parts) >= 3 else ""
            start_idx = 3
            
        # Collect params
        remaining_parts = []
        if start_idx < len(parts):
            for i in range(start_idx, len(parts)):
                if parts[i]:
                    remaining_parts.append(parts[i])
        
        if remaining_parts:
            params = ", ".join(remaining_parts)
            
        # Formatting mods
        mods = mods.replace("$mainMod", "SUPER")
        mods = re.sub(r'[ \t]+', '+', mods)
        
        # Build combo string
        if mods and key:
            combo_str = f"{mods}+{key}"
        elif key:
            combo_str = key
        else:
            combo_str = mods
            
        # Final Print Format
        if has_desc and desc:
            formatted_lines.append(f"{combo_str} — {desc}")
        elif dispatcher:
            if params:
                formatted_lines.append(f"{combo_str} — {dispatcher} {params}")
            else:
                formatted_lines.append(f"{combo_str} — {dispatcher}")
        else:
            formatted_lines.append(combo_str)
            
    return formatted_lines

def main():
    if len(sys.argv) < 2:
        # No files provided
        sys.exit(0)
        
    config_files = sys.argv[1:]
    has_lua = any(path.endswith(".lua") for path in config_files)
    if has_lua:
        formatted = parse_lua_files(config_files)
        if not formatted:
            print("no keybinds found.")
            sys.exit(1)
        for line in formatted:
            print(line)
        return

    binds, suggestions = parse_files(config_files)
    
    if not binds:
        print("no keybinds found.")
        sys.exit(1)
        
    formatted = format_for_rofi(binds)
    
    for line in formatted:
        print(line)
        
    # Handle suggestions (print to stderr or a specific file if needed, 
    # but the original script assigns it to a variable 'msg'.
    # To pass this back to bash, we might need a separate mechanism or just print to a known file.)
    if suggestions:
        import tempfile
        try:
            with tempfile.NamedTemporaryFile(mode='w', delete=False, prefix='hypr-unbind-suggestions-', suffix='.conf') as tf:
                tf.write('\n'.join(suggestions) + '\n')
                # We print a special marker line to stdout that the bash script can capture?
                # Or better, just print to stderr and let the user ignore it, 
                # OR, since the original script specifically puts it in the Rofi message,
                # we can print a special string at the END of stdout or to a side channel.
                
                # Let's decide to print the valid keybinds to stdout (for rofi).
                # And print the suggestion file path to a known location or specific fd if possible.
                # Simplest: Write to a fixed temp file location that the bash script checks.
                with open("/tmp/hypr_keybind_suggestions_file", "w") as sf:
                    sf.write(tf.name)
        except Exception:
            pass

if __name__ == "__main__":
    main()

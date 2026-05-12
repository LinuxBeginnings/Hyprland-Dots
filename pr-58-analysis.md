## Review of PR 58 rofi-calc replacing RofiCalc.sh

- One issues is the supplied theme cannot be used
  - Very light, bright white background black text
  - Needs to follow our theming

  ```
  ### PR #58 is checked out on local test branch pr-58-test.
  ```

Review findings

1. Potential calculator launch failure when rofi is already open (medium)
   • File: config/hypr/configs/Keybinds.conf:77
   • New bind runs rofi directly:
   ◦ rofi -show calc -modi calc ...
   • If another rofi instance is active, this can fail.  
   • Improvement: use either:
   ◦ pkill rofi || true && rofi ... (pattern already used elsewhere), or
   ◦ rofi -replace ...

2. Lua keybind path now points to a deleted script (medium)
   • File: config/hypr/lua/keybinds.lua:129
   • Still references:
   ◦ $HOME/.config/hypr/UserScripts/RofiCalc.sh
   • But PR deletes config/hypr/UserScripts/RofiCalc.sh.
   • Result: Lua keybind path is stale/inconsistent with the new calculator flow.

3. Behavior change to confirm (low / UX)
   • Old script explicitly copied results to clipboard (wl-copy).
   • New rofi-calc flow does not explicitly do that in this repo config.
   • Confirm this is intended UX; if not, add copy behavior.

Additional notes
• PR scope is clean and focused (3 files changed).
• keybinds_parser.py parses updated Keybinds.conf successfully.
• gh pr checks reports no CI checks configured for this PR branch.

If you want, I can prepare a follow-up patch on pr-58-test to fix items 1 and 2 directly.

```

```

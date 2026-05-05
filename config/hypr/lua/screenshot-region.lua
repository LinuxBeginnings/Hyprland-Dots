-- Found on Hyprland discord
-- Possible replacement for screenshot.sh

function screenshot(file_prefix, region)
  local file = "$HOME/Pictures/Screenshots/"
    .. file_prefix
    .. os.date("-%Y-%m-%d_%Hh-%Mm-%Ss_" .. math.random(100000) .. ".png")
  local grim = 'grim -g "' .. region .. '" ' .. file
  local message = " && notify-send Screenshot saved"
  local copy = " && wl-copy < " .. file

  hl.dispatch(hl.dsp.exec_cmd(grim .. message .. copy))
end

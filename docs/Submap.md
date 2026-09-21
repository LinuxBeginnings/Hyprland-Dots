# **Submaps**

Submaps allow you to create a new set of keybinds, separate from the standard bindings. They work in modes (e.g in or out of a submap). You can set up a many submaps as you'd like This makes the customisability of keybindings almost infinite. 

The official documentation in the hyprland wiki can be found [here](https://wiki.hypr.land/configuring/core/binds/submaps/).

## **Kool-dots Submap**

The submap function, available in /hypr/UserConfigs/user_keybings.lua, allows you to set up and execute submaps without the extra set-up (especially because they can be finicky).

The submap function has a few options available:


 submap  
├── auto  
│      ├── release  
│      └── toggle  
├── man  
├── create  
└── define  

#### auto - Automatically sets up the complete submap with the options of toggle or while holding the triggering key. 


```
submap.auto.release(name, keybind, function()

-- your binds here

end)

submap.auto.toggle(name, keybind, function()

-- your binds here

end)
```

#### man - Allows you to use separate binds for entry and exiting your submap.

```
submap.man(name, keybind1, keybind2, function()

-- your binds here

end)
```

#### create - only triggers the creation of the submap 

```
submap.create(name, keybind, function()

hl.define_submap(name)

-- your binds here

bind(keybind, hl.dsp.submap("reset"), {flags}
end)
```

#### define - only outputs the create and define functions

```
submap.define(name, keybind, function() 

-- your binds here

bind(keybind, hl.dsp.submap("reset"), {flags}
end)
```

## Examples

- Note that keybinds do not need to have mod keys, but they can be used.

### Example 1  
This alows you to perform media controls while holding down the middle mouse buttion. 

```
Submap.auto.release("Media", "mouse:274", function()

bind("", "w", exec_cmd("playerctl volume 0.1+"))

bind("", "s", exec_cmd("playerctl volume 0.1-"))

bind("", "a", exec_cmd("playerctl previous"))

bind("", "d", exec_cmd("playerctl next"))

bind("", "e", exec_cmd("playerctl play-pause"))

end)
```

### Example 2
Here is a way to switch into a secondary mode that allows you to insert text macros.
```
submap.auto.toggle("Macros", "CRTL ALT + code:11", function()

bind("SUPER", "E", exec_cmd('ydotool type "e-mail address"'))
bind("SUPER + SHIFT", "E", exec_cmd('ydotool type "e-mail address 2"'))
bind("SUPER", "U", exec_cmd('ydotool type "Username"'))
bind("SUPER + SHIFT", "U", exec_cmd('ydotool type "Username 2"'))

bind("", "1", 
exec_cmd('ydotool type "#include<stdio.h>" -k Return "#include<stdlib.h>" -k Return "int main()" -k Return "{)"'),
{description = "Create std C file"})

end)
```
- Note when using macros to input text use ydotool, as using wtype results in undefined behavior.

### Example 3
Submaps can also be used as a way to launch additional applications not already bound. If you would like to change
the default app launch bindings, you can use unbind to free the default bindings for different uses. 
```
submap.auto.release("App-Shortcuts", "Mod2", function()

bind("", "S", exec_cmd("Steam &"))
bind("", "F", exec_cmd("org.ferdium.Ferdium")) --[[great app btw ;)]]
bind("", "M", exec_cmd("spotify-launcher &"))

end)
```

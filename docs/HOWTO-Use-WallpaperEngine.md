# *Rofi Linux-WallpaperEnigne*
kool-Dots allows you to use Linux wallpaper engine in the Rofi wallpaper selector. All that is needed is to install Linux wallpaper engine from [Almamu](https://github.com/Almamu/linux-wallpaperengine), and then all of your downloaded wallpaper engine wallpapers should be populated in your Rofi wallpaper selector. Once installed, the wallpapers should be populated in the rofi wallpaper selector, with WE_ appended to the wallpaper ID.

**You need to already own wallpaper engine on steam.**

# Install Instructions
## Dependencies (Ubuntu/Debian)
OpenGL 3.3 support  
CMake  
LZ4, Zlib  
SDL2  
FFmpeg  
X11 or Wayland  
Xrandr (for X11)  
GLFW3, GLEW, GLUT, GLM  
MPV  
PulseAudio  
FFTW3

## Arch
Linux-Wallpaperengine is available in the AUR.

```term
yay -S linux-wallpaperengine-git
```

## Build from source
### Git clone
```term
git clone --recurse-submodules https://github.com/Almamu/linux-wallpaperengine.git
cd linux-wallpaperengine
```
### Build
```term
mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE='Release' ..
make
```

# Additional info
GUI applications do exist as listed in the official github repo. I recommend using the application from [jagrat7](https://github.com/jagrat7/linux-wallpaper-engine) as it gives you the ability to check for linux compatability issues. It is also supported by Anufrievroman's [waypaper](https://github.com/anufrievroman/waypaper).
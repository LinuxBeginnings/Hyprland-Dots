# Cómo agregar iconos de aplicaciones a los espacios de trabajo en Waybar (`ModulesWorkspaces`)

[Read in English](./HOWTO-Add-New-Application-Icons-ModulesWorkspaces.md)

En **KoolDots (2026)**, los diseños de Waybar que utilizan el módulo dinámico de espacios de trabajo pueden mostrar iconos específicos por aplicación para cada ventana abierta en cada espacio de trabajo.

Estas reglas de espacios de trabajo y mapeos de iconos se definen en:

```
~/.config/hypr/waybar/ModulesWorkspaces
```
*(En el árbol de fuentes del repositorio: `config/hypr/waybar/ModulesWorkspaces`)*

Esta guía explica cómo funcionan las reglas de reescritura de ventanas (*window-rewrite*) en Waybar, cómo identificar la clase (`class`) y el título (`title`) de una aplicación, cómo agregar nuevos mapeos de iconos y cómo recargar y solucionar problemas en la barra.

---

## 1. Descripción general y arquitectura

### ¿Cómo funciona la reescritura de ventanas (*window-rewrite*)?
El módulo `hyprland/workspaces` de Waybar admite la reescritura dinámica de ventanas mediante reglas con expresiones regulares (regex). En `ModulesWorkspaces`, esto se configura en el bloque `"hyprland/workspaces#rw"`:

```jsonc
"hyprland/workspaces#rw": {
    "format": "{icon} {windows}",
    "format-window-separator": " ",
    "window-rewrite-default": " <span foreground='#ff0000'>✘</span> ",
    "window-rewrite": {
        "class<firefox|org.mozilla.firefox>": " ",
        "class<kitty|konsole|[Aa]lacritty>": " ",
        "title<.*youtube.*>": " "
    }
}
```

- **`format`**: `{icon} {windows}` muestra el número o icono del espacio de trabajo seguido de los iconos de cada ventana abierta en dicho espacio.
- **`window-rewrite-default`**: El icono de respaldo cuando una aplicación no coincide con ninguna regla (en KoolDots se muestra un glifo de terminal con una cruz roja ` ✘`).
- **`window-rewrite`**: Un mapa JSON de selectores regex que apuntan a cadenas con iconos.

### ¿Qué diseños de Waybar admiten esta función?
La mayoría de los diseños estándar y modernos de Waybar en KoolDots incluyen `"hyprland/workspaces#rw"`:
- `TOP-Default`, `BOT-Default`
- `TOP-Default-Laptop`, `TOP-Default-Laptop-glass`
- `TOP-Simple`, `BOT-Simple`
- `TOP-Everforest`, `TOP-Everforest-glass`
- `TOP-&-BOT-SummitSplit` (y variantes `v2`, `v3`, `glass`)
- `TOP-&-Left-NorthWest`, `TOP-&-Right-NorthEast`
- `BOT-&-Left-SouthWest`, `BOT-&-Right-SouthEast`
- `TOP-ddubs-simple-bar`

Puede cambiar a cualquiera de estos diseños utilizando **SUPER + ALT + B** (menú de diseños de Waybar) o desde Configuración rápida (**SUPER + SHIFT + E**).

---

## 2. Cómo encontrar la clase (`class`) y el título (`title`) de una aplicación

Para crear una regla precisa, necesita el identificador de ventana reportado por Hyprland.

### Método A: Inspeccionar la ventana activa (Más rápido)
Abra y enfoque la aplicación deseada, luego ejecute en una terminal:

```bash
hyprctl activewindow
```

Examine los valores `class:` y `title:`. Por ejemplo:
```
class: org.signal.Signal
title: Signal
initialClass: org.signal.Signal
initialTitle: Signal
```

### Método B: Listar todas las ventanas abiertas
Para ver las clases y títulos de todas las ventanas abiertas:

```bash
hyprctl clients -j | jq '.[] | {class: .class, title: .title, workspace: .workspace.name}'
```

> **Consejo:** Coincidir por `class<...>` suele ser más estable que por `title<...>`, ya que los títulos cambian con frecuencia (por ejemplo, pestañas del navegador, nombres de archivos en editores o títulos de documentos). Utilice `title<...>` cuando una aplicación se ejecute dentro de un navegador o tenga una clase genérica.

---

## 3. Elegir un icono

- Utilice glifos de **Nerd Fonts** (Font Awesome, Material Design Icons, Octicons, etc.).
- Puede buscar iconos en [Nerd Fonts Cheat Sheet](https://www.nerdfonts.com/cheat-sheet).
- **Formato:** Incluya siempre un espacio al final del glifo (por ejemplo, `"󰍩 "` o `" "`). Esto evita que los iconos de ventanas adyacentes queden pegados.
- **Color:** Opcionalmente puede usar marcado Pango para colorear iconos, por ejemplo:
  ```jsonc
  "class<brave-browser>": "<span foreground='#ff5722'>🦁</span> "
  ```

---

## 4. Paso a paso: Agregar un nuevo mapeo de icono

### Paso 1: Abrir `ModulesWorkspaces`
Abra el archivo en su editor de texto preferido:

```bash
nano ~/.config/hypr/waybar/ModulesWorkspaces
# o
nvim ~/.config/hypr/waybar/ModulesWorkspaces
```

### Paso 2: Ubicar `"hyprland/workspaces#rw"`
Busque `"hyprland/workspaces#rw"` (alrededor de la línea 169) y localice el bloque `"window-rewrite"`:

```jsonc
"window-rewrite": {
    "title<.*amazon.*>": " ",
    "title<.*reddit.*>": " ",
    ...
```

### Paso 3: Agregar su regla
Inserte su regla dentro de `"window-rewrite"`. Por ejemplo, para agregar **Signal Desktop**:

```jsonc
"class<[Ss]ignal|signal-desktop|org.signal.Signal>": "󰍩 ",
"title<.*Signal.*>": "󰍩 ",
```

> **Regla importante de sintaxis JSON:** Cada línea dentro del bloque `"window-rewrite"` debe terminar con una coma `,`, **excepto** la última entrada antes de la llave de cierre `}`.

### Paso 4: Guardar y recargar Waybar
Recargue Waybar para aplicar los cambios:

- **Atajo de teclado:** Presione **SUPER + ALT + R**
- **Terminal:** Ejecute:
  ```bash
  ~/.config/hypr/scripts/Refresh.sh
  ```

---

## 5. Ejemplos prácticos de selectores

### Múltiples variantes y empaquetados (Nativo, Flatpak, AUR)
Agrupe varias clases mediante la barra vertical de alternancia regex `|`:
```jsonc
"class<[Dd]iscord|discord-canary|[Ww]ebcord|[Vv]esktop|com.discordapp.Discord|dev.vencord.Vesktop>": " ",
"class<[Tt]elegram-desktop|org.telegram.desktop|io.github.tdesktop_x64.TDesktop>": " ",
"class<VSCode|code|code-url-handler|code-oss|codium|VSCodium>": "󰨞 ",
```

### Coincidencia insensible a mayúsculas y minúsculas
Utilice clases de caracteres como `[Ff]` para abarcar variaciones en minúsculas y mayúsculas:
```jsonc
"class<[Ss]potify>": " ",
"class<[Kk]denlive|org.kde.kdenlive>": "🎬 ",
```

### Aplicaciones web y títulos específicos
Cuando varias aplicaciones comparten la clase de un navegador, coincida por el título de la ventana:
```jsonc
"title<.*ChatGPT.*>": "󰚩 ",
"title<.*YouTube.*>": " ",
"title<.*gmail.*>": "󰊫 ",
"title<.*github.*>": " ",
```

### Binarios empaquetados o con prefijos especiales
Algunas aplicaciones contenedorizadas o envueltas tienen prefijos de clase específicos:
```jsonc
"class<virt-manager|\\.virt-manager-wrapped>": " ",
"class<com\\.mitchellh\\.ghostty>": " ",
```

---

## 6. Solución de problemas y consejos

1. **La ventana muestra la cruz roja ` ✘`:**
   - La aplicación no coincide con ninguna regla y se aplica el icono de `window-rewrite-default`.
   - Vuelva a verificar la clase exacta con `hyprctl activewindow`.
   - Asegúrese de escapar correctamente los caracteres especiales de regex si es necesario.

2. **Waybar se bloquea o desaparece tras editar el archivo:**
   - Waybar no pudo analizar el archivo JSON.
   - Compruebe comas faltantes o comas sobrantes al final en `ModulesWorkspaces`.
   - Asegúrese de que todas las comillas `"` y llaves `{ }` estén cerradas correctamente.
   - Ejecute Waybar en una terminal para ver el mensaje de error:
     ```bash
     waybar -c ~/.config/hypr/waybar/config -s ~/.config/hypr/waybar/style.css
     ```

3. **El icono aparece como un rectángulo o cuadro vacío:**
   - La fuente tipográfica instalada no contiene ese glifo específico.
   - Elija un glifo alternativo del conjunto estándar de Nerd Fonts admitido en KoolDots.

4. **Los iconos no se muestran en su barra activa:**
   - Su diseño activo de Waybar podría estar usando otro módulo de espacios de trabajo (como `#roman`, `#pacman`, `#kanji` o `#numbers`).
   - Cambie a un diseño con soporte `#rw` usando **SUPER + ALT + B**, o edite su archivo de configuración activo en `~/.config/hypr/waybar/configs/` para reemplazar `"hyprland/workspaces"` por `"hyprland/workspaces#rw"`.

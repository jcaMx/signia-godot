# Godot Web Export Guide for Signia

This guide outlines the step-by-step procedure for exporting the Godot game project to the Nuxt frontend whenever game assets, scenes, or GDScript logic are updated.

---

## 🚀 Quick Command Line Export (Recommended)

You can perform a fresh Web export directly from the terminal without opening the Godot Editor UI.

### PowerShell Command:
```powershell
& "C:\Users\Acer\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe" --headless --path "c:\Users\Acer\Games\signia" --export-release "Web"
```

> **Note:** The export path is pre-configured in `export_presets.cfg` to automatically build files into:
> `c:\Projects\signia-frontend\public\signia-game\`

---

## 🖥️ Manual Export via Godot Editor UI

If you prefer using the Godot Editor graphical interface:

1. Open **Godot Engine** (v4.6+).
2. Open the project at `c:\Users\Acer\Games\signia`.
3. Go to the top menu: **Project** $\rightarrow$ **Export...**.
4. In the Export window, select the **Web** preset on the left sidebar.
5. Click the **Export Project...** button at the bottom.
6. Verify the destination filename is set to:
   `c:\Projects\signia-frontend\public\signia-game\index.html`
7. Ensure **Export With Debug** is unchecked (or checked if debugging).
8. Click **Save**.

---

## 📦 Exported Files Overview

The export generates the following files in `c:\Projects\signia-frontend\public\signia-game\`:

| File | Purpose |
| :--- | :--- |
| `index.html` | Entry point webpage hosted inside Nuxt iframe |
| `index.js` | Emscripten JavaScript glue for Godot WASM engine |
| `index.wasm` | Compiled WebAssembly Godot engine binary |
| `index.pck` | Game assets, GDScript scripts, and scenes |
| `*.png`, `*.worklet.js` | Audio worklets and icons |

---

## 🧪 Verification & Testing

After exporting:

1. Ensure the Nuxt dev server is running (`npm run dev` in `c:\Projects\signia-frontend`).
2. Test the following URLs in your web browser:
   - **Default / Main Menu**: `http://localhost:3000/signia-game/index.html`
   - **Chapter 1**: `http://localhost:3000/signia-game/index.html?chapter=1`
   - **Chapter 2**: `http://localhost:3000/signia-game/index.html?chapter=2`
   - **Chapter 3**: `http://localhost:3000/signia-game/index.html?chapter=3`

---

## 💡 Important Architecture Rules

- **Single Web Export**: The project relies on a single Web export binary.
- **Dynamic Chapter Launching**: Chapters are launched dynamically via URL query parameters (`?chapter=N`). GDScript's [`LevelManager.gd`](file:///c:/Users/Acer/Games/signia/Scripts/LevelManager.gd) inspects the URL query string using `JavaScriptBridge`.
- **No Manual File Edits**: Do **not** edit `index.html` or `index.js` manually after exporting. All web integration features are handled natively in GDScript.

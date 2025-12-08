<p align="center">
  <img src="https://raw.githubusercontent.com/yourusername/hypr-lens/main/assets/hypr-lens-logo.png" alt="hypr-lens logo" width="200">
</p>

<h1 align="center">hypr-lens</h1>

<p align="center">
  <strong>Screen capture, OCR, and visual search utilities for Hyprland</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#usage">Usage</a> •
  <a href="#configuration">Configuration</a> •
  <a href="#troubleshooting">Troubleshooting</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/license-GPL--3.0-blue.svg" alt="License">
  <img src="https://img.shields.io/badge/Hyprland-0.40%2B-blue" alt="Hyprland">
  <img src="https://img.shields.io/badge/quickshell-0.1.0%2B-green" alt="QuickShell">
  <img src="https://img.shields.io/badge/platform-Linux-lightgrey" alt="Platform">
  <img src="https://img.shields.io/badge/Conventional%20Commits-1.0.0-%23FE5196?logo=conventionalcommits&logoColor=white" alt="Conventional Commits">
</p>

---

A standalone, portable toolkit extracted from [end-4's dotfiles](https://github.com/end-4/dots-hyprland) that provides a polished region selector UI with window detection, screenshot capture, OCR text extraction, Google Lens integration, and screen recording.

<!--
## Screenshots

<p align="center">
  <img src="https://raw.githubusercontent.com/yourusername/hypr-lens/main/assets/screenshot-region.png" alt="Region selector" width="600">
</p>
-->

## Features

| Feature | Description |
|---------|-------------|
| 📸 **Region Screenshot** | Select any region and copy to clipboard |
| 🪟 **Window Detection** | Click on detected windows/layers for quick capture |
| 🔍 **Content Detection** | OpenCV-powered region detection within screenshots |
| 📝 **OCR Text Extraction** | Extract text from selected regions using Tesseract |
| 🔎 **Image Search** | Upload to Google Lens for visual search |
| 🎬 **Screen Recording** | Record selected regions with optional audio |
| 🎨 **Color Picker** | Pick colors from anywhere on screen |

## Prerequisites

### Required

| Tool | Purpose | Install |
|------|---------|---------|
| [quickshell](https://github.com/quickshell-mirror/quickshell) | QML shell runtime | `paru -S quickshell-git` |
| [grim](https://sr.ht/~emersion/grim/) | Screenshot capture | `pacman -S grim` |
| [slurp](https://github.com/emersion/slurp) | Region selection fallback | `pacman -S slurp` |
| wl-copy | Clipboard | `pacman -S wl-clipboard` |
| jq | JSON parsing | `pacman -S jq` |
| notify-send | Notifications | `pacman -S libnotify` |
| magick | Image processing | `pacman -S imagemagick` |

### Optional

| Tool | Purpose | Install |
|------|---------|---------|
| [tesseract](https://github.com/tesseract-ocr/tesseract) | OCR text extraction | `pacman -S tesseract tesseract-data-eng` |
| [swappy](https://github.com/jtheoof/swappy) | Screenshot editing | `pacman -S swappy` |
| [wf-recorder](https://github.com/ammen99/wf-recorder) | Screen recording | `pacman -S wf-recorder` |
| [hyprpicker](https://github.com/hyprwm/hyprpicker) | Color picker | `pacman -S hyprpicker` |
| python3 + opencv | Content detection | Installer sets up venv |
| [matugen](https://github.com/InioX/matugen) | Dynamic theming | `paru -S matugen-bin` |

### Version Requirements

| Component | Minimum | Notes |
|-----------|---------|-------|
| quickshell | 0.1.0+ | Required for GlobalShortcut, IpcHandler |
| Hyprland | 0.40.0+ | Required for `hyprctl clients -j` format |
| ImageMagick | 7.0+ | Uses `magick` command (not legacy `convert`) |
| grim | 1.4+ | Wayland screenshot capture |
| wf-recorder | 0.4+ | Wayland screen recording |

## Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/hypr-lens.git
cd hypr-lens

# Run the installer
./hypr-lens-install.sh

# Or preview first with dry-run
./hypr-lens-install.sh --dry-run
```

### What the Installer Does

| Step | Location |
|------|----------|
| QML modules | `~/.config/quickshell/hypr-lens/` |
| Scripts | `~/.local/share/hypr-lens/scripts/` |
| Python venv | `~/.local/share/hypr-lens/venv/` (optional) |
| Default config | `~/.config/hypr-lens/config.jsonc` |

### Starting hypr-lens

<details>
<summary><strong>Option 1: Integrated (recommended)</strong></summary>

The installer can **automatically integrate** hypr-lens into your existing `shell.qml`:
- Creates a timestamped backup: `shell.qml.hypr-lens-backup.<timestamp>`
- Adds the import and RegionSelector component
- Validates syntax before completing

Or integrate manually by adding to your `~/.config/quickshell/shell.qml`:

```qml
// At the top with your other imports:
import "./hypr-lens/modules/regionSelector"

// Inside your root component (Scope, ShellRoot, etc.):
RegionSelector {}
```

Then restart quickshell:
```bash
killall quickshell; quickshell &
```

</details>

<details>
<summary><strong>Option 2: Standalone</strong></summary>

Add to your Hyprland startup (e.g., `execs.conf`):
```bash
exec-once = qs --path ~/.config/quickshell/hypr-lens &
```

To start immediately:
```bash
qs --path ~/.config/quickshell/hypr-lens &
```

</details>

### Adding Keybinds

Copy the keybinds from `keybinds.example.conf` to your Hyprland config:

```bash
# Example: append to your keybinds file
cat keybinds.example.conf >> ~/.config/hypr/your-keybinds.conf

# Then reload Hyprland
hyprctl reload
```

## Usage

### Default Keybinds

| Keybind | Action |
|---------|--------|
| `Super+Shift+S` | Region screenshot (copy to clipboard) |
| `Super+Shift+A` | Image search (Google Lens) |
| `Super+Shift+X` | OCR text extraction |
| `Super+Shift+R` | Region recording |
| `Super+Shift+Alt+R` | Recording with audio |
| `Super+Shift+C` | Color picker |
| `Print` | Quick fullscreen screenshot |

### Quick Start

1. Press `Super+Shift+S` to open the region selector
2. Detected windows appear with colored borders
3. Click a window to capture it, or drag to select a custom region
4. The screenshot is copied to your clipboard
5. Right-click (if swappy installed) opens the editor

### IPC Commands

Control hypr-lens programmatically via quickshell IPC:

```bash
qs ipc call region screenshot
qs ipc call region search
qs ipc call region ocr
qs ipc call region record
qs ipc call region recordWithSound
```

> For standalone mode, use: `qs --path ~/.config/quickshell/hypr-lens ipc call ...`

See [MANUAL.md](MANUAL.md#ipc-commands) for detailed IPC documentation.

## Configuration

Config file: `~/.config/hypr-lens/config.jsonc`

<details>
<summary><strong>Full Configuration Reference</strong></summary>

```jsonc
{
  // ─── Appearance ─────────────────────────────────────────────
  "appearance": {
    "matugenPath": "",              // Path to matugen.json (empty = default)
    "ripple": {
      "usePrimaryColor": true,      // true = accent color, false = gray
      "colorMixRatio": 0.65,        // 0.0 = bold, 1.0 = invisible
      "solidRadius": 0.45,          // Solid color extent (0.0-1.0)
      "fadeRadius": 0.7             // Fade end point (0.0-1.0)
    }
  },

  // ─── Screenshots ────────────────────────────────────────────
  "screenSnip": {
    "savePath": ""                  // Empty = clipboard only
  },

  // ─── Screen Recording ───────────────────────────────────────
  "screenRecord": {
    "savePath": ""                  // Empty = ~/Videos
  },

  // ─── OCR ────────────────────────────────────────────────────
  "ocr": {
    "useCircleSelection": false     // true = circle, false = rectangle
  },

  // ─── Image Search ───────────────────────────────────────────
  "search": {
    "imageSearch": {
      "imageSearchEngineBaseUrl": "https://lens.google.com/uploadbyurl?url=",
      "useCircleSelection": false
    }
  },

  // ─── Region Selector ────────────────────────────────────────
  "regionSelector": {
    "targetRegions": {
      "windows": true,              // Detect window boundaries
      "layers": false,              // Detect Hyprland layers
      "content": true,              // OpenCV content detection
      "showLabel": false,           // Show labels on regions
      "opacity": 0.3,               // Highlight opacity (0.0-1.0)
      "contentRegionOpacity": 0.8,
      "selectionPadding": 5         // Extra pixels around regions
    },
    "rect": {
      "showAimLines": true          // Show crosshair when drawing
    },
    "circle": {
      "strokeWidth": 6,             // Outline thickness
      "padding": 10                 // Extra space around selection
    }
  }
}
```

</details>

## Theming

hypr-lens supports dynamic theming via [matugen](https://github.com/InioX/matugen), a Material You color generation tool.

### How it works

- hypr-lens watches `~/.config/quickshell/matugen.json` for color changes
- When you change your wallpaper (and matugen regenerates colors), hypr-lens automatically updates
- Without matugen, hypr-lens uses a default blue theme

### Setup

<details>
<summary><strong>Setting up matugen</strong></summary>

If you're using matugen with quickshell (e.g., from dots-hyprland), theming works automatically - hypr-lens reads the same `matugen.json` file.

If you want to set up matugen standalone:

1. Install matugen: `paru -S matugen-bin`
2. Create a template at `~/.config/matugen/templates/quickshell.json`:
   ```json
   {
     "primary": "@{primary}",
     "on_primary": "@{on_primary}",
     "surface": "@{surface}",
     "surface_container": "@{surface_container}"
   }
   ```
3. Configure matugen to output to `~/.config/quickshell/matugen.json`
4. Run `matugen image /path/to/wallpaper.jpg` to generate colors

</details>

## Uninstall

```bash
./hypr-lens-install.sh --uninstall
```

> **Note:** Remember to remove keybinds from your Hyprland config manually.

## Troubleshooting

<details>
<summary><strong>"quickshell: command not found"</strong></summary>

Install quickshell from AUR:
```bash
paru -S quickshell-git
```

</details>

<details>
<summary><strong>Screenshots not copying to clipboard</strong></summary>

Ensure `wl-copy` is installed and working:
```bash
echo test | wl-copy
```

</details>

<details>
<summary><strong>OCR returns empty text</strong></summary>

- Install tesseract language data: `pacman -S tesseract-data-eng`
- For other languages: `pacman -S tesseract-data-<lang>`

</details>

<details>
<summary><strong>Content detection not working</strong></summary>

- Ensure Python venv was set up during install
- Verify with:
  ```bash
  ~/.local/share/hypr-lens/venv/bin/python -c "import cv2; print('OK')"
  ```

</details>

<details>
<summary><strong>Recording not working</strong></summary>

- Install wf-recorder: `pacman -S wf-recorder`
- Check if another recording is active: `pkill wf-recorder`

</details>

## Credits

- UI components from [dots-hyprland](https://github.com/end-4/dots-hyprland) by end-4
- Built on [quickshell](https://github.com/quickshell-mirror/quickshell)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the GPL-3.0 License - see the [LICENSE](LICENSE) file for details.

# hypr-lens Manual

Detailed documentation for hypr-lens features and customization.

## Table of Contents

- [Region Selection Modes](#region-selection-modes)
- [Screenshot Actions](#screenshot-actions)
- [OCR Text Extraction](#ocr-text-extraction)
- [Image Search](#image-search)
- [Screen Recording](#screen-recording)
- [Content Detection](#content-detection)
- [Configuration Reference](#configuration-reference)
- [IPC Commands](#ipc-commands)
- [Customizing Keybinds](#customizing-keybinds)
- [Theming](#theming)

## Region Selection Modes

### Rectangle Selection (Default)

Click and drag to select a rectangular region. Features:

- **Aim lines** - Crosshair guides follow your cursor
- **Dimension display** - Shows width x height as you drag
- **Window snapping** - Detected windows highlight for quick selection

### Circle Selection

Used for image search by default. Draw a freeform circle around content:

- Hold and drag to draw
- Release to capture the bounded area
- Useful for irregular shapes or specific content

Toggle between modes in config:
```json
{
  "search": {
    "imageSearch": {
      "useCircleSelection": true
    }
  }
}
```

## Screenshot Actions

### Copy (Super+Shift+S)

1. Opens region selector overlay
2. Select region or click detected window
3. Captures with `grim`
4. Copies PNG to clipboard with `wl-copy`

**Save to disk**: Set `screenSnip.savePath` in config:
```json
{
  "screenSnip": {
    "savePath": "/home/user/Screenshots"
  }
}
```

### Edit (Right-click)

If swappy is installed, right-clicking in the region selector opens the screenshot in swappy for annotation before copying.

## OCR Text Extraction

### Usage (Super+Shift+X)

1. Select region containing text
2. Captures screenshot
3. Runs tesseract OCR
4. Copies extracted text to clipboard
5. Shows notification with preview

### Language Support

Install additional language packs:
```bash
# List available
pacman -Ss tesseract-data

# Install specific language
pacman -S tesseract-data-jpn  # Japanese
pacman -S tesseract-data-chi-sim  # Simplified Chinese
```

## Image Search

### Usage (Super+Shift+A)

1. Select region (circle mode by default)
2. Captures and uploads to temporary hosting (uguu.se)
3. Opens Google Lens with the image URL
4. Browser opens with visual search results

### How it works

```
Region → grim capture → Upload to uguu.se → Get URL → Open lens.google.com/uploadbyurl?url=...
```

### Custom Search Engine

Modify the base URL in config:
```json
{
  "search": {
    "imageSearch": {
      "imageSearchEngineBaseUrl": "https://lens.google.com/uploadbyurl?url="
    }
  }
}
```

## Screen Recording

### Start Recording (Super+Shift+R)

1. Select region to record
2. Recording starts with wf-recorder
3. Notification confirms recording started

### Stop Recording

Press `Super+Shift+R` again while recording is active.

### Recording with Audio (Super+Shift+Alt+R)

Same as above but captures system audio (monitor source).

### Output Location

Default: `~/Videos/recording_YYYY-MM-DD_HH.MM.SS.mp4`

Custom path in config:
```json
{
  "screenRecord": {
    "savePath": "/path/to/recordings"
  }
}
```

### Manual Recording Control

```bash
# Start recording a region
~/.local/share/hypr-lens/scripts/videos/record.sh --region "100,100 800x600"

# Start with audio
~/.local/share/hypr-lens/scripts/videos/record.sh --region "100,100 800x600" --sound

# Fullscreen recording
~/.local/share/hypr-lens/scripts/videos/record.sh --fullscreen

# Stop any active recording
~/.local/share/hypr-lens/scripts/videos/record.sh
```

## Content Detection

OpenCV-based detection of distinct regions within the screen (buttons, images, text blocks).

### Requirements

- Python 3 with venv
- opencv-python, numpy (installed by installer)

### How it works

1. Takes screenshot of current screen
2. Runs `find_regions.py` with OpenCV
3. Detects contours and bounding boxes
4. Filters overlapping regions
5. Displays as clickable targets in UI

### Enable/Disable

```json
{
  "regionSelector": {
    "targetRegions": {
      "content": true  // false to disable
    }
  }
}
```

## Configuration Reference

Full config schema (`~/.config/hypr-lens/config.json`):

```json
{
  "screenSnip": {
    "savePath": ""           // Path to save screenshots, empty = clipboard only
  },
  "screenRecord": {
    "savePath": ""           // Path to save recordings, empty = ~/Videos
  },
  "search": {
    "imageSearch": {
      "imageSearchEngineBaseUrl": "https://lens.google.com/uploadbyurl?url=",
      "useCircleSelection": false    // true = circle mode for image search
    }
  },
  "regionSelector": {
    "targetRegions": {
      "windows": true,       // Highlight detected windows
      "layers": false,       // Highlight layer surfaces (panels, etc)
      "content": true,       // OpenCV content detection
      "showLabel": false,    // Show window class names
      "opacity": 0.3,        // Highlight overlay opacity
      "contentRegionOpacity": 0.8,  // Content detection opacity
      "selectionPadding": 5  // Padding when clicking targets
    },
    "rect": {
      "showAimLines": true   // Crosshair cursor guides
    },
    "circle": {
      "strokeWidth": 6,      // Circle selection line thickness
      "padding": 10          // Extra padding around circle bounds
    }
  }
}
```

## IPC Commands

Control hypr-lens programmatically via quickshell IPC:

```bash
# Region screenshot
qs --path ~/.config/quickshell/hypr-lens ipc call region screenshot

# Image search
qs --path ~/.config/quickshell/hypr-lens ipc call region search

# OCR
qs --path ~/.config/quickshell/hypr-lens ipc call region ocr

# Recording
qs --path ~/.config/quickshell/hypr-lens ipc call region record
qs --path ~/.config/quickshell/hypr-lens ipc call region recordWithSound
```

**Note:** hypr-lens must be running for IPC commands to work.

## Customizing Keybinds

The example keybinds use GlobalShortcuts. Modify in your Hyprland config:

```bash
# Change screenshot to Super+Print
bind = Super, Print, global, quickshell:regionScreenshot

# Use different modifier
bind = Alt+Shift, S, global, quickshell:regionScreenshot

# Disable a keybind (remove or comment the line)
# bind = Super+Shift, X, global, quickshell:regionOcr
```

### Available GlobalShortcut Names

| Name | Action |
|------|--------|
| `regionScreenshot` | Region screenshot |
| `regionSearch` | Image search |
| `regionOcr` | OCR text extraction |
| `regionRecord` | Start/stop recording |
| `regionRecordWithSound` | Recording with audio |

## Theming

hypr-lens uses Material Design 3 colors defined in `Appearance.qml`. The default theme is a dark neutral palette.

### Customizing Colors

Edit `~/.config/quickshell/hypr-lens/modules/common/Appearance.qml`:

```qml
m3colors: QtObject {
    property bool darkmode: true
    property color m3primary: "#your-color"
    property color m3secondary: "#your-color"
    // ... etc
}
```

### Integration with System Theme

For automatic theming based on wallpaper (like dots-hyprland), you would need to implement the full MaterialThemeLoader system, which is beyond the scope of this minimal extraction.

## Architecture

```
~/.config/quickshell/hypr-lens/
├── shell.qml                 # Entry point
├── GlobalStates.qml          # State management
├── modules/
│   ├── common/               # Shared utilities
│   │   ├── Appearance.qml    # Theme/colors
│   │   ├── Config.qml        # Configuration
│   │   ├── Directories.qml   # Paths
│   │   ├── functions/        # Utility functions
│   │   └── widgets/          # UI components
│   └── regionSelector/       # Main feature
│       ├── RegionSelector.qml
│       ├── RegionSelection.qml
│       └── ...
└── services/
    ├── HyprlandData.qml      # Window detection
    ├── Translation.qml       # i18n stub
    └── AppSearch.qml         # Icon lookup

~/.local/share/hypr-lens/
├── scripts/
│   ├── videos/record.sh      # Recording script
│   └── images/
│       ├── find_regions.py   # OpenCV detection
│       └── find-regions-venv.sh
└── venv/                     # Python environment
```

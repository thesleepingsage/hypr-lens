# hypr-lens Configuration

Edit `config.json` in this directory to customize hypr-lens behavior.
Changes take effect after restarting quickshell: `killall quickshell; quickshell &`

---

## appearance

Theme and visual settings.

| Setting | Default | Description |
|---------|---------|-------------|
| `matugenPath` | `""` | Path to matugen.json for dynamic theming. Empty uses `~/.config/quickshell/matugen.json` |

### appearance.ripple

Button click ripple effect. Adjust these to change how button clicks look.

| Setting | Default | Range | Description |
|---------|---------|-------|-------------|
| `usePrimaryColor` | `true` | `true`/`false` | `true` = theme accent color, `false` = subtle gray |
| `colorMixRatio` | `0.65` | `0.0` - `1.0` | Lower = more visible. `0.0` = max contrast, `1.0` = invisible |
| `solidRadius` | `0.45` | `0.0` - `1.0` | How far solid color extends before fading |
| `fadeRadius` | `0.7` | `0.0` - `1.0` | Where the fade completes |

**Presets:**
```json
// Punchy & visible
"ripple": { "usePrimaryColor": true, "colorMixRatio": 0.5, "solidRadius": 0.5, "fadeRadius": 0.8 }

// Subtle & elegant
"ripple": { "usePrimaryColor": false, "colorMixRatio": 0.75, "solidRadius": 0.3, "fadeRadius": 0.5 }

// Maximum visibility (for testing)
"ripple": { "usePrimaryColor": true, "colorMixRatio": 0.4, "solidRadius": 0.6, "fadeRadius": 0.9 }
```

---

## screenSnip

Screenshot settings.

| Setting | Default | Description |
|---------|---------|-------------|
| `savePath` | `""` | Where to save screenshots. Empty = `~/Pictures/hypr-lens` |
| `copyAlsoSaves` | `false` | If `true`, Copy mode (left-click) also saves to disk. If `false`, only Edit mode (swappy) saves. |

**Behavior:**
- **Left-click (Copy)**: Copies to clipboard only (unless `copyAlsoSaves` is `true`)
- **Right-click (Edit)**: Opens swappy for annotation, then saves to `savePath`

**Example:** `"/home/user/Pictures/Screenshots"` or `"~/Pictures/Screenshots"`

---

## screenRecord

Screen recording settings.

| Setting | Default | Description |
|---------|---------|-------------|
| `savePath` | `""` | Where to save recordings. Empty = `~/Videos/hypr-lens` |

**Example:** `"/home/user/Videos/Recordings"`

---

## ocr

Text extraction (OCR) settings.

| Setting | Default | Description |
|---------|---------|-------------|
| `useCircleSelection` | `false` | `true` = circular selection tool, `false` = rectangle |

---

## search.imageSearch

Reverse image search settings.

| Setting | Default | Description |
|---------|---------|-------------|
| `imageSearchEngineBaseUrl` | Google Lens URL | Base URL for reverse image search |
| `useCircleSelection` | `false` | `true` = circular selection, `false` = rectangle |

**Alternative search engines:**
```json
// Google Lens (default)
"imageSearchEngineBaseUrl": "https://lens.google.com/uploadbyurl?url="

// TinEye
"imageSearchEngineBaseUrl": "https://tineye.com/search?url="

// Bing Visual Search
"imageSearchEngineBaseUrl": "https://www.bing.com/images/search?view=detailv2&iss=sbi&q=imgurl:"
```

---

## regionSelector

Controls the region selection overlay behavior.

### regionSelector.targetRegions

Auto-detection of clickable regions (windows, content areas).

| Setting | Default | Description |
|---------|---------|-------------|
| `windows` | `true` | Auto-detect window boundaries |
| `layers` | `false` | Detect Hyprland layers (panels, bars) |
| `content` | `true` | Use OpenCV to detect content within windows |
| `showLabel` | `false` | Show labels on detected regions |
| `opacity` | `0.3` | Highlight overlay opacity (0.0-1.0) |
| `contentRegionOpacity` | `0.8` | Opacity for content-detected regions |
| `selectionPadding` | `5` | Extra pixels around detected regions |

### regionSelector.rect

Rectangle selection tool settings.

| Setting | Default | Description |
|---------|---------|-------------|
| `showAimLines` | `true` | Show crosshair lines when drawing |

### regionSelector.circle

Circle selection tool settings.

| Setting | Default | Description |
|---------|---------|-------------|
| `strokeWidth` | `6` | Circle outline thickness |
| `padding` | `10` | Extra space around selection |

---

## Tips

- Empty string `""` for path settings = use default behavior
- Restart quickshell after changes: `killall quickshell; quickshell &`
- Both absolute paths (`/home/user/...`) and tilde paths (`~/...`) are supported

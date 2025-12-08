# Security Analysis

This document explains exactly what the installer script does, demonstrating it is safe to run.

> **Note:** Line numbers referenced in this document are relative to when it was published. Future updates to the installer may shift line positions, so numbers may be inaccurate at a later date. Use the provided `grep` commands to verify current locations.

## TL;DR

| Aspect | Status |
|--------|--------|
| Root/sudo required | **Optional** - only if you choose auto-install packages. Skip and install deps manually if preferred |
| Files modified | `~/.config/` and `~/.local/share/` - user directories only |
| Network access | **None** - no downloads, no telemetry |
| Data collection | **None** - no analytics, no phone-home |
| Reversible | **Yes** - `--uninstall` + automatic backups for shell.qml |

---

## What Gets Modified

The installer only touches files in your user directories:

| Path | Action | Purpose |
|------|--------|---------|
| `~/.config/quickshell/hypr-lens/` | Create | QML modules (UI components) |
| `~/.config/hypr-lens/config.jsonc` | Create | User configuration file |
| `~/.local/share/hypr-lens/scripts/` | Create | Helper scripts (OpenCV, recording) |
| `~/.local/share/hypr-lens/venv/` | Create (optional) | Python venv for content detection |
| `~/.config/quickshell/shell.qml` | Modify (optional) | Integration (with timestamped backup) |

**Nothing outside your user directories is ever touched** (except package installation if you choose).

---

## Script Breakdown: hypr-lens-install.sh

**1030 lines total** — here's what each section does:

| Lines | Section | What It Does |
|-------|---------|--------------|
| 1-7 | Shebang + safety | `set -eu` enables strict error handling |
| 9-59 | Help & args | Parses `--help`, `--dry-run`, `--uninstall`, `--update` |
| 60-200 | Configuration | Defines paths, colors, helper functions (no execution) |
| 201-310 | Dependency handling | Package detection and optional installation |
| 311-430 | Install functions | File copy operations for QML, scripts, config |
| 431-600 | Shell integration | Optional shell.qml modification with backup |
| 601-900 | Main installer | Orchestrates installation with user prompts |
| 901-1030 | Update mode | Quick update path that preserves config |

### Package Installation (Lines 236-265)

This is the **only place sudo is used**, and **only if you choose to auto-install**:

```bash
# Line 237-239 (official packages)
sudo pacman -S --needed --noconfirm "${official[@]}"

# Lines 250-261 (AUR packages via paru/yay)
$helper -S $aur_flags "${aur[@]}"
```

You can **skip this entirely** by:
1. Answering "n" when asked "Install missing packages now?"
2. Installing dependencies manually before running the installer

### File Operations (Lines 346-364, 933-947)

All file operations use safe patterns:

```bash
# Creating directories (user-owned)
mkdir -p "$QML_INSTALL_DIR"              # Line 346
mkdir -p "$SCRIPTS_INSTALL_DIR"          # Line 360
mkdir -p "$CONFIG_DIR"                   # Line 410

# Copying files (no overwrites without asking)
cp -r "$SCRIPT_DIR/quickshell/"* "$QML_INSTALL_DIR/"   # Line 347
cp -r "$SCRIPT_DIR/scripts/"* "$SCRIPTS_INSTALL_DIR/"  # Line 361

# Making scripts executable (your own files only)
chmod +x "$SCRIPTS_INSTALL_DIR/videos/record.sh"       # Line 362
chmod +x "$SCRIPTS_INSTALL_DIR/images/find-regions-venv.sh"  # Line 363
chmod +x "$SCRIPTS_INSTALL_DIR/images/find_regions.py"       # Line 364
```

### Backup Creation (Lines 490-509)

Before modifying shell.qml, a timestamped backup is created:

```bash
# Line 490
local backup_file="${shell_file}.hypr-lens-backup.$(date +%Y%m%d_%H%M%S)"

# Lines 507-509 (atomic backup)
cp "$shell_file" "$temp_file"
mv "$temp_file" "$backup_file"
success "Backup created: $backup_file"
```

### Cleanup Operations (Lines 129, 385)

`rm -rf` is only used for:
- Line 129: Uninstall function (removes hypr-lens directories)
- Line 385: Recreating Python venv (only after user confirms)

Both are scoped to hypr-lens directories only.

---

## Safety Features

| Feature | How It Works | Lines |
|---------|--------------|-------|
| **Dry-run mode** | `--dry-run` previews all changes without executing | 46, 54, 89, 126, 236, 256, 839, 907 |
| **Automatic backups** | Creates `shell.qml.hypr-lens-backup.<timestamp>` | 490, 506-509 |
| **User confirmation** | Every major action requires y/N prompt | 134, 140, 303, 384, 417, 737, 754, 871 |
| **Update mode** | `--update` refreshes files, preserves config, skips prompts | 901-1030 |
| **Fail-fast** | `set -eu` exits immediately on any error | 7 |
| **Dependency validation** | Checks for required tools before proceeding | 276-310 |

---

## What This Script Does NOT Do

- **No hidden network calls** — no curl, wget, or telemetry
- **No data collection** — no analytics or phone-home
- **No system files** — only touches `~/.config/` and `~/.local/share/`
- **No cron jobs** — no scheduled tasks installed
- **No services** — no systemd units or daemons
- **No PATH changes** — doesn't modify your shell PATH
- **No forced sudo** — package installation is optional and prompted

---

## Verify It Yourself

### Before running — preview changes:
```bash
./hypr-lens-install.sh --dry-run
```

### Check for dangerous patterns:
```bash
# Verify sudo is only in package installation (should show ~4 lines)
grep -n "sudo" hypr-lens-install.sh
# Expected: only lines 237, 239, 264 (and they're all pacman-related)

# Verify no hidden network access
grep -n "curl\|wget\|nc \|netcat\|http" hypr-lens-install.sh
# Expected: (nothing)

# Verify all paths are in user directories
grep -n '\$HOME\|~/' hypr-lens-install.sh | grep -v "^#" | head -20
# Expected: all paths are ~/.config/ or ~/.local/share/

# Verify rm -rf is scoped properly
grep -n "rm -rf" hypr-lens-install.sh
# Expected: only lines 129 (uninstall) and 385 (venv recreate)
```

### After running — check what was installed:
```bash
# See installed locations
ls -la ~/.config/quickshell/hypr-lens/
ls -la ~/.local/share/hypr-lens/
ls -la ~/.config/hypr-lens/

# Check for backup if shell.qml was modified
ls -la ~/.config/quickshell/shell.qml.hypr-lens-backup.*
```

### Full uninstall:
```bash
./hypr-lens-install.sh --uninstall
```

---

## Questions?

If you find any security concerns, please open an issue. This script is intentionally transparent and auditable.

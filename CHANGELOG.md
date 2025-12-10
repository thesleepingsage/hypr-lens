# Changelog

All notable changes to hypr-lens are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).

## [Unreleased]

## 1.0.0 - 2025-12-08

Initial public release! 🎉

### Added

- **Core QML Region Selector** - Polished region selection UI with window detection, custom region drawing, and visual feedback
- **Screenshot Capture** - Region, window, and fullscreen screenshot support with clipboard integration
- **OCR Text Extraction** - Tesseract-powered text extraction from selected screen regions
- **Google Lens Integration** - Quick image search workflow via clipboard + browser
- **Screen Recording** - Region-based screen recording with optional audio capture using wf-recorder
- **Color Picker** - Screen-wide color picking via hyprpicker integration
- **OpenCV Content Detection** - Intelligent region detection within screenshots using Python + OpenCV
- **Window/Layer Detection** - Automatic detection of Hyprland windows and layers for quick capture
- **Installer Script** - Interactive installer with dependency detection, automatic setup, and shell integration
- **Example Keybinds** - Pre-configured Hyprland keybinds for all features
- **Default Configuration** - JSONC config with sensible defaults for all options
- **Matugen Theming Support** - Dynamic Material You theming via matugen integration
- **IPC Interface** - Programmatic control via quickshell IPC commands
- **Project Documentation** - README, MANUAL, SECURITY audit, and wiki

### Features in Detail

| Feature | Keybind |
|---------|---------|
| Region Screenshot | `Super+Shift+S` |
| Image Search | `Super+Shift+A` |
| OCR Extraction | `Super+Shift+X` |
| Screen Recording | `Super+Shift+R` |
| Recording + Audio | `Super+Shift+Alt+R` |
| Color Picker | `Super+Shift+C` |
| Quick Fullscreen | `Print` |

## 1.1.0 - 2025-12-08

### Added

- **One-Click Monitor Capture** - Quick capture buttons for each monitor in the region selector UI

### Changed

- **Region Selector Refactor** - Extracted utilities and reduced code duplication for better maintainability

### Fixed

- **Installer Recovery** - Detect and recover missing shell integration during update mode
- **Invalid Input Handling** - Improved input validation in integration recovery flow

## 1.2.0 - 2025-12-08

### Added

- **Demo Videos** - Video demonstrations of screenshot, OCR, and screen recording features
- **Security Documentation** - Comprehensive SECURITY.md transparency document with line-by-line audit

### Fixed

- **Video Compatibility** - Re-encoded demo videos to H.264 for GitHub compatibility

---

## Version History Summary

| Version | Date | Highlights |
|---------|------|------------|
| 1.2.0 | 2025-12-08 | Demo videos, security documentation |
| 1.1.0 | 2025-12-08 | Monitor capture buttons, installer recovery |
| 1.0.0 | 2025-12-08 | Initial release |
[1.0.0]: https://github.com/thesleepingsage/hypr-lens/releases/tag/v1.0.0

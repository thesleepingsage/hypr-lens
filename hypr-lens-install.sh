#!/bin/bash
# hypr-lens Installer
# Screen capture, OCR, and visual search utilities for Hyprland
#
# Usage: ./hypr-lens-install.sh [OPTIONS]

set -eu

# ==============================================================================
# Help
# ==============================================================================

show_help() {
    cat << 'EOF'
hypr-lens - Screen Capture & Visual Search for Hyprland

Usage: ./hypr-lens-install.sh [OPTIONS]

Options:
  -n, --dry-run    Preview changes without modifying files
  -h, --help       Show this help message
  -u, --uninstall  Remove all installed components
  -d, --update     Quick update: refresh files, skip prompts for existing setup

Components installed:
  1. QML modules     → ~/.config/quickshell/hypr-lens/
  2. Scripts         → ~/.local/share/hypr-lens/scripts/
  3. Python venv     → ~/.local/share/hypr-lens/venv/
  4. Default config  → ~/.config/hypr-lens/config.jsonc

Generated (you copy manually):
  - keybinds.example.conf  → Copy contents to your Hyprland keybinds config

Requirements:
  Required: quickshell, grim, slurp, wl-copy, hyprctl, notify-send, jq
  Optional: tesseract, swappy, wf-recorder, hyprpicker, python3, opencv, matugen
EOF
    exit 0
}

# ==============================================================================
# Configuration
# ==============================================================================

# Modes
DRY_RUN=false
UNINSTALL=false
UPDATE_MODE=false

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        -h|--help)      show_help ;;
        -n|--dry-run)   DRY_RUN=true ;;
        -u|--uninstall) UNINSTALL=true ;;
        -d|--update)    UPDATE_MODE=true ;;
        *) echo "Unknown option: $arg"; echo "Use --help for usage."; exit 1 ;;
    esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Get script directory (where hypr-lens repo is)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Installation paths
QML_INSTALL_DIR="$HOME/.config/quickshell/hypr-lens"
SCRIPTS_INSTALL_DIR="$HOME/.local/share/hypr-lens/scripts"
VENV_DIR="$HOME/.local/share/hypr-lens/venv"
CONFIG_DIR="$HOME/.config/hypr-lens"

# ==============================================================================
# Helper Functions
# ==============================================================================

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }

dry_run_prefix() {
    if $DRY_RUN; then
        echo -e "${CYAN}[DRY-RUN]${NC} "
    fi
}

# Print preview messages in dry-run mode and return success (for early return)
# Returns 1 if not in dry-run mode (continue with real operation)
# Usage: if dry_run_preview "msg1" "msg2"; then return; fi
dry_run_preview() {
    $DRY_RUN || return 1
    for msg in "$@"; do
        echo "$(dry_run_prefix)$msg"
    done
    return 0
}

# Remove directory if it exists, with optional user prompt
# Usage: remove_if_exists "path" "description" [--prompt "message"]
remove_if_exists() {
    local path="$1"
    local description="$2"
    local prompt_msg=""

    # Parse optional --prompt flag
    if [[ "${3:-}" == "--prompt" ]]; then
        prompt_msg="${4:-}"
    fi

    # Skip if directory doesn't exist
    [[ -d "$path" ]] || return 0

    # If prompt specified, ask user first
    if [[ -n "$prompt_msg" ]]; then
        ask "$prompt_msg" || return 0
    fi

    # Execute or preview
    if $DRY_RUN; then
        echo "$(dry_run_prefix)Would remove: $path"
    else
        rm -rf "$path"
        success "Removed $description"
    fi
}

ask() {
    echo -e -n "${YELLOW}[?]${NC} $1 [y/N] "
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

ask_yes() {
    echo -e -n "${YELLOW}[?]${NC} $1 [Y/n] "
    read -r response
    [[ ! "$response" =~ ^[Nn]$ ]]
}

banner() {
    echo -e "${CYAN}"
    cat << 'EOF'
 _                            _
| |__  _   _ _ __  _ __      | | ___ _ __  ___
| '_ \| | | | '_ \| '__|_____| |/ _ \ '_ \/ __|
| | | | |_| | |_) | | |_____|| |  __/ | | \__ \
|_| |_|\__, | .__/|_|        |_|\___|_| |_|___/
       |___/|_|
EOF
    echo -e "${NC}"
    echo "Screen Capture & Visual Search for Hyprland"
    echo ""
}

# ==============================================================================
# Installation Detection
# ==============================================================================

# Check if hypr-lens is already installed
is_installed() {
    [[ -d "$QML_INSTALL_DIR" ]] && [[ -d "$SCRIPTS_INSTALL_DIR" ]]
}

# Check if shell.qml already has hypr-lens integrated
is_shell_integrated() {
    local shell_file="$HOME/.config/quickshell/shell.qml"
    [[ -f "$shell_file" ]] && grep -q "RegionSelector" "$shell_file"
}

# Check if Python venv exists and is functional
is_venv_setup() {
    [[ -d "$VENV_DIR" ]] && [[ -f "$VENV_DIR/bin/activate" ]]
}

# ==============================================================================
# Package Management
# ==============================================================================

# Command to package name mapping
declare -A CMD_TO_PKG=(
    # Required
    ["quickshell"]="quickshell-git"
    ["grim"]="grim"
    ["slurp"]="slurp"
    ["wl-copy"]="wl-clipboard"
    ["jq"]="jq"
    ["notify-send"]="libnotify"
    ["magick"]="imagemagick"
    # Optional
    ["tesseract"]="tesseract"
    ["swappy"]="swappy"
    ["wf-recorder"]="wf-recorder"
    ["hyprpicker"]="hyprpicker"
    ["matugen"]="matugen-bin"
)

# Packages that require AUR
declare -A AUR_PACKAGES=(
    ["quickshell-git"]=1
    ["matugen-bin"]=1
)

detect_aur_helper() {
    if command -v paru &>/dev/null; then
        echo "paru"
    elif command -v yay &>/dev/null; then
        echo "yay"
    else
        echo ""
    fi
}

install_packages() {
    local packages=("$@")
    local official=()
    local aur=()

    # Separate official vs AUR packages
    for pkg in "${packages[@]}"; do
        if [[ -n "${AUR_PACKAGES[$pkg]}" ]]; then
            aur+=("$pkg")
        else
            official+=("$pkg")
        fi
    done

    # Install official packages with pacman
    if [[ ${#official[@]} -gt 0 ]]; then
        info "Installing from official repos: ${official[*]}"
        if $DRY_RUN; then
            echo "$(dry_run_prefix)Would run: sudo pacman -S --needed --noconfirm ${official[*]}"
        else
            sudo pacman -S --needed --noconfirm "${official[@]}"
        fi
    fi

    # Install AUR packages with helper
    if [[ ${#aur[@]} -gt 0 ]]; then
        local helper
        helper=$(detect_aur_helper)
        if [[ -n "$helper" ]]; then
            info "Installing from AUR via $helper: ${aur[*]}"
            # Build helper-specific flags
            local aur_flags="--needed --noconfirm --removemake"
            if [[ "$helper" == "paru" ]]; then
                aur_flags+=" --skipreview"
            elif [[ "$helper" == "yay" ]]; then
                aur_flags+=" --answeredit None --answerdiff None"
            fi
            if $DRY_RUN; then
                echo "$(dry_run_prefix)Would run: $helper -S $aur_flags ${aur[*]}"
            else
                $helper -S $aur_flags "${aur[@]}"
            fi
        else
            error "No AUR helper (paru/yay) found!"
            echo "  Install one first, then retry:"
            echo "    sudo pacman -S --needed paru"
            echo "  Or install AUR packages manually: ${aur[*]}"
            return 1
        fi
    fi
}

check_and_install() {
    local dep_type=$1  # "required" or "optional"
    shift
    local cmds=("$@")
    local missing_cmds=()
    local missing_pkgs=()

    # Find missing commands
    for cmd in "${cmds[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_cmds+=("$cmd")
            missing_pkgs+=("${CMD_TO_PKG[$cmd]:-$cmd}")
        fi
    done

    if [[ ${#missing_pkgs[@]} -eq 0 ]]; then
        return 0
    fi

    # Show what's missing
    if [[ "$dep_type" == "required" ]]; then
        warn "Missing required packages:"
    else
        info "Missing optional packages:"
    fi

    for i in "${!missing_cmds[@]}"; do
        echo "  ${missing_cmds[$i]} → ${missing_pkgs[$i]}"
    done
    echo ""

    # Prompt to install
    if ask "Install missing packages now?"; then
        install_packages "${missing_pkgs[@]}"

        # Verify installation
        local still_missing=()
        for cmd in "${missing_cmds[@]}"; do
            if ! command -v "$cmd" &>/dev/null; then
                still_missing+=("$cmd")
            fi
        done

        if [[ ${#still_missing[@]} -gt 0 ]]; then
            warn "Some packages failed to install: ${still_missing[*]}"
            if [[ "$dep_type" == "required" ]]; then
                error "Cannot continue without required dependencies"
                exit 1
            fi
        else
            success "All packages installed successfully"
        fi
    else
        if [[ "$dep_type" == "required" ]]; then
            error "Cannot continue without required dependencies"
            exit 1
        else
            warn "Skipping optional packages - some features may not work"
        fi
    fi
}

# ==============================================================================
# Installation Functions
# ==============================================================================

install_qml_modules() {
    info "Installing QML modules to $QML_INSTALL_DIR"

    if dry_run_preview \
        "Would create: $QML_INSTALL_DIR" \
        "Would copy: $SCRIPT_DIR/quickshell/* → $QML_INSTALL_DIR/"; then
        return
    fi

    mkdir -p "$QML_INSTALL_DIR"
    cp -r "$SCRIPT_DIR/quickshell/"* "$QML_INSTALL_DIR/"
    success "QML modules installed"
}

install_scripts() {
    info "Installing scripts to $SCRIPTS_INSTALL_DIR"

    if dry_run_preview \
        "Would create: $SCRIPTS_INSTALL_DIR" \
        "Would copy: $SCRIPT_DIR/scripts/* → $SCRIPTS_INSTALL_DIR/"; then
        return
    fi

    mkdir -p "$SCRIPTS_INSTALL_DIR"
    cp -r "$SCRIPT_DIR/scripts/"* "$SCRIPTS_INSTALL_DIR/"
    chmod +x "$SCRIPTS_INSTALL_DIR/videos/record.sh"
    chmod +x "$SCRIPTS_INSTALL_DIR/images/find-regions-venv.sh"
    chmod +x "$SCRIPTS_INSTALL_DIR/images/find_regions.py"
    success "Scripts installed"
}

setup_python_venv() {
    if ! command -v python3 &>/dev/null; then
        warn "Python3 not found, skipping venv setup"
        warn "Content detection (OpenCV) will not be available"
        return
    fi

    info "Setting up Python virtual environment at $VENV_DIR"

    if dry_run_preview \
        "Would create: $VENV_DIR" \
        "Would install: opencv-python, numpy"; then
        return
    fi

    if [[ -d "$VENV_DIR" ]]; then
        if ask "Python venv already exists. Recreate it?"; then
            rm -rf "$VENV_DIR"
        else
            success "Using existing venv"
            return
        fi
    fi

    python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip
    pip install opencv-python numpy
    deactivate
    success "Python venv created with OpenCV"
}

install_config() {
    info "Installing default configuration to $CONFIG_DIR"

    if dry_run_preview \
        "Would create: $CONFIG_DIR" \
        "Would copy: $SCRIPT_DIR/defaults/config.jsonc → $CONFIG_DIR/config.jsonc" \
        "Would copy: $SCRIPT_DIR/defaults/CONFIG_README.md → $CONFIG_DIR/CONFIG_README.md"; then
        return
    fi

    mkdir -p "$CONFIG_DIR"

    # Always copy/update the README
    cp "$SCRIPT_DIR/defaults/CONFIG_README.md" "$CONFIG_DIR/CONFIG_README.md"

    if [[ -f "$CONFIG_DIR/config.jsonc" ]]; then
        warn "Config already exists at $CONFIG_DIR/config.jsonc"
        if ask "Overwrite with defaults?"; then
            cp "$SCRIPT_DIR/defaults/config.jsonc" "$CONFIG_DIR/config.jsonc"
            success "Config overwritten"
        else
            success "Keeping existing config"
        fi
    else
        cp "$SCRIPT_DIR/defaults/config.jsonc" "$CONFIG_DIR/config.jsonc"
        success "Default config installed"
    fi
    success "Config README installed"
}

generate_keybinds_example() {
    local example_file="$SCRIPT_DIR/keybinds.example.conf"

    info "Generating keybinds example file"

    if dry_run_preview "Would create: $example_file"; then
        return
    fi

    cat > "$example_file" << 'EOF'
# hypr-lens keybinds
# Copy these to your Hyprland keybinds config file
# (e.g., ~/.config/hypr/keybinds.conf or your custom keybinds file)

# Region screenshot (copy to clipboard)
bind = Super+Shift, S, global, quickshell:regionScreenshot

# Image search (Google Lens)
bind = Super+Shift, A, global, quickshell:regionSearch

# OCR text extraction
bind = Super+Shift, X, global, quickshell:regionOcr

# Region recording
bind = Super+Shift, R, global, quickshell:regionRecord

# Region recording with audio
bind = Super+Shift+Alt, R, global, quickshell:regionRecordWithSound

# Color picker (requires hyprpicker)
bind = Super+Shift, C, exec, hyprpicker -a

# Quick fullscreen screenshot
bindl = , Print, exec, grim - | wl-copy
EOF

    success "Created $example_file"
}

update_directories_paths() {
    # Update Directories.qml to point to installed scripts location
    local dirs_file="$QML_INSTALL_DIR/modules/common/Directories.qml"

    if dry_run_preview "Would update script paths in $dirs_file"; then
        return
    fi

    if [[ -f "$dirs_file" ]]; then
        # Update scriptPath to point to installed location
        sed -i "s|home + \"/.config/hypr/hyprland/scripts/hypr-lens\"|\"$SCRIPTS_INSTALL_DIR\"|g" "$dirs_file"
        success "Updated script paths in Directories.qml"
    fi
}

# ==============================================================================
# Auto-Integration Functions
# ==============================================================================

auto_integrate_shell() {
    local shell_file="$HOME/.config/quickshell/shell.qml"
    local backup_file="${shell_file}.hypr-lens-backup.$(date +%Y%m%d_%H%M%S)"
    local temp_file="${shell_file}.hypr-lens-temp.$$"

    if dry_run_preview \
        "Would backup: $shell_file → $backup_file" \
        "Would add import and RegionSelector to shell.qml"; then
        return 0
    fi

    # Check if already integrated
    if grep -q 'hypr-lens' "$shell_file"; then
        warn "hypr-lens already appears to be integrated in shell.qml"
        info "Skipping auto-integration"
        return 0
    fi

    # Create backup atomically (copy to temp, then rename)
    cp "$shell_file" "$temp_file"
    mv "$temp_file" "$backup_file"
    success "Backup created: $backup_file"

    # Work on a temporary copy for atomic replacement
    cp "$shell_file" "$temp_file"

    # Find last import line
    local last_import_line
    last_import_line=$(grep -n "^import" "$temp_file" | tail -1 | cut -d: -f1)

    if [[ -z "$last_import_line" ]]; then
        error "Could not find import statements in shell.qml"
        rm -f "$temp_file"
        return 1
    fi

    # Insert our import after the last import
    sed -i "${last_import_line}a import \"./hypr-lens/modules/regionSelector\"" "$temp_file"
    info "Added import statement after line $last_import_line"

    # Find root component (Scope { or ShellRoot { or similar)
    local root_line
    root_line=$(grep -n "^Scope {\\|^ShellRoot {\\|^Variants {" "$temp_file" | head -1 | cut -d: -f1)

    if [[ -z "$root_line" ]]; then
        error "Could not find root component (Scope/ShellRoot) in shell.qml"
        rm -f "$temp_file"
        return 1
    fi

    # Insert RegionSelector {} after the root component's opening brace
    sed -i "${root_line}a\\    RegionSelector {}" "$temp_file"
    info "Added RegionSelector {} after line $root_line"

    # Atomically replace the original file
    mv "$temp_file" "$shell_file"

    # Validate by trying to start quickshell briefly
    info "Validating syntax..."

    # Kill any existing quickshell first
    killall quickshell 2>/dev/null || true
    sleep 1

    # Try to start quickshell with a timeout
    local validation_output
    if timeout 5 quickshell 2>&1 &
    then
        sleep 3
        # Check if it's still running (good sign)
        if pgrep -x quickshell >/dev/null; then
            killall quickshell 2>/dev/null || true
            success "Syntax validation passed"
            success "Auto-integration complete!"
            echo ""
            info "Backup saved at: $backup_file"
            return 0
        fi
    fi

    # If we get here, validation might have failed
    # Check for QML errors in recent output
    warn "Could not fully validate syntax"
    echo ""
    echo "The integration was applied. Please verify manually:"
    echo "  1. Run: quickshell"
    echo "  2. Check for errors"
    echo "  3. If broken, restore: cp '$backup_file' '$shell_file'"
    echo ""
    return 0
}

# ==============================================================================
# Uninstall Functions
# ==============================================================================

uninstall() {
    banner
    warn "This will remove hypr-lens components"
    echo ""
    echo "Components to remove:"
    echo "  - QML modules: $QML_INSTALL_DIR"
    echo "  - Scripts: $SCRIPTS_INSTALL_DIR"
    echo ""
    echo "Optional (will ask):"
    echo "  - Python venv: $VENV_DIR"
    echo "  - Config: $CONFIG_DIR"
    echo ""

    if ! ask "Continue with uninstall?"; then
        info "Uninstall cancelled"
        exit 0
    fi

    # Required removals
    remove_if_exists "$QML_INSTALL_DIR" "QML modules"
    remove_if_exists "$SCRIPTS_INSTALL_DIR" "scripts"

    # Optional removals
    remove_if_exists "$VENV_DIR" "Python venv" --prompt "Remove Python venv ($VENV_DIR)?"
    remove_if_exists "$CONFIG_DIR" "config" --prompt "Remove config ($CONFIG_DIR)?"

    # Clean up empty parent directories
    rmdir "$HOME/.local/share/hypr-lens" 2>/dev/null || true

    echo ""
    success "Uninstall complete!"
    echo ""
    warn "Remember to remove keybinds from your Hyprland config manually"
}

# ==============================================================================
# Install Helper Functions
# ==============================================================================

# Global state for shell integration (set by prompt_shell_integration, used by show_next_steps)
USE_INTEGRATED=false
AUTO_INTEGRATED=false

# Display post-installation next steps
show_next_steps() {
    local existing_shell="$HOME/.config/quickshell/shell.qml"

    echo "=============================================="
    echo "Next steps:"
    echo "=============================================="
    echo ""

    if $AUTO_INTEGRATED; then
        echo -e "1. ${BOLD}Restart quickshell:${NC}"
        echo "   killall quickshell; quickshell &"
        echo ""
        echo -e "   ${GREEN}(Integration was done automatically)${NC}"
    elif $USE_INTEGRATED; then
        echo -e "1. ${BOLD}Edit your shell.qml:${NC}"
        echo "   $existing_shell"
        echo ""
        echo "   a) Add this import near the top (with your other imports):"
        echo ""
        echo -e "      ${CYAN}import \"./hypr-lens/modules/regionSelector\"${NC}"
        echo ""
        echo "   b) Add RegionSelector inside your main component. Example:"
        echo ""
        echo -e "      ${CYAN}Scope {${NC}"
        echo -e "      ${CYAN}    // ... your existing content ...${NC}"
        echo ""
        echo -e "      ${CYAN}    RegionSelector {}  // <-- add this line${NC}"
        echo -e "      ${CYAN}}${NC}"
        echo ""
        echo -e "2. ${BOLD}Restart quickshell:${NC}"
        echo "   killall quickshell; quickshell &"
    else
        echo -e "1. ${BOLD}Start hypr-lens (for this session):${NC}"
        echo "   qs --path ~/.config/quickshell/hypr-lens &"
        echo ""
        echo -e "2. ${BOLD}Add startup to your execs.conf:${NC}"
        echo "   exec-once = qs --path ~/.config/quickshell/hypr-lens &"
    fi

    # Determine next step number based on what was shown above
    local next_step=2
    if $AUTO_INTEGRATED; then
        next_step=2
    elif $USE_INTEGRATED; then
        next_step=3
    else
        next_step=3
    fi

    echo ""
    echo -e "${next_step}. ${BOLD}Add keybinds to your Hyprland config:${NC}"
    echo "   See: $SCRIPT_DIR/keybinds.example.conf"
    echo ""
    echo -e "$((next_step + 1)). ${BOLD}Reload Hyprland:${NC}"
    echo "   hyprctl reload"
    echo ""
    echo -e "$((next_step + 2)). ${BOLD}Test it:${NC}"
    echo "   Press Super+Shift+S for region screenshot"
    echo ""
    echo "Keybinds reference:"
    echo "  Super+Shift+S     Screenshot (copy to clipboard)"
    echo "  Super+Shift+A     Image search (Google Lens)"
    echo "  Super+Shift+X     OCR text extraction"
    echo "  Super+Shift+R     Region recording"
    echo "  Super+Shift+Alt+R Recording with audio"
    echo "  Super+Shift+C     Color picker"
    echo "  Print             Quick fullscreen screenshot"
    echo ""
}

# Prompt user about shell.qml integration
# Sets: USE_INTEGRATED, AUTO_INTEGRATED globals
prompt_shell_integration() {
    local existing_shell="$HOME/.config/quickshell/shell.qml"

    [[ -f "$existing_shell" ]] || return 0

    echo "----------------------------------------------"
    info "Existing quickshell shell detected at:"
    echo "   $existing_shell"
    echo ""
    echo "You can either:"
    echo "  1. INTEGRATE into your existing shell (saves ~300MB RAM)"
    echo "  2. RUN SEPARATELY as standalone instance"
    echo ""
    read -r -p "$(echo -e "${YELLOW}[?]${NC} Integrate into existing shell? [1/y or 2/n] ")" integrate_choice
    if [[ "$integrate_choice" =~ ^[1Yy]$ ]]; then
        USE_INTEGRATED=true
        echo ""
        echo "Integration options:"
        echo "  A) AUTOMATIC - Let installer modify shell.qml"
        echo "     Backup will be created at: ${existing_shell}.hypr-lens-backup.<timestamp>"
        echo "  M) MANUAL    - Show instructions to do it yourself"
        echo ""
        read -r -p "$(echo -e "${YELLOW}[?]${NC} Attempt automatic integration? [a/M] ")" auto_choice
        if [[ "$auto_choice" =~ ^[Aa]$ ]]; then
            echo ""
            if auto_integrate_shell; then
                AUTO_INTEGRATED=true
            fi
        fi
    fi
    echo "----------------------------------------------"
    echo ""
}

# Handle optional feature installation (venv, matugen)
prompt_optional_features() {
    echo ""
    if ask "Set up Python venv for OpenCV content detection?"; then
        setup_python_venv
    else
        warn "Skipping Python venv - content detection disabled"
    fi

    echo ""
    # Check for matugen theming
    if command -v matugen &>/dev/null; then
        success "matugen detected - dynamic theming enabled"
        # Discover and let user pick matugen.json location
        discover_matugen
    else
        info "matugen not installed (optional)"
        echo "  hypr-lens supports dynamic Material You theming via matugen."
        echo "  Without it, a default blue theme is used."
        echo ""
        if ask "Would you like to install matugen for dynamic theming?"; then
            echo ""
            echo "Install matugen with one of:"
            echo "  paru -S matugen-bin"
            echo "  yay -S matugen-bin"
            echo ""
            info "After installing, run: matugen image /path/to/wallpaper.jpg"
            info "This generates ~/.config/quickshell/matugen.json"
        fi
    fi
}

# Discover and configure matugen theme file location
discover_matugen() {
    info "Searching for matugen theme files..."

    # Search common locations for matugen JSON files
    local matugen_files=()
    while IFS= read -r file; do
        [[ -n "$file" ]] && matugen_files+=("$file")
    done < <(find "$HOME/.config" -type f \( -name "matugen*.json" -o -name "*matugen.json" -o -name "colors.json" \) 2>/dev/null | grep -v "node_modules" | head -10)

    if [[ ${#matugen_files[@]} -eq 0 ]]; then
        warn "No matugen.json files found"
        info "Using default path: ~/.config/quickshell/matugen.json"
        info "Run 'matugen image <wallpaper>' to generate theme colors"
        return
    fi

    echo ""
    echo "Found matugen theme files:"
    for i in "${!matugen_files[@]}"; do
        echo "  $((i+1))) ${matugen_files[$i]}"
    done
    echo "  $((${#matugen_files[@]}+1))) Enter custom path"
    echo "  $((${#matugen_files[@]}+2))) Skip (use default ~/.config/quickshell/matugen.json)"
    echo ""

    read -r -p "Select matugen file [1-$((${#matugen_files[@]}+2))]: " choice

    local selected_path=""
    if [[ "$choice" =~ ^[0-9]+$ ]]; then
        if [[ $choice -le ${#matugen_files[@]} && $choice -ge 1 ]]; then
            selected_path="${matugen_files[$((choice-1))]}"
        elif [[ $choice -eq $((${#matugen_files[@]}+1)) ]]; then
            read -r -p "Enter full path to matugen.json: " selected_path
        fi
    fi

    if [[ -n "$selected_path" ]]; then
        if [[ -f "$selected_path" ]]; then
            # Update config.jsonc with selected path
            if [[ -f "$CONFIG_DIR/config.jsonc" ]]; then
                if dry_run_preview "Would set matugen path in config to: $selected_path"; then
                    return
                fi
                # Strip comments, update with jq, then re-add comments manually
                # (jq doesn't support JSONC, so we use sed to strip // comments first)
                local tmp_config
                tmp_config=$(mktemp)
                if sed 's|//.*||g' "$CONFIG_DIR/config.jsonc" | jq --arg path "$selected_path" '.appearance.matugenPath = $path' > "$tmp_config" 2>/dev/null; then
                    mv "$tmp_config" "$CONFIG_DIR/config.jsonc"
                    success "Matugen path set to: $selected_path"
                    warn "Note: Comments were stripped from config. See CONFIG_README.md for reference."
                else
                    rm -f "$tmp_config"
                    warn "Failed to update config - using default path"
                fi
            fi
        else
            warn "File not found: $selected_path"
            info "Using default path: ~/.config/quickshell/matugen.json"
        fi
    else
        info "Using default path: ~/.config/quickshell/matugen.json"
    fi
}

# ==============================================================================
# Main Installation
# ==============================================================================

install() {
    banner

    if $DRY_RUN; then
        warn "DRY-RUN MODE - No changes will be made"
        echo ""
    fi

    # Suggest update mode if already installed
    if is_installed; then
        info "Existing hypr-lens installation detected"
        echo ""
        echo "For a quick update, use: ./hypr-lens-install.sh --update"
        echo "  (Skips prompts for already-configured components)"
        echo ""
        if ! ask "Continue with full installation anyway?"; then
            info "Tip: Use --update for quick file refresh"
            exit 0
        fi
        echo ""
    fi

    info "Checking dependencies..."
    check_and_install "required" quickshell grim slurp wl-copy jq notify-send magick
    check_and_install "optional" tesseract swappy wf-recorder hyprpicker python3 matugen
    success "Required dependencies found"
    echo ""

    echo "Installation paths:"
    echo "  QML modules: $QML_INSTALL_DIR"
    echo "  Scripts:     $SCRIPTS_INSTALL_DIR"
    echo "  Python venv: $VENV_DIR"
    echo "  Config:      $CONFIG_DIR"
    echo ""

    if ! ask_yes "Continue with installation?"; then
        info "Installation cancelled"
        exit 0
    fi
    echo ""

    # Install components
    install_qml_modules
    install_scripts
    update_directories_paths
    install_config

    # Optional features
    prompt_optional_features

    echo ""
    generate_keybinds_example

    echo ""
    echo "=============================================="
    success "Installation complete!"
    echo "=============================================="
    echo ""

    # Shell integration and next steps
    prompt_shell_integration
    show_next_steps
}

# ==============================================================================
# Quick Update Mode
# ==============================================================================

update() {
    banner

    if $DRY_RUN; then
        warn "DRY-RUN MODE - No changes will be made"
        echo ""
    fi

    info "Update mode - refreshing hypr-lens components"
    echo ""

    # Verify it's actually installed
    if ! is_installed; then
        warn "hypr-lens is not installed. Running full installation..."
        echo ""
        install
        return
    fi

    # Check dependencies (always)
    info "Checking dependencies..."
    check_and_install "required" quickshell grim slurp wl-copy jq notify-send magick
    echo ""

    # Update QML modules
    info "Updating QML modules..."
    if dry_run_preview "Would update: $QML_INSTALL_DIR"; then
        :
    else
        mkdir -p "$QML_INSTALL_DIR"
        cp -r "$SCRIPT_DIR/quickshell/"* "$QML_INSTALL_DIR/"
        success "QML modules updated"
    fi

    # Update scripts
    info "Updating scripts..."
    if dry_run_preview "Would update: $SCRIPTS_INSTALL_DIR"; then
        :
    else
        mkdir -p "$SCRIPTS_INSTALL_DIR"
        cp -r "$SCRIPT_DIR/scripts/"* "$SCRIPTS_INSTALL_DIR/"
        chmod +x "$SCRIPTS_INSTALL_DIR/videos/record.sh"
        chmod +x "$SCRIPTS_INSTALL_DIR/images/find-regions-venv.sh"
        chmod +x "$SCRIPTS_INSTALL_DIR/images/find_regions.py"
        success "Scripts updated"
    fi

    # Update Directories.qml paths (always needed)
    update_directories_paths

    # Smart skip for venv
    if is_venv_setup; then
        success "Python venv already configured"
    else
        echo ""
        if ask "Python venv not set up. Set it up now?"; then
            setup_python_venv
        else
            warn "Skipping Python venv - content detection disabled"
        fi
    fi

    # Config is preserved (don't overwrite user settings)
    if [[ -f "$CONFIG_DIR/config.jsonc" ]]; then
        success "Config preserved (not overwritten)"
    else
        install_config
    fi

    echo ""
    echo "=============================================="
    success "Update complete!"
    echo "=============================================="
    echo ""

    # Check shell integration - offer recovery if missing
    if is_shell_integrated; then
        success "Shell integration verified"
        info "Restart quickshell to apply changes:"
        echo "  killall quickshell; quickshell &"
    else
        warn "Shell integration missing (shell.qml may have been overwritten)"
        echo ""
        echo "  Options:"
        echo "    1) Auto-integrate into shell.qml (creates backup)"
        echo "    2) Show manual integration instructions"
        echo "    3) Skip (fix later)"
        echo ""
        echo -e -n "${YELLOW}[?]${NC} Choose option [1/2/3]: "
        read -r choice
        case "$choice" in
            1)
                auto_integrate_shell
                ;;
            2)
                echo ""
                info "Add to ~/.config/quickshell/shell.qml:"
                echo ""
                echo "  // At the top with imports:"
                echo "  import \"./hypr-lens/modules/regionSelector\""
                echo ""
                echo "  // Inside root component (Scope, ShellRoot, etc.):"
                echo "  RegionSelector {}"
                echo ""
                ;;
            3|"")
                info "Skipped. Run installer without --update for full setup."
                ;;
        esac
    fi
    echo ""
}

# ==============================================================================
# Entry Point
# ==============================================================================

if $UNINSTALL; then
    uninstall
elif $UPDATE_MODE; then
    update
else
    install
fi

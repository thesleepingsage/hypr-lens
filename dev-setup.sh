#!/bin/bash
# hypr-lens Developer Setup
# Creates symlinks from install dirs to source for live editing
#
# Usage: ./dev-setup.sh

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

QML_INSTALL_DIR="$HOME/.config/quickshell/hypr-lens"
SCRIPTS_INSTALL_DIR="$HOME/.local/share/hypr-lens/scripts"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${YELLOW}[DEV]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }

echo "hypr-lens Developer Setup"
echo "========================="
echo ""
echo "This creates symlinks so edits in the repo are immediately reflected."
echo ""

for pair in \
    "$QML_INSTALL_DIR:$SCRIPT_DIR/quickshell" \
    "$SCRIPTS_INSTALL_DIR:$SCRIPT_DIR/scripts"; do

    dest="${pair%%:*}"
    source="${pair##*:}"

    if [[ -L "$dest" ]]; then
        info "Symlink already exists: $dest"
    elif [[ -d "$dest" ]]; then
        info "Replacing directory with symlink: $dest"
        rm -rf "$dest"
        mkdir -p "$(dirname "$dest")"
        ln -s "$source" "$dest"
        success "Symlinked: $dest → $source"
    else
        mkdir -p "$(dirname "$dest")"
        ln -s "$source" "$dest"
        success "Symlinked: $dest → $source"
    fi
done

echo ""
success "Dev setup complete! Edits in repo are now live."

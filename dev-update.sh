#!/bin/bash
# Quick dev update - syncs scripts + ensures shell.qml integration
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DEST="$HOME/.local/share/hypr-lens/scripts"
SHELL_QML="$HOME/.config/quickshell/shell.qml"

# Sync scripts
echo "Syncing scripts..."
rsync -av --delete "$SCRIPT_DIR/scripts/" "$SCRIPTS_DEST/"
chmod +x "$SCRIPTS_DEST/videos/record.sh"
chmod +x "$SCRIPTS_DEST/images/find-regions-venv.sh"
chmod +x "$SCRIPTS_DEST/images/find_regions.py"

# Shell.qml integration (one-time)
if [[ -f "$SHELL_QML" ]] && ! grep -q "RegionSelector" "$SHELL_QML"; then
    echo "Integrating into shell.qml..."

    # Find last import line
    last_import=$(grep -n "^import" "$SHELL_QML" | tail -1 | cut -d: -f1)

    # Find closing brace of Scope
    closing_brace=$(grep -n "^}" "$SHELL_QML" | tail -1 | cut -d: -f1)

    if [[ -n "$last_import" && -n "$closing_brace" ]]; then
        # Insert import after last import
        sed -i "${last_import}a import \"./hypr-lens/modules/regionSelector\"" "$SHELL_QML"

        # Insert RegionSelector before closing brace (line number shifted by 1 due to previous insert)
        closing_brace=$((closing_brace + 1))
        sed -i "${closing_brace}i\\  RegionSelector {}" "$SHELL_QML"

        echo "✓ Shell integration added"
    else
        echo "⚠ Could not find insertion points - integrate manually"
    fi
else
    echo "✓ Shell already integrated"
fi

echo "Done! Restart quickshell: killall quickshell; quickshell &"

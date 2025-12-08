#!/usr/bin/env bash
# Wrapper script to run find_regions.py with its Python venv
# The venv is created by the installer at ~/.local/share/hypr-lens/venv

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$HOME/.local/share/hypr-lens/venv"

if [[ ! -d "$VENV_DIR" ]]; then
    echo "Error: Python venv not found at $VENV_DIR" >&2
    echo "Please run the hypr-lens installer to set up the venv." >&2
    exit 1
fi

source "$VENV_DIR/bin/activate"
python3 "$SCRIPT_DIR/find_regions.py" "$@"
exit_code=$?
deactivate
exit $exit_code

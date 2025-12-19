#!/usr/bin/env bash
# hypr-lens screen recording script
# Uses wf-recorder for Wayland screen capture

# Constants
readonly APP_NAME="hypr-lens"
readonly CONFIG_FILE="$HOME/.config/hypr-lens/config.json"
readonly JSON_PATH=".screenRecord.savePath"

# Helper functions
notify() {
    local title="$1" body="$2"
    notify-send "$title" "$body" -a "$APP_NAME" & disown
}

build_filename() {
    echo "./recording_$(date '+%Y-%m-%d_%H.%M.%S').mp4"
}

get_audio_output() {
    pactl list sources | grep 'Name' | grep 'monitor' | cut -d ' ' -f2
}

get_active_monitor() {
    hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name'
}

# Configuration
CUSTOM_PATH=$(jq -r "$JSON_PATH" "$CONFIG_FILE" 2>/dev/null)
if [[ -n "$CUSTOM_PATH" && "$CUSTOM_PATH" != "null" ]]; then
    RECORDING_DIR="$CUSTOM_PATH"
else
    RECORDING_DIR="$HOME/Videos/hypr-lens"
fi

# Expand ~ to $HOME (tilde doesn't expand when read from config file)
RECORDING_DIR="${RECORDING_DIR/#\~/$HOME}"

mkdir -p "$RECORDING_DIR"
cd "$RECORDING_DIR" || exit

ARGS=("$@")
MANUAL_REGION=""
SOUND_FLAG=0
FULLSCREEN_FLAG=0
for ((i=0;i<${#ARGS[@]};i++)); do
    case "${ARGS[i]}" in
        --region)
            if (( i+1 < ${#ARGS[@]} )); then
                MANUAL_REGION="${ARGS[i+1]}"
                # Validate region format: X,Y WxH (e.g., "100,200 800x600")
                if [[ ! "$MANUAL_REGION" =~ ^[0-9]+,[0-9]+\ [0-9]+x[0-9]+$ ]]; then
                    notify "Recording cancelled" "Invalid region format: $MANUAL_REGION (expected: X,Y WxH)"
                    exit 1
                fi
            else
                notify "Recording cancelled" "No region specified for --region"
                exit 1
            fi
            ;;
        --sound) SOUND_FLAG=1 ;;
        --fullscreen) FULLSCREEN_FLAG=1 ;;
    esac
done

# Check if already recording - if so, stop
if pgrep wf-recorder > /dev/null; then
    notify "Recording Stopped" "Stopped"
    pkill wf-recorder &
    exit 0
fi

# Build wf-recorder command
CMD=(wf-recorder --pixel-format yuv420p -f "$(build_filename)")

if [[ $FULLSCREEN_FLAG -eq 1 ]]; then
    CMD+=(-o "$(get_active_monitor)")
else
    # Get region (manual or via slurp)
    if [[ -n "$MANUAL_REGION" ]]; then
        region="$MANUAL_REGION"
    elif ! region="$(slurp 2>&1)"; then
        notify "Recording cancelled" "Selection was cancelled"
        exit 1
    fi
    CMD+=(--geometry "$region")
fi

if [[ $SOUND_FLAG -eq 1 ]]; then
    CMD+=(--audio="$(get_audio_output)")
fi

# Start recording
notify "Starting recording" "$(basename "$(build_filename)")"
"${CMD[@]}"

#!/bin/bash

# Ensure we have a directory
if [ -z "$1" ]; then
    echo "Usage: $0 /path/to/music"
    exit 1
fi

DIR=$(realpath "$1")
OUT="$DIR/opus"
mkdir -p "$OUT"

# Define the processing logic as a function to be called by find
process_file() {
    local f="$1"
    local name=$(basename "${f%.flac}")
    local FINAL="$OUT/$name.opus"

    # Define temp files
    local TMP_OPUS=$(mktemp --suffix=.opus)
    local TMP_COVER=$(mktemp --suffix=.jpg)

    echo "Processing: $name"

    # 1. Convert FLAC to Opus
    ffmpeg -y -hide_banner -loglevel error -i "$f" \
        -c:a libopus -b:a 96k \
        -map_metadata 0 \
        "$TMP_OPUS" || {
            echo "FFmpeg failed: $name"
            rm -f "$TMP_OPUS"
            return
        }

    # 2. Extract cover
    ffmpeg -y -hide_banner -loglevel error -i "$f" \
        -an -vcodec copy "$TMP_COVER" 2>/dev/null || true

    # 3. Apply cover via kid3-cli (using your original logic)
    if [[ -s "$TMP_COVER" ]] && command -v kid3-cli >/dev/null 2>&1; then
        kid3-cli \
            -c "set picture:\"$TMP_COVER\" 'Front Cover'" \
            "$TMP_OPUS" \
            > /dev/null || echo "Cover failed: $name"
    fi

    mv -- "$TMP_OPUS" "$FINAL"
    rm -f "$TMP_COVER"
}

export -f process_file
export OUT

# Use -exec to handle paths safely, preventing the "Skipping missing" errors
find "$DIR" -maxdepth 1 -type f -name "*.flac" -exec bash -c 'process_file "$0"' {} \;

echo "Done."

#!/usr/bin/env bash

SRC="$1"
DEST="$2"

mkdir -p "$DEST"

for file in "$SRC"/*.flac; do
    filename=$(basename "$file")
    name="${filename%.flac}"
    destfile="$DEST/$name.mp3"

    if [ -f "$destfile" ]; then
        echo "Skipping existing: $filename"
        continue
    fi

    echo "Converting: $filename"

    ffmpeg -loglevel error -i "$file" \
        -map 0 \
        -map_metadata 0 \
        -c:a libmp3lame -b:a 320k \
        "$destfile"
done

echo "Done."

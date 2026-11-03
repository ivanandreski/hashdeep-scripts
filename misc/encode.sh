#!/bin/sh
set -euo pipefail

# ============================================================
# Configuration
# ============================================================

INPUT="/mnt/wdblue/Torrents/The.Cat.O'Nine.Tails.1971.4K.HDR.DV.2160p BDRemux Ita Eng x265-NAHOM/The.Cat.O'Nine.Tails.1971.4K.HDR.DV.2160p BDRemux Ita Eng x265-NAHOM.mkv"

OUTPUT="/mnt/kc600/cat-nine-tails-dv-crop-test.mkv"

# Fill these in before each run.
# Example:
# OUTPUT_WIDTH=3840
# OUTPUT_HEIGHT=1632

OUTPUT_WIDTH=3840
OUTPUT_HEIGHT=1632

# ============================================================
# Validate configuration
# ============================================================

if [[ -z "$OUTPUT_WIDTH" || -z "$OUTPUT_HEIGHT" ]]; then
    echo "ERROR: Set OUTPUT_WIDTH and OUTPUT_HEIGHT first."
    echo
    echo "Example:"
    echo "  OUTPUT_WIDTH=3840"
    echo "  OUTPUT_HEIGHT=1632"
    exit 1
fi

# ============================================================
# Read source resolution
# ============================================================

SOURCE_WIDTH=$(ffprobe \
    -v error \
    -select_streams v:0 \
    -show_entries stream=width \
    -of default=noprint_wrappers=1:nokey=1 \
    "$INPUT")

SOURCE_HEIGHT=$(ffprobe \
    -v error \
    -select_streams v:0 \
    -show_entries stream=height \
    -of default=noprint_wrappers=1:nokey=1 \
    "$INPUT")

echo "Source resolution: ${SOURCE_WIDTH}x${SOURCE_HEIGHT}"
echo "Output resolution: ${OUTPUT_WIDTH}x${OUTPUT_HEIGHT}"

# ============================================================
# Calculate centered crop
# ============================================================

if (( OUTPUT_WIDTH > SOURCE_WIDTH )); then
    echo "ERROR: Output width is larger than source width."
    exit 1
fi

if (( OUTPUT_HEIGHT > SOURCE_HEIGHT )); then
    echo "ERROR: Output height is larger than source height."
    exit 1
fi

WIDTH_DIFF=$((SOURCE_WIDTH - OUTPUT_WIDTH))
HEIGHT_DIFF=$((SOURCE_HEIGHT - OUTPUT_HEIGHT))

if (( WIDTH_DIFF % 2 != 0 )); then
    echo "ERROR: Width difference is not evenly divisible by 2."
    exit 1
fi

if (( HEIGHT_DIFF % 2 != 0 )); then
    echo "ERROR: Height difference is not evenly divisible by 2."
    exit 1
fi

CROP_X=$((WIDTH_DIFF / 2))
CROP_Y=$((HEIGHT_DIFF / 2))

CROP="crop=${OUTPUT_WIDTH}:${OUTPUT_HEIGHT}:${CROP_X}:${CROP_Y}"

echo "Crop filter: $CROP"
echo

# ============================================================
# Encode
# ============================================================

# ffmpeg \
#     -ss 0 \
#     -i "$INPUT" \
#     -t 15 \
#     -map 0:v:0 \
#     -map 0:1 \
#     -map 0:2 \
#     -map 0:3 \
#     -map 0:4 \
#     -vf "$CROP" \
#     -c:v libx265 \
#     -preset slow \
#     -crf 17 \
#     -pix_fmt yuv420p10le \
#     -dolbyvision 1 \
#     -x265-params "vbv-maxrate=30000:vbv-bufsize=30000" \
#     -c:a:0 aac \
#     -b:a:0 224k \
#     -c:a:1 copy \
#     -c:s copy \
#     "$OUTPUT"

ffmpeg \
    -ss 0 \
    -i "$INPUT" \
    -t 30 \
    -map 0:v:0 \
    -map 0:1 \
    -map 0:2 \
    -map 0:3 \
    -map 0:4 \
    -c:v libx265 \
    -preset ultrafast \
    -crf 17 \
    -pix_fmt yuv420p10le \
    -dolbyvision 1 \
    -x265-params "vbv-maxrate=30000:vbv-bufsize=30000" \
    -c:a:0 aac \
    -b:a:0 224k \
    -c:a:1 copy \
    -c:s copy \
    "/mnt/kc600/cat-nine-tails-ffmpeg-no-crop.mkv"
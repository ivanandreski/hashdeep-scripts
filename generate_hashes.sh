#!/usr/bin/env bash
# generate_hashes.sh
# Generates or updates hashdeep files for every movie container folder on the
# external HDD. Run this after adding or modifying content.
#
# Expected drive layout:
#   $DRIVE_ROOT/
#     4kMovies/<ContainerFolder>/...
#     Movies/<ContainerFolder>/...
#     hashes/4kMovies/<ContainerFolder>.hashdeep
#     hashes/Movies/<ContainerFolder>.hashdeep
#
# Usage:
#   ./generate_hashes.sh /path/to/drive/root

set -euo pipefail

# shellcheck source=common.sh
source "$(dirname "$0")/common.sh"
require_hashdeep

SUCCESS=0
SKIPPED=0
FAILED=0
FAILED_LIST=()

for CATEGORY in "${CATEGORIES[@]}"; do
    CATEGORY_PATH="$DRIVE_ROOT/$CATEGORY"
    HASH_CATEGORY_DIR="$HASH_DIR/$CATEGORY"

    if [[ ! -d "$CATEGORY_PATH" ]]; then
        echo "WARNING: Category folder not found, skipping: $CATEGORY_PATH"
        continue
    fi

    # Ensure output directory exists
    mkdir -p "$HASH_CATEGORY_DIR"

    echo
    echo "━━━  $CATEGORY  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Iterate over every direct sub-folder (movie container)
    while IFS= read -r -d '' CONTAINER_PATH; do
        CONTAINER_NAME="$(basename "$CONTAINER_PATH")"
        HASH_FILE="$HASH_CATEGORY_DIR/${CONTAINER_NAME}.hashdeep"

        # Skip if hash already exists
        if [[ -s "$HASH_FILE" ]]; then
            echo "  Skipping: $CONTAINER_NAME (hash exists)"
            (( SKIPPED++ )) || true
            continue
        fi

        echo -n "  Hashing: $CONTAINER_NAME ... "

        # -r  recursive
        # -l  relative paths (makes hash files portable)
        # -c sha256,md5  both algorithms for belt-and-suspenders
        # Output is written to the hash file, replacing any previous version.
        if hashdeep -r -l -c sha256,md5 "$CONTAINER_PATH" > "$HASH_FILE" 2>/dev/null; then
            FILE_COUNT=$(grep -c '^[^#%]' "$HASH_FILE" 2>/dev/null || echo "0")
            echo "OK  ($FILE_COUNT file(s))"
            (( SUCCESS++ )) || true
        else
            echo "FAILED"
            rm -f "$HASH_FILE"   # don't leave a partial file
            FAILED_LIST+=("$CATEGORY/$CONTAINER_NAME")
            (( FAILED++ )) || true
        fi

    done < <(find "$CATEGORY_PATH" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

done

# ── Summary ──────────────────────────────────────────────────────────────────
echo
echo "════════════════════════════════════════"
echo "  Generate complete"
echo "  Success : $SUCCESS container(s)"
echo "  Skipped : $SKIPPED container(s)"
echo "  Failed  : $FAILED container(s)"

if [[ ${#FAILED_LIST[@]} -gt 0 ]]; then
    echo
    echo "  Failed containers:"
    for ITEM in "${FAILED_LIST[@]}"; do
        echo "    - $ITEM"
    done
    exit 1
fi
echo "════════════════════════════════════════"

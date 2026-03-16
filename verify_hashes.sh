#!/usr/bin/env bash
# verify_hashes.sh
# Audits every movie container against its stored hashdeep file and reports
# any corruption, missing files, or new untracked files.
#
# Exit codes:
#   0 — all containers passed
#   1 — one or more containers failed or had warnings
#   2 — fatal error (drive not found, hashdeep missing, etc.)
#
# Usage:
#   ./verify_hashes.sh /path/to/drive/root

set -uo pipefail

# shellcheck source=common.sh
source "$(dirname "$0")/common.sh"
require_hashdeep
require_hash_dir
LOG_FILE="$HASH_DIR/verify_$(date '+%Y%m%d_%H%M%S').log"

# Redirect all output to both terminal and log file
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Verify run: $(date)"
echo "Drive root: $DRIVE_ROOT"
echo

PASSED=0
FAILED=0
MISSING_HASH=0    # container exists, no hash file yet
MISSING_CONTAINER=0  # hash file exists, container folder is gone
FAILED_LIST=()

for CATEGORY in "${CATEGORIES[@]}"; do
    CATEGORY_PATH="$DRIVE_ROOT/$CATEGORY"
    HASH_CATEGORY_DIR="$HASH_DIR/$CATEGORY"

    if [[ ! -d "$CATEGORY_PATH" ]]; then
        echo "WARNING: Category folder not found, skipping: $CATEGORY_PATH"
        continue
    fi

    echo "━━━  $CATEGORY  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # ── Check: hash file exists but its container folder has been removed ───
    if [[ -d "$HASH_CATEGORY_DIR" ]]; then
        while IFS= read -r -d '' HASH_FILE; do
            CONTAINER_NAME="$(basename "$HASH_FILE" .txt)"
            CONTAINER_PATH="$CATEGORY_PATH/$CONTAINER_NAME"
            if [[ ! -d "$CONTAINER_PATH" ]]; then
                echo "  [ORPHAN]  Hash file has no matching folder: $CATEGORY/$CONTAINER_NAME"
                (( MISSING_CONTAINER++ )) || true
            fi
        done < <(find "$HASH_CATEGORY_DIR" -maxdepth 1 -name "*.txt" -print0 2>/dev/null | sort -z)
    fi

    # ── Check: container folder exists → verify against hash file ──────────
    while IFS= read -r -d '' CONTAINER_PATH; do
        CONTAINER_NAME="$(basename "$CONTAINER_PATH")"
        HASH_FILE="$HASH_CATEGORY_DIR/${CONTAINER_NAME}.txt"

        printf "  %-50s" "$CONTAINER_NAME"

        # No hash file for this container yet
        if [[ ! -f "$HASH_FILE" ]]; then
            echo "  [NO HASH]  Run generate_hashes.sh to create one."
            (( MISSING_HASH++ )) || true
            continue
        fi

        # hashdeep audit flags:
        # -a   audit mode — compare files against the known-good hash file
        # -r   recursive
        # -l   relative paths (matches how hashes were generated)
        # -k   path to known-good hash file
        # -q   quiet (suppress per-file OK lines; only shows failures)
        AUDIT_OUTPUT=$(hashdeep -r -l -a -k "$HASH_FILE" "$CONTAINER_PATH" 2>&1)
        AUDIT_EXIT=$?

        if [[ $AUDIT_EXIT -eq 0 ]]; then
            echo "  [OK]"
            (( PASSED++ )) || true
        else
            echo "  [FAILED] ← corruption or changed files detected"
            # Indent the detail lines for readability
            while IFS= read -r LINE; do
                echo "             $LINE"
            done <<< "$AUDIT_OUTPUT"
            FAILED_LIST+=("$CATEGORY/$CONTAINER_NAME")
            (( FAILED++ )) || true
        fi

    done < <(find "$CATEGORY_PATH" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

    echo
done

# ── Summary ──────────────────────────────────────────────────────────────────
echo "════════════════════════════════════════"
echo "  Verify complete: $(date)"
echo "  Passed          : $PASSED container(s)"
echo "  Failed          : $FAILED container(s)"
echo "  No hash yet     : $MISSING_HASH container(s)"
echo "  Orphaned hashes : $MISSING_CONTAINER (folder removed)"
echo "  Log saved to    : $LOG_FILE"

if [[ ${#FAILED_LIST[@]} -gt 0 ]]; then
    echo
    echo "  !! CORRUPTION / MISMATCH DETECTED in:"
    for ITEM in "${FAILED_LIST[@]}"; do
        echo "    - $ITEM"
    done
    echo "════════════════════════════════════════"
    exit 1
fi

echo "════════════════════════════════════════"

# Exit 0 only if nothing failed (missing hashes are a warning, not a failure)
[[ $MISSING_HASH -gt 0 || $MISSING_CONTAINER -gt 0 ]] && exit 1 || exit 0

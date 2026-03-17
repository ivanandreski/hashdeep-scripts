#!/usr/bin/env bash
# check_sync.sh
# Quickly checks whether every movie container folder has a matching hash file
# and every hash file has a matching container folder. Prints a diff-style
# report without running any hashing — this is intentionally fast.
#
# Exit codes:
#   0 — everything is in sync
#   1 — mismatches found
#   2 — fatal error (bad arguments, drive not found, etc.)
#
# Usage:
#   ./check_sync.sh /path/to/drive/root

set -euo pipefail

# shellcheck source=common.sh
source "$(dirname "$0")/common.sh"
require_hash_dir

TOTAL_MISSING_HASH=0    # container exists, no hash file
TOTAL_ORPHAN_HASH=0     # hash file exists, no container folder

for CATEGORY in "${CATEGORIES[@]}"; do
    CATEGORY_PATH="$DRIVE_ROOT/$CATEGORY"
    HASH_CATEGORY_DIR="$HASH_DIR/$CATEGORY"

    MISSING_HASH=()   # containers without a hash file
    ORPHAN_HASH=()    # hash files without a container folder

    # ── Build list of container folder names ─────────────────────────────
    declare -A CONTAINERS=()
    if [[ -d "$CATEGORY_PATH" ]]; then
        while IFS= read -r -d '' DIR; do
            NAME="$(basename "$DIR")"
            CONTAINERS["$NAME"]=1
        done < <(find "$CATEGORY_PATH" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
    fi

    # ── Build list of hash file names (strip .hashdeep suffix) ────────────────
    declare -A HASHED=()
    if [[ -d "$HASH_CATEGORY_DIR" ]]; then
        while IFS= read -r -d '' FILE; do
            NAME="$(basename "$FILE" .hashdeep)"
            HASHED["$NAME"]=1
        done < <(find "$HASH_CATEGORY_DIR" -maxdepth 1 -name "*.hashdeep" -print0 | sort -z)
    fi

    # ── Containers missing a hash file ───────────────────────────────────
    for NAME in $(printf '%s\n' "${!CONTAINERS[@]}" | sort); do
        if [[ -z "${HASHED[$NAME]+_}" ]]; then
            MISSING_HASH+=("$NAME")
        fi
    done

    # ── Hash files with no matching container folder ──────────────────────
    for NAME in $(printf '%s\n' "${!HASHED[@]}" | sort); do
        if [[ -z "${CONTAINERS[$NAME]+_}" ]]; then
            ORPHAN_HASH+=("$NAME")
        fi
    done

    # ── Print results for this category ──────────────────────────────────
    echo "━━━  $CATEGORY  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Containers : ${#CONTAINERS[@]}"
    echo "  Hash files : ${#HASHED[@]}"

    if [[ ${#MISSING_HASH[@]} -eq 0 && ${#ORPHAN_HASH[@]} -eq 0 ]]; then
        echo "  Status     : IN SYNC"
    else
        echo "  Status     : OUT OF SYNC"
        if [[ ${#MISSING_HASH[@]} -gt 0 ]]; then
            echo
            echo "  + Containers with NO hash file (${#MISSING_HASH[@]}):"
            for NAME in "${MISSING_HASH[@]}"; do
                echo "      + $CATEGORY/$NAME"
            done
        fi
        if [[ ${#ORPHAN_HASH[@]} -gt 0 ]]; then
            echo
            echo "  - Orphaned hash files with NO matching container (${#ORPHAN_HASH[@]}):"
            for NAME in "${ORPHAN_HASH[@]}"; do
                echo "      - $CATEGORY/$NAME"
            done
        fi
    fi

    echo

    (( TOTAL_MISSING_HASH += ${#MISSING_HASH[@]} )) || true
    (( TOTAL_ORPHAN_HASH  += ${#ORPHAN_HASH[@]}  )) || true

    unset CONTAINERS
    unset HASHED
done

# ── Overall summary ───────────────────────────────────────────────────────────
echo "════════════════════════════════════════"
if [[ $TOTAL_MISSING_HASH -eq 0 && $TOTAL_ORPHAN_HASH -eq 0 ]]; then
    echo "  All containers and hash files are in sync."
    echo "════════════════════════════════════════"
    exit 0
else
    echo "  Containers missing a hash : $TOTAL_MISSING_HASH"
    echo "  Orphaned hash files       : $TOTAL_ORPHAN_HASH"
    echo
    echo "  Run generate_hashes.sh to create missing hash files."
    echo "  Remove orphaned .hashdeep files from the hashes/ folder manually if the"
    echo "  corresponding container was intentionally deleted."
    echo "════════════════════════════════════════"
    exit 1
fi

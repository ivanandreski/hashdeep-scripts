#!/usr/bin/env bash
# compare_drives.sh
# Compares movie container folders between two drives and reports what is
# present on one but missing on the other, as well as what is shared.
# No hashing is performed — this is a fast, name-based diff.
#
# Expected drive layout on each drive:
#   $DRIVE_ROOT/
#     4kMovies/<ContainerFolder>/
#     Movies/<ContainerFolder>/
#
# Exit codes:
#   0 — both drives have identical content for all categories
#   1 — differences found
#   2 — fatal error (bad arguments, drive not found, etc.)
#
# Usage:
#   ./compare_drives.sh /path/to/drive-A /path/to/drive-B

set -euo pipefail

CATEGORIES=("4kMovies" "Movies")

# ── Arguments ─────────────────────────────────────────────────────────────────
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 /path/to/drive-A /path/to/drive-B"
    exit 2
fi

DRIVE_A="$1"
DRIVE_B="$2"

# ── Validate drive roots ──────────────────────────────────────────────────────
for DRIVE_LABEL in "A:$DRIVE_A" "B:$DRIVE_B"; do
    LABEL="${DRIVE_LABEL%%:*}"
    PATH_VAL="${DRIVE_LABEL#*:}"
    if [[ ! -d "$PATH_VAL" ]]; then
        echo "ERROR: Drive $LABEL root not found: $PATH_VAL"
        echo "       Make sure the drive is mounted, or pass the correct path as an argument."
        exit 2
    fi
done

echo
echo "  Drive A : $DRIVE_A"
echo "  Drive B : $DRIVE_B"
echo

TOTAL_ONLY_A=0
TOTAL_ONLY_B=0
TOTAL_SHARED=0

for CATEGORY in "${CATEGORIES[@]}"; do
    PATH_A="$DRIVE_A/$CATEGORY"
    PATH_B="$DRIVE_B/$CATEGORY"

    unset SET_A SET_B
    declare -A SET_A=()
    declare -A SET_B=()

    # ── Collect container names from drive A ─────────────────────────────
    if [[ -d "$PATH_A" ]]; then
        while IFS= read -r -d '' DIR; do
            SET_A["$(basename "$DIR")"]=1
        done < <(find -L "$PATH_A" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
    fi

    # ── Collect container names from drive B ─────────────────────────────
    if [[ -d "$PATH_B" ]]; then
        while IFS= read -r -d '' DIR; do
            SET_B["$(basename "$DIR")"]=1
        done < <(find -L "$PATH_B" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
    fi

    ONLY_A=()   # in A but not B
    ONLY_B=()   # in B but not A
    SHARED=0

    # ── Find entries only on A ────────────────────────────────────────────
    while IFS= read -r -d '' NAME; do
        if [[ -z "${SET_B[$NAME]+_}" ]]; then
            ONLY_A+=("$NAME")
        else
            (( SHARED++ )) || true
        fi
    done < <(printf '%s\0' "${!SET_A[@]}" | sort -z)

    # ── Find entries only on B ────────────────────────────────────────────
    while IFS= read -r -d '' NAME; do
        if [[ -z "${SET_A[$NAME]+_}" ]]; then
            ONLY_B+=("$NAME")
        fi
    done < <(printf '%s\0' "${!SET_B[@]}" | sort -z)

    # ── Print results for this category ──────────────────────────────────
    echo "━━━  $CATEGORY  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  On Drive A : ${#SET_A[@]} container(s)"
    echo "  On Drive B : ${#SET_B[@]} container(s)"
    echo "  Shared     : $SHARED"

    if [[ ${#ONLY_A[@]} -eq 0 && ${#ONLY_B[@]} -eq 0 ]]; then
        echo "  Status     : IDENTICAL"
    else
        echo "  Status     : DIFFERENCES FOUND"

        if [[ ${#ONLY_A[@]} -gt 0 ]]; then
            echo
            echo "  Only on Drive A (${#ONLY_A[@]}) — missing from B:"
            for NAME in "${ONLY_A[@]}"; do
                echo "    < $CATEGORY/$NAME"
            done
        fi

        if [[ ${#ONLY_B[@]} -gt 0 ]]; then
            echo
            echo "  Only on Drive B (${#ONLY_B[@]}) — missing from A:"
            for NAME in "${ONLY_B[@]}"; do
                echo "    > $CATEGORY/$NAME"
            done
        fi
    fi

    echo

    (( TOTAL_ONLY_A += ${#ONLY_A[@]} )) || true
    (( TOTAL_ONLY_B += ${#ONLY_B[@]} )) || true
    (( TOTAL_SHARED += SHARED         )) || true

    unset SET_A
    unset SET_B
done

# ── Overall summary ───────────────────────────────────────────────────────────
echo "════════════════════════════════════════"
echo "  Shared across both drives : $TOTAL_SHARED container(s)"
echo "  Only on Drive A           : $TOTAL_ONLY_A container(s)"
echo "  Only on Drive B           : $TOTAL_ONLY_B container(s)"

if [[ $TOTAL_ONLY_A -eq 0 && $TOTAL_ONLY_B -eq 0 ]]; then
    echo
    echo "  Both drives have identical content."
    echo "════════════════════════════════════════"
    exit 0
else
    echo "════════════════════════════════════════"
    exit 1
fi

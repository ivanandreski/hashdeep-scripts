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

# ── Helper: list sorted container folder names in a directory, one per line ───
list_containers() {
    local DIR="$1"
    if [[ -d "$DIR" ]]; then
        find -L "$DIR" -mindepth 1 -maxdepth 1 -type d -print0 \
            | sort -z \
            | xargs -0 -I{} basename "{}"
    fi
}

# ── Per-category comparison using comm (no associative arrays) ────────────────
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

for CATEGORY in "${CATEGORIES[@]}"; do
    PATH_A="$DRIVE_A/$CATEGORY"
    PATH_B="$DRIVE_B/$CATEGORY"

    list_containers "$PATH_A" > "$WORK_DIR/a.txt"
    list_containers "$PATH_B" > "$WORK_DIR/b.txt"

    COUNT_A="$(wc -l < "$WORK_DIR/a.txt" | tr -d ' ')"
    COUNT_B="$(wc -l < "$WORK_DIR/b.txt" | tr -d ' ')"

    # comm requires sorted input — list_containers produces sorted output
    # -23 = only in A    -13 = only in B    -12 = in both
    ONLY_A="$(comm -23 "$WORK_DIR/a.txt" "$WORK_DIR/b.txt" || true)"
    ONLY_B="$(comm -13 "$WORK_DIR/a.txt" "$WORK_DIR/b.txt" || true)"
    SHARED="$(comm -12 "$WORK_DIR/a.txt" "$WORK_DIR/b.txt" | wc -l | tr -d ' ')"

    COUNT_ONLY_A=0
    [[ -n "$ONLY_A" ]] && COUNT_ONLY_A="$(echo "$ONLY_A" | wc -l | tr -d ' ')"

    COUNT_ONLY_B=0
    [[ -n "$ONLY_B" ]] && COUNT_ONLY_B="$(echo "$ONLY_B" | wc -l | tr -d ' ')"

    echo "━━━  $CATEGORY  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  On Drive A : $COUNT_A container(s)"
    echo "  On Drive B : $COUNT_B container(s)"
    echo "  Shared     : $SHARED"

    if [[ $COUNT_ONLY_A -eq 0 && $COUNT_ONLY_B -eq 0 ]]; then
        echo "  Status     : IDENTICAL"
    else
        echo "  Status     : DIFFERENCES FOUND"

        if [[ $COUNT_ONLY_A -gt 0 ]]; then
            echo
            echo "  Only on Drive A ($COUNT_ONLY_A) — missing from B:"
            while IFS= read -r NAME; do
                echo "    < $CATEGORY/$NAME"
            done <<< "$ONLY_A"
        fi

        if [[ $COUNT_ONLY_B -gt 0 ]]; then
            echo
            echo "  Only on Drive B ($COUNT_ONLY_B) — missing from A:"
            while IFS= read -r NAME; do
                echo "    > $CATEGORY/$NAME"
            done <<< "$ONLY_B"
        fi
    fi

    echo

    (( TOTAL_ONLY_A += COUNT_ONLY_A )) || true
    (( TOTAL_ONLY_B += COUNT_ONLY_B )) || true
    (( TOTAL_SHARED += SHARED       )) || true
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

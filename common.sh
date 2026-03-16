#!/usr/bin/env bash
# common.sh
# Shared bootstrap sourced by generate_hashes.sh, verify_hashes.sh, and
# check_sync.sh. Must NOT be executed directly.
#
# After sourcing, the following variables are available:
#   DRIVE_ROOT  — validated path supplied as $1 by the calling script
#   CATEGORIES  — ("4kMovies" "Movies")
#   HASH_DIR    — $DRIVE_ROOT/hashes
#
# Optional helper functions to call as needed:
#   require_hashdeep   — aborts if hashdeep is not in PATH
#   require_hash_dir   — aborts if $HASH_DIR does not exist yet

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "ERROR: common.sh must be sourced, not executed directly."
    exit 1
fi

# ── Require drive root argument ───────────────────────────────────────────────
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 /path/to/drive/root"
    exit 1
fi

DRIVE_ROOT="$1"
CATEGORIES=("4kMovies" "Movies")
HASH_DIR="$DRIVE_ROOT/hashes"

# ── Validate drive root ───────────────────────────────────────────────────────
if [[ ! -d "$DRIVE_ROOT" ]]; then
    echo "ERROR: Drive root not found: $DRIVE_ROOT"
    echo "       Make sure the drive is mounted, or pass the correct path as an argument."
    exit 2
fi

# ── Optional helpers ──────────────────────────────────────────────────────────

# Call this in scripts that invoke hashdeep
require_hashdeep() {
    if ! command -v hashdeep &>/dev/null; then
        echo "ERROR: hashdeep is not installed or not in PATH."
        echo "       Install it with:  brew install hashdeep"
        exit 1
    fi
}

# Call this in scripts that need an existing hashes/ directory
require_hash_dir() {
    if [[ ! -d "$HASH_DIR" ]]; then
        echo "ERROR: Hashes directory not found: $HASH_DIR"
        echo "       Run generate_hashes.sh first."
        exit 2
    fi
}

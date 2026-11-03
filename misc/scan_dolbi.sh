
#!/usr/bin/env bash

ROOT="${1:-.}"
OUTPUT="dolbi.txt"

DV_LIST=$(mktemp)
HDR10PLUS_LIST=$(mktemp)
HDR_LIST=$(mktemp)
SDR_LIST=$(mktemp)

trap 'rm -f "$DV_LIST" "$HDR10PLUS_LIST" "$HDR_LIST" "$SDR_LIST"' EXIT

TOTAL=0

is_hdr10plus() {
    local trace

    trace=$(ffmpeg -hide_banner -loglevel verbose \
        -i "$1" \
        -map 0:v:0 \
        -c:v copy \
        -bsf:v trace_headers \
        -frames:v 1 \
        -f null - 2>&1)

    grep -qE 'itu_t_t35_country_code.*= 181' <<< "$trace" &&
    grep -qE 'itu_t_t35_payload_byte\[2\].*= 60' <<< "$trace" &&
    grep -qE 'itu_t_t35_payload_byte\[4\].*= 1' <<< "$trace" &&
    grep -qE 'itu_t_t35_payload_byte\[5\].*= 4' <<< "$trace"
}

echo "Scanning: $ROOT"
echo

while IFS= read -r -d '' file; do
    ((TOTAL++))

    probe=$(ffprobe -v error \
        -select_streams v:0 \
        -show_streams \
        -of json "$file" 2>/dev/null)

    metadata=$(jq -c '.streams[0] // {}' <<< "$probe")

    # Dolby Vision
    if grep -qi 'dovi' <<< "$metadata"; then
        printf '%s\n' "$file" >> "$DV_LIST"
        category="Dolby Vision"

    # HDR10+
    elif is_hdr10plus "$file"; then
        printf '%s\n' "$file" >> "$HDR10PLUS_LIST"
        category="HDR10+"

    # HDR10 / HLG
    elif jq -e '
        .color_transfer == "smpte2084" or
        .color_transfer == "arib-std-b67" or
        any(.side_data_list[]?;
            (.side_data_type // "" |
            test("Mastering display|Content light"; "i")))
    ' <<< "$metadata" >/dev/null; then
        printf '%s\n' "$file" >> "$HDR_LIST"
        category="HDR10 / HDR"

    # SDR
    else
        printf '%s\n' "$file" >> "$SDR_LIST"
        category="SDR"
    fi

    printf '[%d] %-14s %s\n' "$TOTAL" "$category" "$file"

done < <(find "$ROOT" -type f \( -iname '*.mkv' -o -iname '*.mp4' \) -print0)

{
    echo "========================================"
    echo "             MOVIE HDR REPORT"
    echo "========================================"
    echo
    echo "Directory: $ROOT"
    echo "Total movies: $TOTAL"
    echo
    printf "Dolby Vision: %s\n" "$(wc -l < "$DV_LIST")"
    printf "HDR10+:       %s\n" "$(wc -l < "$HDR10PLUS_LIST")"
    printf "HDR10 / HDR:  %s\n" "$(wc -l < "$HDR_LIST")"
    printf "SDR:          %s\n" "$(wc -l < "$SDR_LIST")"

    echo
    echo "========================================"
    echo "             DOLBY VISION"
    echo "========================================"
    cat "$DV_LIST"

    echo
    echo "========================================"
    echo "                HDR10+"
    echo "========================================"
    cat "$HDR10PLUS_LIST"

    echo
    echo "========================================"
    echo "              HDR10 / HDR"
    echo "========================================"
    cat "$HDR_LIST"

    echo
    echo "========================================"
    echo "                 SDR"
    echo "========================================"
    cat "$SDR_LIST"

} > "$OUTPUT"

echo
echo "========================================"
echo "Scan complete!"
echo "Report: $OUTPUT"
echo "Movies scanned: $TOTAL"
echo "========================================"

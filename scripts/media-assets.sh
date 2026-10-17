#!/usr/bin/env bash
# Sample media download, shared by bootstrap (scripts/lib/00-common.sh),
# scripts/install-phase-ii and sample-srt-source.sh.
#
# NORSK_ASSET_BASE overrides where the media comes from.

NORSK_ASSET_BASE="${NORSK_ASSET_BASE:-https://assets.norsk.video}"

# fetch_media_asset <file name> <dest dir>
#
# Downloads media-examples/data/<file name> into <dest dir>, unless a
# non-empty copy is already there. The download goes to a temporary name and
# is renamed into place only once complete, so a failed or interrupted
# download never leaves a partial or empty file that later runs would skip.
fetch_media_asset() {
    local -r name=$1
    local -r dir=$2
    local -r target="$dir/$name"
    local -r url="$NORSK_ASSET_BASE/media-examples/data/$name"
    local -r tmp="$target.download.$$"

    if [[ -s "$target" ]]; then
        echo "Already present: $target"
        return 0
    fi

    mkdir -p "$dir"
    echo "Downloading $name"
    if command -v curl > /dev/null 2>&1; then
        curl --fail --silent --show-error -L --retry 3 -o "$tmp" "$url" || { echo "Failed to download $url" >&2; rm -f "$tmp"; return 1; }
    else
        wget --quiet --tries=3 -O "$tmp" "$url" || { echo "Failed to download $url" >&2; rm -f "$tmp"; return 1; }
    fi
    if [[ ! -s "$tmp" ]]; then
        echo "$url came back empty" >&2
        rm -f "$tmp"
        return 1
    fi
    mv -f "$tmp" "$target"
    echo "Downloaded: $target"
}

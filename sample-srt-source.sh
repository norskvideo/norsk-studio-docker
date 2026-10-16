#!/usr/bin/env bash
set -eo pipefail
cd "${0%/*}"

mkdir -p ./data/media
SOURCES_DIR=$(readlink -f ./data/media)

oops() {
    echo "$0:" "$@" >&2
    exit 1
}

if ! command -v curl > /dev/null 2>&1 && ! command -v wget > /dev/null 2>&1; then
    oops "you don't have wget or curl installed, which I need to download the file"
fi


usage() {
    echo "Usage: ${0##*/} <camera1|camera2> <start|stop>"
    echo "  Start a sample SRT source that sends a stream to camera 1 or camera 2 on port 5001"
}

source ./scripts/media-assets.sh

function downloadMediaAsset() {
    fetch_media_asset "$1" "$SOURCES_DIR"
}

main() {
    if [[ $# -ne 2 ]] ; then
        usage
        exit 1
    fi
    local source
    case $1 in
        camera1)
            source="action.mp4"
        ;;
        camera2)
            source="wildlife.ts"
        ;;
        *)
            usage
            exit 1
    esac


    case $2 in
        start)
        ;;
        stop)
        ;;
        *)
            usage
            exit 1
    esac
    local -r action=$2
    local name=$1
    for i in $(docker ps --all --format '{{.Names}}' | grep -e ^sample-srt-$name\$); do
        echo Stopping $i
        docker rm -f $i
        # If we are about to start the source again, back off for a few seconds first
        if [[ $action == "start" ]] ; then
            sleep 5
        fi
    done

    if [[ $action != "start" ]] ; then
        exit 0
    fi

    downloadMediaAsset "$source"
    name=$name source=$source docker compose -p $name -f "yaml/sample-sources/srt-camera.yaml" up -d
}

main "$@"

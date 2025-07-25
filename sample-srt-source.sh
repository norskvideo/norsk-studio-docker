#!/usr/bin/env bash
set -eo pipefail
cd "${0%/*}"

SOURCES_DIR=$(readlink -f ./sources)


if command -v curl > /dev/null 2>&1; then
    fetch() { curl  --silent --fail -L "$1" -o "$2"; }
    elif command -v wget > /dev/null 2>&1; then
    fetch() { wget --quiet "$1" -O "$2"; }
else
    oops "you don't have wget or curl installed, which I need to download the binary tarball"
fi


usage() {
    echo "Usage: ${0##*/} <camera1|camera2> <start|stop>"
    echo "  Start a sample SRT source that sends a stream to camera 1 or camera 2 on port 5001"
}

function downloadMediaAsset() {
    mkdir -p $SOURCES_DIR
    local -r fileName=$1
    local -r target="$SOURCES_DIR/$fileName"
    if [[ ! -f $target ]]; then
        echo "Downloading sample file $target"
        fetch "https://s3.eu-west-1.amazonaws.com/norsk.video/media-examples/data/$fileName" "$target.download"
        mv "$target.download" "$target"
    fi
}

main() {
    if [[ $# -ne 2 ]] ; then
        usage
        exit 1
    fi
    local source
    case $1 in
        camera1)
            source="InkDrop.ts"
        ;;
        camera2)
            source="Weaving.ts"
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

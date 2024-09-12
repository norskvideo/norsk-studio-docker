#!/usr/bin/env bash
set -eo pipefail
cd "${0%/*}"

function main() {
    local i
    local firstTime=true
    for i in $(docker ps --all --format '{{.Names}}' | grep -e ^norsk-); do
        if [ $firstTime == true ]; then
            echo "Stopping running containers:"
            firstTime=false
        fi
        # The sed is just to indent the output
        docker rm -f "$i" | sed 's/^/    /'
    done

    firstTime=true
    for i in $(docker network list --format '{{.Name}}' | grep -e ^norsk-nw); do
        if [ $firstTime == true ]; then
            echo "Deleting network:"
            firstTime=false
        fi
        # The sed is just to indent the output
        docker network rm "$i" | sed 's/^/    /'
    done
}

main "$@"
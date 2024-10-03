#!/usr/bin/env bash
set -eo pipefail
cd "${0%/*}"

export NORSK_MEDIA_IMAGE=norskvideo/norsk:v1.0.380-main
export NORSK_STUDIO_IMAGE=norskvideo/norsk-studio:1.0.381
#export NORSK_STUDIO_IMAGE=norsk-studio:latest

declare NETWORK_MODE_DEFAULT

declare HOST_IP=${HOST_IP:-127.0.0.1}

if [[ "$OSTYPE" == "linux"* ]]; then
    NETWORK_MODE_DEFAULT="host"
else
    NETWORK_MODE_DEFAULT="docker"
fi

LICENSE_FILE="secrets/license.json"

usage() {
    echo "Usage: ${0##*/} [options]"
    echo "  Options:"
    echo "    --network-mode [docker|host] : whether the example should run in host or docker network mode.  Defaults to $NETWORK_MODE_DEFAULT on $OSTYPE"
    echo "    --turn : launch a local turn server"
    echo "    --nvidia : enable nvidia access"
    echo "    --merge filename : build a single compose file from your options"
    echo "    --logs dirname : mount Norsk Media logs to the given directory (path relative to folder containing this up.sh)"
    echo "  Environment variables:"
    echo "    HOST_IP - the IP used for access to this Norsk application. default: 127.0.0.1"
}

realpath() {
    local expanded="${1/#\~/$HOME}"
    echo "$(cd "$(dirname "$expanded")" && pwd)/$(basename "$expanded")"
}

main() {
    local action="up -d"
    local -r licenseFilePath=$(realpath $LICENSE_FILE)
    local networkMode=$NETWORK_MODE_DEFAULT
    local toFile=""

    # Make sure that a license file is in place
    if [[ ! -f  $licenseFilePath ]] ; then
        echo "No license.json file found in $licenseFilePath"
        echo "  See Readme for instructions on how to obtain one."
        exit 1
    fi

    # Verify that we can at least get docker version output
    if ! docker compose version; then
        echo "Docker Compose is not installed on your system"
        echo "Please install it and start the Docker daemon before proceeding"
        echo "You can find the installation instructions at: https://docs.docker.com/get-docker/"
        exit 1
    fi

    local localTurn="false"
    local nvidiaSettings=""
    local logSettings=""
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h | --help)
                usage
                exit 0
            ;;
            --network-mode)
                if [[ "$OSTYPE" == "linux"* ]]; then
                    case "$2" in
                        docker | host)
                            networkMode=$2
                            shift 2
                        ;;
                        *)
                            echo "Unknown network-mode $2"
                            usage
                            exit 1
                        ;;
                    esac
                else
                    echo "network-mode is unsupported on $OSTYPE"
                    usage
                    exit 1
                fi
            ;;
            --turn)
                localTurn="true"
                shift 1
            ;;
            --merge)
                if [ "$#" -le 1 ]; then
                    echo "merge needs an output file specified"
                    usage
                    exit 1
                fi
                action="config"
                toFile="$2"
                shift 2
            ;;
            --logs)
                if [ "$#" -le 1 ]; then
                    echo "need to specify a directory for the logs to be written to"
                    usage
                    exit 1
                fi
                mkdir -p "$2"
                export LOG_ROOT=$(realpath "$2")
                logSettings="-f yaml/volumes/norsk-media-logs.yaml"
                shift 2
            ;;
            --nvidia)
                if [[ "$OSTYPE" == "linux"* ]]; then
                    nvidiaSettings="-f yaml/hardware-devices/nvidia.yaml"
                    shift 1
                else
                    echo "nvidia is unsupported on $OSTYPE"
                    usage
                    exit 1
                fi
            ;;
            *)
                echo "Error: unknown option $1"
                usage
                exit 1
        esac
    done

    local networkDir
    if [[ "$networkMode" == "host" ]]; then
        networkDir="networking/host"
    else
        networkDir="networking/docker"
    fi

    local -r studioSettings="-f yaml/servers/norsk-studio.yaml -f yaml/$networkDir/norsk-studio.yaml"
    local -r norskMediaSettings="-f yaml/servers/norsk-media.yaml -f yaml/$networkDir/norsk-media.yaml"

    local turnSettings=""
    if [[ $localTurn == "true" ]]; then
        turnSettings="-f yaml/servers/turn.yaml -f yaml/$networkDir/turn.yaml"
    fi

    local urlPrefixSettings=""
    if [[ "$HOST_IP" != "127.0.0.1" ]]; then
      urlPrefixSettings="PUBLIC_URL_PREFIX=http://$HOST_IP:8080 "
    fi

    ./down.sh
    # The sed is just to remove multiple spaces when options are blank...
    local cmd=$(echo "${urlPrefixSettings}docker compose $norskMediaSettings $logSettings $studioSettings $turnSettings $nvidiaSettings $action" | sed 's/  \+/ /g')
    echo "Launching with:"
    echo "  $cmd"
    if [[ $toFile == "" ]]; then
        $cmd
        echo "The Norsk Studio UI is available on http://$HOST_IP:8000"
        echo "The Norsk Workflow Visualiser is available on http://$HOST_IP:6791"
    else
        $cmd > "$toFile"
        echo "Combined docker compose file written to $toFile"
    fi
}

main "$@"

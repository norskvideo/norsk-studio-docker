#!/usr/bin/env bash
set -eo pipefail
cd "${0%/*}"

export NORSK_MEDIA_IMAGE=norskvideo/norsk:1.0.402-2025-09-10-38401717
export NORSK_STUDIO_IMAGE=norskvideo/norsk-studio:1.0.402-2025-09-10-38401717

declare NETWORK_MODE_DEFAULT
declare LOCAL_TURN_DEFAULT

declare HOST_IP=${HOST_IP:-127.0.0.1}

if [[ "$OSTYPE" == "linux"* ]]; then
    NETWORK_MODE_DEFAULT="host"
    LOCAL_TURN_DEFAULT=false
else
    NETWORK_MODE_DEFAULT="docker"
    LOCAL_TURN_DEFAULT=true
fi
LICENSE_FILE="secrets/license.json"

usage() {
    echo "Usage: ${0##*/} [options]"
    echo "  Options:"
    echo "    --network-mode [docker|host] : whether the example should run in host or docker network mode.  Defaults to $NETWORK_MODE_DEFAULT on $OSTYPE"
    echo "    --turn [true|false]: launch a local turn server. Defaults to $LOCAL_TURN_DEFAULT on $OSTYPE"
    echo "    --enable-nvidia : enable nvidia access (Linux only)"
    echo "    --enable-quadra : enable quadra access (Linux only)"
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
    local -a envVars

    # Make sure that a license file is in place
    if [[ ! -f  $licenseFilePath ]] ; then
        echo "No license.json file found in $licenseFilePath"
        echo "  See Readme for instructions on how to obtain one."
        exit 1
    fi

    # Check that docker is running
    if ! docker images > /dev/null 2>&1; then
        echo "Either Docker is not installed or I can't run it - is the daemon running and do you have permissions?"
        exit 1
    fi

    # Verify that we can at least get docker version output
    if ! docker compose version; then
        echo "Docker Compose is not installed on your system"
        echo "Please install it and start the Docker daemon before proceeding"
        echo "You can find the installation instructions at: https://docs.docker.com/get-docker/"
        exit 1
    fi

    arch=$(docker info --format '{{ .Architecture }}')

    local localTurn=$LOCAL_TURN_DEFAULT
    local nvidiaSettings=""
    local quadraSettings=""
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
                    echo "network-mode is not supported on $OSTYPE"
                    usage
                    exit 1
                fi
            ;;
            --turn)
                case "$2" in
                    true | false)
                        localTurn=$2
                        shift 2
                    ;;
                    *)
                        echo "--turn must be followed by true or false"
                        usage
                        exit 1
                    ;;
                esac
            ;;
            --merge)
                if [[ "$#" -le 1 ]]; then
                    echo "merge needs an output file specified"
                    usage
                    exit 1
                fi
                action="config"
                toFile="$2"
                shift 2
            ;;
            --logs)
                if [[ "$#" -le 1 ]]; then
                    echo "need to specify a directory for the logs to be written to"
                    usage
                    exit 1
                fi
                mkdir -p "$2"
                export LOG_ROOT=$(realpath "$2")
                logSettings="-f yaml/volumes/norsk-media-logs.yaml"
                shift 2
            ;;
            --enable-nvidia)
                if [[ "$OSTYPE" == "linux"* ]]; then
                    nvidiaSettings="-f yaml/hardware-devices/nvidia.yaml"
                    shift 1
                else
                    echo "nvidia is not supported on $OSTYPE"
                    usage
                    exit 1
                fi
            ;;
            --enable-quadra)
                if [[ "$OSTYPE" == "linux"* ]]; then
                    quadraSettings="-f yaml/hardware-devices/quadra.yaml"
                    shift 1
                else
                    echo "quadra is not supported on $OSTYPE"
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
        if [[ "$networkMode" == "host" ]]; then
            export GLOBAL_ICE_SERVERS='[{"url": "turn:127.0.0.1:3478", "reportedUrl": "turn:'$HOST_IP':3478", "username": "norsk", "credential": "norsk" }, { "url": "turn:127.0.0.1:3478", "reportedUrl": "turn:'$HOST_IP':3478?transport=tcp", "username": "norsk", "credential": "norsk" }]'
        else
            export GLOBAL_ICE_SERVERS='[{"url": "turn:norsk-turn:3478", "reportedUrl": "turn:'$HOST_IP':3478", "username": "norsk", "credential": "norsk" }, { "url": "turn:norsk-turn:3478", "reportedUrl": "turn:'$HOST_IP':3478?transport=tcp", "username": "norsk", "credential": "norsk" }]'
        fi
        envVars+=("GLOBAL_ICE_SERVERS")
    fi

    if [[ "$HOST_IP" != "127.0.0.1" ]]; then
        export PUBLIC_URL_PREFIX="http://$HOST_IP:8080"
        envVars+=("PUBLIC_URL_PREFIX")
    fi

    ./down.sh
    # The sed is just to remove multiple spaces when options are blank...
    local cmd=$(echo "docker compose $norskMediaSettings $logSettings $studioSettings $turnSettings $nvidiaSettings $quadraSettings $action" | sed 's/  \+/ /g')
    echo "Launching with:"
    echo "  $cmd"
    local firstTime=true
    for envVar in "${envVars[@]}"
    do
        if [[ $firstTime == true ]]; then
            echo "Env vars set:"
            firstTime=false
        fi
        echo "   ${envVar}: ${!envVar}"
    done

    if [[ $toFile == "" ]]; then
        eval "$cmd"
        echo "The Norsk Studio UI is available on http://$HOST_IP:8000"
        echo "The Norsk Workflow Visualiser is available on http://$HOST_IP:6791"
    else
        eval "$cmd" > "$toFile"
        echo "Combined docker compose file written to $toFile"
    fi
}

main "$@"

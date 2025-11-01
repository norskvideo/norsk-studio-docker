#!/usr/bin/env bash
set -eo pipefail
cd "${0%/*}"

export NORSK_MEDIA_IMAGE=norskvideo/norsk:1.0.402-2025-09-10-38401717
export NORSK_STUDIO_IMAGE=norskvideo/norsk-studio:1.0.402-2025-09-10-38401717

declare NETWORK_MODE_DEFAULT
declare LOCAL_TURN_DEFAULT
declare IS_WSL=false

declare HOST_IP=${HOST_IP:-127.0.0.1}

# Detect platform and set defaults
if [[ "$OSTYPE" == "linux"* ]]; then
    # Check if running in WSL
    if grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null; then
        IS_WSL=true
        # Check for WSL2 (has proper virtualization)
        if ! grep -qiE 'wsl2' /proc/version; then
            echo "Error: WSL1 detected. Only WSL2 is supported."
            echo "Please upgrade to WSL2: https://docs.microsoft.com/en-us/windows/wsl/install"
            exit 1
        fi
        # WSL2 uses docker networking mode
        NETWORK_MODE_DEFAULT="docker"
        LOCAL_TURN_DEFAULT=true
    else
        # Native Linux uses host mode
        NETWORK_MODE_DEFAULT="host"
        LOCAL_TURN_DEFAULT=false
    fi
else
    # macOS uses docker mode
    NETWORK_MODE_DEFAULT="docker"
    LOCAL_TURN_DEFAULT=true
fi
LICENSE_FILE="secrets/license.json"

usage() {
    echo "Usage: ${0##*/} [options]"
    echo ""
    echo "Start Norsk Studio with Docker Compose"
    echo ""
    echo "Options:"
    echo "  --network-mode [docker|host]"
    echo "      Docker: containers use internal networking (default macOS/WSL2)"
    echo "      Host: containers use host network (default Linux, faster)"
    echo "  --turn [true|false]"
    echo "      Launch local TURN server (default: $LOCAL_TURN_DEFAULT)"
    echo "  --enable-nvidia"
    echo "      Enable NVIDIA GPU (Linux only)"
    echo "  --enable-quadra"
    echo "      Enable Quadra GPU (Linux only)"
    echo "  --logs <dir>"
    echo "      Mount Norsk Media logs to directory"
    echo "  --merge <file>"
    echo "      Generate merged compose file without starting"
    echo ""
    echo "Environment:"
    echo "  HOST_IP - IP/hostname for UI access and stream URLs"
    echo "            On a cloud server it can be set to the public IP"
    echo "            (default: 127.0.0.1)"
    echo ""
    echo "Examples:"
    echo "  ./up.sh"
    echo "  HOST_IP=192.168.1.100 ./up.sh --turn true"
    echo "  HOST_IP=\$(curl -s ifconfig.me) ./up.sh"
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
        echo "Error: No license.json file found at $licenseFilePath"
        echo "  Get a license at: https://docs.norsk.video/studio/latest/getting-started/setup.html"
        exit 1
    fi

    # Check license file is not empty
    if [[ ! -s  $licenseFilePath ]] ; then
        echo "Error: license.json is empty"
        echo "  Get a license at: https://docs.norsk.video/studio/latest/getting-started/setup.html"
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
                local mergeDir=$(dirname "$2")
                if [[ ! -d "$mergeDir" ]]; then
                    echo "Error: Directory does not exist: $mergeDir"
                    exit 1
                fi
                if [[ ! -w "$mergeDir" ]]; then
                    echo "Error: Directory is not writable: $mergeDir"
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
                if ! mkdir -p "$2" 2>/dev/null; then
                    echo "Error: Cannot create logs directory: $2"
                    exit 1
                fi
                if [[ ! -w "$2" ]]; then
                    echo "Error: Logs directory is not writable: $2"
                    exit 1
                fi
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

    # Build docker compose arguments once
    local -a composeArgs=($norskMediaSettings $logSettings $studioSettings $turnSettings $nvidiaSettings $quadraSettings $action)

    echo "Launching with:"
    echo "  docker compose ${composeArgs[*]}"
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
        docker compose "${composeArgs[@]}"
        echo "The Norsk Studio UI is available on http://$HOST_IP:8000"
        echo "The Norsk Workflow Visualiser is available on http://$HOST_IP:6791"
    else
        docker compose "${composeArgs[@]}" > "$toFile"
        echo "Combined docker compose file written to $toFile"
    fi
}

main "$@"

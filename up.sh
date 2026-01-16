#!/usr/bin/env bash
set -eo pipefail
cd "${0%/*}"

# Load container versions
if [[ ! -f versions ]]; then
    echo "Error: versions file not found"
    echo "Reinstall or run './manage.sh --use-containers'"
    exit 1
fi
source versions
export NORSK_MEDIA_IMAGE
export NORSK_STUDIO_IMAGE

# TURN version (not in versions file as manage.sh doesn't manage it)
export COTURN_VERSION=4.6.3-alpine

declare NETWORK_MODE_DEFAULT
declare LOCAL_TURN_DEFAULT

declare HOST_IP=${HOST_IP:-127.0.0.1}

declare LOG_ROOT=${LOG_ROOT:-$PWD/logs}

# Detect platform and set defaults
if [[ "$OSTYPE" == "linux"* ]]; then
    # Check if running in WSL
    if grep -qiE '(microsoft|wsl)' /proc/version 2>/dev/null; then
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
    echo "Simple Mode (auto-configuration):"
    echo "  --host-ip <ip>"
    echo "      Host IP for UI access and stream URLs (default: 127.0.0.1)"
    echo "      Auto-configures PUBLIC_URL_PREFIX and ICE servers"
    echo "  --turn [true|false]"
    echo "      Launch local TURN server (default: $LOCAL_TURN_DEFAULT)"
    echo ""
    echo "Advanced Mode (explicit control, cannot use with --host-ip):"
    echo "  --ice-servers <json>"
    echo "      Explicit ICE servers JSON array"
    echo "  --public-url <url>"
    echo "      Explicit PUBLIC_URL_PREFIX (requires --studio-url)"
    echo "  --studio-url <url>"
    echo "      Explicit STUDIO_URL_PREFIX (requires --public-url)"
    echo ""
    echo "Common Options:"
    echo "  --network-mode [docker|host]"
    echo "      Docker: internal networking (default macOS/WSL2)"
    echo "      Host: host network (default Linux)"
    echo "  --workflow <file>"
    echo "      Load workflow at startup (in data/studio-save-files/)"
    echo "  --overrides <file>"
    echo "      Apply workflow overrides (in data/studio-save-files/)"
    echo "  --enable-nvidia"
    echo "      Enable NVIDIA GPU (Linux/WSL2 only)"
    echo "  --enable-quadra"
    echo "      Enable Quadra GPU (Linux only)"
    echo "  --logs <dir>"
    echo "      Logs directory (default ./logs)"
    echo "  --working-directory <dir>"
    echo "      Custom data directory (default ./data)"
    echo "  --pull-only"
    echo "      Pull container images without starting"
    echo "  --merge <file>"
    echo "      Generate merged compose file without starting"
    echo "  --quiet"
    echo "      Suppress output (for automation)"
    echo "  --no-detach"
    echo "      Run in foreground (e.g., for systemd services)"
    echo ""
    echo "Simple Mode Examples:"
    echo "  ./up.sh"
    echo "  ./up.sh --host-ip 192.168.1.100 --turn true"
    echo "  ./up.sh --host-ip \$(curl -s ifconfig.me) --turn true"
    echo ""
    echo "Advanced Mode Examples:"
    echo "  ./up.sh --public-url 'https://example.com/norsk' \\"
    echo "          --studio-url 'https://example.com/studio' \\"
    echo "          --ice-servers '[{\"url\":\"turn:...\"}]'"
}

realpath() {
    local expanded="${1/#\~/$HOME}"
    echo "$(cd "$(dirname "$expanded")" && pwd)/$(basename "$expanded")"
}

# Validate that a file is in data/studio-save-files/ and return just the filename
validate_studio_file() {
    local file_path="$1"
    local file_type="$2"  # "workflow" or "overrides"
    local file_check="$file_path"
    local data_root="data"

    if [[ ! -z "$DATA_ROOT" ]]; then
        data_root="$DATA_ROOT";
    fi

    # If absolute path, check it resolves to our studio-save-files directory
    if [[ "$file_path" == /* ]]; then
        local abs_studio_save_files="$(cd $data_root/studio-save-files 2>/dev/null && pwd)"
        if [[ "$file_path" == "$abs_studio_save_files"/* ]]; then
            # Absolute path within our studio-save-files, this is OK
            file_check="${file_path#$abs_studio_save_files/}"
        else
            echo "Error: $file_type must be in $data_root/studio-save-files/ directory" >&2
            echo "  Got absolute path: $file_path" >&2
            exit 1
        fi
    # Strip data/studio-save-files/ prefix if present
    elif [[ "$file_path" == $data_root/studio-save-files/* ]]; then
        file_check="${file_path#$data_root/studio-save-files/}"
    elif [[ "$file_path" == */* ]]; then
        # Has path separators but not recognized prefix
        echo "Error: $file_type must be in $data_root/studio-save-files/ directory" >&2
        echo "  Specify just the filename or use $data_root/studio-save-files/ prefix" >&2
        echo "  Got: $file_path" >&2
        exit 1
    fi

    # Check file exists
    if [[ ! -f "$data_root/studio-save-files/$file_check" ]]; then
        echo "Error: $file_type file not found: $data_root/studio-save-files/$file_check" >&2
        exit 1
    fi

    # Return just the filename
    echo "$file_check"
}

main() {
    local action="up -d"
    local -r licenseFilePath=$(realpath $LICENSE_FILE)
    local networkMode=$NETWORK_MODE_DEFAULT
    local toFile=""
    local -a envVars

    local logSettings=""
    local dataSettings=""
    local urlPrefix=""
    local studioUrlPrefix=""
    local studioDocsUrl=""

    # Simple vs advanced mode flags
    local hostIpFlag=""
    local iceServersFlag=""
    local publicUrlFlag=""
    local studioUrlFlag=""
    local pullOnly=false
    local quiet=false
    local noDetach=false

    # Check for help before checking docker
    for arg in "$@"; do
        if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
            usage
            exit 0
        fi
    done

    # Warn about deprecated env vars
    if [[ -n "${HOST_IP:-}" && "$HOST_IP" != "127.0.0.1" ]]; then
        echo "Warning: HOST_IP env var is deprecated, use --host-ip flag instead" >&2
    fi
    if [[ -n "${PUBLIC_URL_PREFIX:-}" ]]; then
        echo "Warning: PUBLIC_URL_PREFIX env var is deprecated, use --public-url flag instead" >&2
    fi
    if [[ -n "${STUDIO_URL_PREFIX:-}" ]]; then
        echo "Warning: STUDIO_URL_PREFIX env var is deprecated, use --studio-url flag instead" >&2
    fi
    if [[ -n "${GLOBAL_ICE_SERVERS:-}" ]]; then
        echo "Warning: GLOBAL_ICE_SERVERS env var is deprecated, use --ice-servers flag instead" >&2
    fi

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
    composeVersion=$(docker compose version 2>&1)
    if [[ $? -ne 0 ]]; then
        echo "Docker Compose is not installed on your system"
        echo "Please install it and start the Docker daemon before proceeding"
        echo "You can find the installation instructions at: https://docs.docker.com/get-docker/"
        exit 1
    fi
    echo "Detected: $composeVersion"

    local localTurn=$LOCAL_TURN_DEFAULT
    local nvidiaSettings=""
    local quadraSettings=""
    local workflow=""
    local overrides=""
    local norskUserSettings=""
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
            --workflow)
                if [[ "$#" -le 1 ]]; then
                    echo "Error: --workflow requires a file path"
                    usage
                    exit 1
                fi
                workflow="$2"
                shift 2
            ;;
            --overrides)
                if [[ "$#" -le 1 ]]; then
                    echo "Error: --overrides requires a file path"
                    usage
                    exit 1
                fi
                overrides="$2"
                shift 2
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
                # if [[ ! -w "$mergeDir" ]]; then
                #     echo "Error: Directory is not writable: $mergeDir"
                #     exit 1
                # fi
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
                export LOG_ROOT=$(realpath "$2")
                shift 2
            ;;
            --working-directory)
                if [[ "$#" -le 1 ]]; then
                    echo "need to specify a directory for the working directory"
                    usage
                    exit 1
                fi
                if [[ ! -d "$2" ]]; then
                    echo "Error: Working directory does not exist: $2"
                    exit 1
                fi
                if [[ ! -r "$2" ]]; then
                    echo "Error: Working directory is not readable: $2"
                    exit 1
                fi
                export DATA_ROOT=$(realpath "$2")
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
            --host-ip)
                if [[ "$#" -le 1 ]]; then
                    echo "Error: --host-ip requires an IP address"
                    usage
                    exit 1
                fi
                hostIpFlag="$2"
                shift 2
            ;;
            --ice-servers)
                if [[ "$#" -le 1 ]]; then
                    echo "Error: --ice-servers requires a JSON array"
                    usage
                    exit 1
                fi
                iceServersFlag="$2"
                shift 2
            ;;
            --public-url)
                if [[ "$#" -le 1 ]]; then
                    echo "Error: --public-url requires a URL"
                    usage
                    exit 1
                fi
                publicUrlFlag="$2"
                shift 2
            ;;
            --studio-url)
                if [[ "$#" -le 1 ]]; then
                    echo "Error: --studio-url requires a URL"
                    usage
                    exit 1
                fi
                studioUrlFlag="$2"
                shift 2
            ;;
            --pull-only)
                pullOnly=true
                shift 1
            ;;
            --quiet)
                quiet=true
                shift 1
            ;;
            --set-norsk-user)
                # Set user/group for hardware access on Linux/WSL2
                # These need to be set as IDs because they are names on the host system, not inside the container
                if [[ -z "${NORSK_USER:-}" ]]; then
                    export NORSK_USER=$(id -u)

                    if [[ -z "${NORSK_GROUP:-}" ]]; then
                        # Prefer the disk group if current user is a member (for hardware access, e.g. Netint Quadra)
                        if id -nG | grep -qw disk; then
                            export NORSK_GROUP=$(getent group disk | cut -d: -f3)
                        else
                            # Otherwise use the default group
                            export NORSK_GROUP=$(id -g)
                        fi
                    fi
                fi
                norskUserSettings="-f yaml/norsk-users.yaml"
                shift 1
            ;;
            --no-detach)
                noDetach=true
                shift 1
            ;;
            *)
                echo "Error: unknown option $1"
                usage
                exit 1
        esac
    done




    # Validate simple vs advanced mode
    if [[ -n "$hostIpFlag" ]]; then
        if [[ -n "$iceServersFlag" || -n "$publicUrlFlag" || -n "$studioUrlFlag" ]]; then
            echo "Error: Cannot use --host-ip with advanced mode flags (--ice-servers, --public-url, --studio-url)"
            usage
            exit 1
        fi
    fi

    # Validate --public-url and --studio-url must be used together
    if [[ -n "$publicUrlFlag" && -z "$studioUrlFlag" ]]; then
        echo "Error: --public-url requires --studio-url"
        usage
        exit 1
    fi
    if [[ -n "$studioUrlFlag" && -z "$publicUrlFlag" ]]; then
        echo "Error: --studio-url requires --public-url"
        usage
        exit 1
    fi

    # Validate --merge and --pull-only are mutually exclusive
    if [[ $pullOnly == true && -n "$toFile" ]]; then
        echo "Error: --pull-only and --merge are mutually exclusive"
        usage
        exit 1
    fi

    # Apply simple mode: use --host-ip or fall back to HOST_IP env var
    if [[ -n "$hostIpFlag" ]]; then
        HOST_IP="$hostIpFlag"
    fi

    # Apply advanced mode flags
    if [[ -n "$iceServersFlag" ]]; then
        export GLOBAL_ICE_SERVERS="$iceServersFlag"
        envVars+=("GLOBAL_ICE_SERVERS")
    fi
    if [[ -n "$publicUrlFlag" ]]; then
        export PUBLIC_URL_PREFIX="$publicUrlFlag"
        envVars+=("PUBLIC_URL_PREFIX")
    fi
    if [[ -n "$studioUrlFlag" ]]; then
        export STUDIO_URL_PREFIX="$studioUrlFlag"
        envVars+=("STUDIO_URL_PREFIX")
    fi

    if [[ $pullOnly == true ]]; then
        action="pull"
    elif [[ $noDetach == true ]]; then
        action="up"
    fi

    # Validate log dirs
    if ! mkdir -p "$LOG_ROOT/norsk-media" "$LOG_ROOT/norsk-studio" 2>/dev/null; then
        echo "Error: Cannot create logs directory: $LOG_ROOT"
        exit 1
    fi
    if [[ ! -w "$LOG_ROOT/norsk-media" || ! -w "$LOG_ROOT/norsk-studio" ]]; then
        echo "Error: Logs directory is not writable: $2"
        exit 1
    fi

    # Validate workflow file - must be in data/studio-save-files/
    local validated_workflow=""
    if [[ -n "$workflow" ]]; then
        validated_workflow=$(validate_studio_file "$workflow" "Workflow")
    fi

    # Validate overrides file - must be in data/studio-save-files/
    local validated_overrides=""
    if [[ -n "$overrides" ]]; then
        validated_overrides=$(validate_studio_file "$overrides" "Overrides")
    fi

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
        # Generate TURN password if not exists
        TURN_PASSWORD_FILE="secrets/turn-password"
        if [[ ! -f "$TURN_PASSWORD_FILE" ]]; then
            mkdir -p secrets
            # Generate 32 character random password
            if command -v openssl > /dev/null 2>&1; then
                openssl rand -base64 24 > "$TURN_PASSWORD_FILE"
            else
                # Fallback: use /dev/urandom
                tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32 > "$TURN_PASSWORD_FILE"
            fi
            echo "Generated TURN password in $TURN_PASSWORD_FILE"
        fi
        export TURN_PASSWORD=$(cat "$TURN_PASSWORD_FILE")

        turnSettings="-f yaml/servers/turn.yaml -f yaml/$networkDir/turn.yaml"
        # Only auto-configure ICE servers if not explicitly set via --ice-servers
        if [[ -z "$iceServersFlag" ]]; then
            if [[ "$networkMode" == "host" ]]; then
                export GLOBAL_ICE_SERVERS='[{"url": "turn:127.0.0.1:3478", "reportedUrl": "turn:'$HOST_IP':3478", "username": "norsk", "credential": "'$TURN_PASSWORD'" }, { "url": "turn:127.0.0.1:3478", "reportedUrl": "turn:'$HOST_IP':3478?transport=tcp", "username": "norsk", "credential": "'$TURN_PASSWORD'" }]'
            else
                export GLOBAL_ICE_SERVERS='[{"url": "turn:norsk-turn:3478", "reportedUrl": "turn:'$HOST_IP':3478", "username": "norsk", "credential": "'$TURN_PASSWORD'" }, { "url": "turn:norsk-turn:3478", "reportedUrl": "turn:'$HOST_IP':3478?transport=tcp", "username": "norsk", "credential": "'$TURN_PASSWORD'" }]'
            fi
        fi
        envVars+=("GLOBAL_ICE_SERVERS")
        envVars+=("TURN_PASSWORD")
    fi

    # Auto-configure PUBLIC_URL_PREFIX if not explicitly set via --public-url
    if [[ "$HOST_IP" != "127.0.0.1" && -z "$publicUrlFlag" ]]; then
        export PUBLIC_URL_PREFIX=${PUBLIC_URL_PREFIX:-"http://$HOST_IP:8080"}
        envVars+=("PUBLIC_URL_PREFIX")
    fi

    if [[ -n "$dataSettings" ]]; then
        envVars+=("DATA_ROOT")
    fi

    # Export workflow and overrides if specified (just the filename)
    if [[ -n "$validated_workflow" ]]; then
        export STUDIO_DOCUMENT="$validated_workflow"
        envVars+=("STUDIO_DOCUMENT")
    fi

    if [[ -n "$validated_overrides" ]]; then
        export STUDIO_DOCUMENT_OVERRIDES="$validated_overrides"
        envVars+=("STUDIO_DOCUMENT_OVERRIDES")
    fi

    ./down.sh

    # Build docker compose arguments once
    local quietFlag=""
    if [[ "$quiet" == true ]]; then
        quietFlag="--quiet"
    fi
    local -a composeArgs=($norskMediaSettings $dataSettings $studioSettings $turnSettings $nvidiaSettings $quadraSettings $norskUserSettings $action $quietFlag)

    echo "Containers:"
    echo "  Media:  ${NORSK_MEDIA_IMAGE#*:}"
    echo "  Studio: ${NORSK_STUDIO_IMAGE#*:}"
    echo ""
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

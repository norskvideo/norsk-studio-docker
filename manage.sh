#!/usr/bin/env bash
set -eo pipefail
cd "${0%/*}"

source scripts/common.sh

TAG_PATTERN='2.*'

usage() {
    echo "Usage: ${0##*/} [options]"
    echo ""
    echo "Manage Norsk Studio releases and container versions"
    echo ""
    echo "Release options:"
    echo "  --current          Show current versions"
    echo "  --list-releases    List available releases"
    echo "  --apply [version]  Update to release (default: latest)"
    echo ""
    echo "Container options:"
    echo "  --list-containers  List available container tags"
    echo "  --use-containers   Set container versions"
    echo "                     media=TAG studio=TAG"
    echo "  --pull             Pull configured containers"
    echo "  --factory-reset    Reset to last installed release"
    echo "                     (danger - discards all local changes, including new files)"
    echo ""
    echo "  -h, --help         Show this help"
    echo ""
    echo "Examples:"
    echo "  ./manage.sh --current"
    echo "  ./manage.sh --list-releases"
    echo "  ./manage.sh --apply 2.0.1"
    echo "  ./manage.sh --list-containers"
    echo "  ./manage.sh --use-containers media=1.0.403-xxx studio=1.27.1-xxx"
    echo "  ./manage.sh --pull"
}

get_current_version() {
    git describe --tags --abbrev=0 2>/dev/null || echo "unknown"
}

get_latest_version() {
    git tag -l "$TAG_PATTERN" | sort | tail -1
}

list_versions() {
    local current=$(get_current_version)
    echo "Available versions:"
    git tag -l "$TAG_PATTERN" | sort | while read -r tag; do
        if [[ "$tag" == "$current" ]]; then
            echo "  $tag (current)"
        else
            echo "  $tag"
        fi
    done
}

check_versions() {
    local current=$(get_current_version)
    local latest=$(get_latest_version)

    echo "Release:"
    echo "  Current: $current"
    echo "  Latest:  $latest"

    if [[ "$current" != "$latest" ]]; then
        echo "  Update available: ./update.sh --apply"
    fi

    echo ""
    echo "Containers:"
    get_container_config .

    # Get defaults from git for comparison
    local default_media default_studio
    default_media=$(git show HEAD:"$VERSIONS_FILE" 2>/dev/null | grep "^NORSK_MEDIA_IMAGE=" | sed 's/.*=//' || true)
    default_studio=$(git show HEAD:"$VERSIONS_FILE" 2>/dev/null | grep "^NORSK_STUDIO_IMAGE=" | sed 's/.*=//' || true)

    if [[ "$NORSK_MEDIA_IMAGE" == "$default_media" ]]; then
        echo "  Media:  ${NORSK_MEDIA_IMAGE#*:} (default)"
    else
        echo "  Media:  ${NORSK_MEDIA_IMAGE#*:} (customized)"
    fi

    if [[ "$NORSK_STUDIO_IMAGE" == "$default_studio" ]]; then
        echo "  Studio: ${NORSK_STUDIO_IMAGE#*:} (default)"
    else
        echo "  Studio: ${NORSK_STUDIO_IMAGE#*:} (customized)"
    fi

    echo ""
    local changes
    changes=$(git status --porcelain)
    if [[ -n "$changes" ]]; then
        echo "Local changes:"
        git status --short
    else
        echo "Local changes: none"
    fi
}

apply_update() {
    local target_version="$1"
    local current=$(get_current_version)

    if [[ -z "$target_version" ]]; then
        target_version=$(get_latest_version)
    fi

    if [[ -z "$target_version" ]]; then
        oops "no versions available"
    fi

    if [[ "$current" == "$target_version" ]]; then
        echo "Already at $target_version"
        return 0
    fi

    echo "This will change the Norsk Studio release from $current to $target_version"
    read -p "Continue? [y/N] " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || exit 1

    # Check for local changes
    local changed_files
    changed_files=$(git status --porcelain | awk '{print $2}')
    if [[ -n "$changed_files" ]]; then
        echo "Local changes detected:"
        git status --short
        echo ""
        echo "Options:"
        echo "  r) Reset - discard modified files"
        echo "  b) Backup - save as .bak files then reset"
        echo "  c) Cancel (see also --factory-reset)"
        read -p "Choice [r/b/c]: " -n 1 -r
        echo
        case $REPLY in
            b|B)
                while IFS= read -r file; do
                    if [[ -f "$file" ]]; then
                        local backup="$file.bak"
                        local i=1
                        while [[ -f "$backup" ]]; do
                            backup="$file.bak.$i"
                            ((i++))
                        done
                        cp "$file" "$backup"
                        echo "Backed up: $file -> $backup"
                    fi
                done <<< "$changed_files"
                git checkout -- .
                ;;
            r|R)
                git checkout -- .
                ;;
            *)
                exit 1
                ;;
        esac
    fi

    # Check for custom container versions
    if [[ -n "$(git diff --name-only $VERSIONS_FILE 2>/dev/null)" ]]; then
        echo "Custom container versions in $VERSIONS_FILE"
        read -p "Reset to release defaults? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git checkout "$VERSIONS_FILE"
        fi
    fi

    echo "Updating $current -> $target_version"
    git fetch --tags --quiet
    git -c advice.detachedHead=false checkout --quiet "$target_version" || oops "failed to checkout $target_version"

    # Pull updated containers
    echo ""
    echo "Pulling containers..."
    source "$VERSIONS_FILE"
    local containers=("$NORSK_MEDIA_IMAGE" "$NORSK_STUDIO_IMAGE")

    for container in "${containers[@]}"; do
        echo "Pulling $container"
        pull "$container"
    done

    echo ""
    echo "Updated to $target_version"
}

list_containers() {
    echo "Norsk Media (norskvideo/norsk):"
    list_docker_tags norsk | sed 's/^/  /'
    echo ""
    echo "Norsk Studio (norskvideo/norsk-studio):"
    list_docker_tags norsk-studio | sed 's/^/  /'
}

use_containers() {
    local media_tag="" studio_tag=""

    for arg in "$@"; do
        case "$arg" in
            media=*)
                media_tag="${arg#media=}"
                ;;
            studio=*)
                studio_tag="${arg#studio=}"
                ;;
            *)
                oops "unknown argument: $arg (expected media=TAG or studio=TAG)"
                ;;
        esac
    done

    if [[ -z "$media_tag" && -z "$studio_tag" ]]; then
        oops "specify at least one of media=TAG or studio=TAG"
    fi

    # Resolve "latest" to most recent tag
    if [[ "$media_tag" == "latest" ]]; then
        media_tag=$(list_docker_tags norsk | head -1)
        echo "Resolved media=latest to $media_tag"
    fi
    if [[ "$studio_tag" == "latest" ]]; then
        studio_tag=$(list_docker_tags norsk-studio | head -1)
        echo "Resolved studio=latest to $studio_tag"
    fi

    # Load current config or defaults
    get_container_config .

    # Update specified values
    if [[ -n "$media_tag" ]]; then
        NORSK_MEDIA_IMAGE="norskvideo/norsk:$media_tag"
    fi
    if [[ -n "$studio_tag" ]]; then
        NORSK_STUDIO_IMAGE="norskvideo/norsk-studio:$studio_tag"
    fi

    # Write versions file
    cat > "$VERSIONS_FILE" << EOF
# Container versions
NORSK_MEDIA_IMAGE=$NORSK_MEDIA_IMAGE
NORSK_STUDIO_IMAGE=$NORSK_STUDIO_IMAGE
EOF

    echo "Updated $VERSIONS_FILE:"
    echo "  Media:  $NORSK_MEDIA_IMAGE"
    echo "  Studio: $NORSK_STUDIO_IMAGE"
}

pull_containers() {
    get_container_config .

    echo "Pulling containers..."
    echo ""
    echo "Pulling $NORSK_MEDIA_IMAGE"
    pull "$NORSK_MEDIA_IMAGE"
    echo ""
    echo "Pulling $NORSK_STUDIO_IMAGE"
    pull "$NORSK_STUDIO_IMAGE"
    echo ""
    echo "Done."
}

factory_reset() {
    local current=$(get_current_version)
    echo "This will reset to $current"
    echo "All local changes will be discarded, including new files."
    read -p "Are you sure? [y/N] " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || exit 1

    git checkout -- .
    git clean -fd
    echo "Reset complete."
}

main() {
    if [[ ! -d .git ]]; then
        oops "not a git repository"
    fi

    if [[ $# -eq 0 ]]; then
        usage
        exit 0
    fi

    local action=""
    local version=""
    local -a container_args=()

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            --current)
                action="current"
                shift
                ;;
            --list-releases)
                action="list-releases"
                shift
                ;;
            --apply)
                action="apply"
                shift
                if [[ $# -gt 0 && ! "$1" =~ ^- ]]; then
                    version="$1"
                    shift
                fi
                ;;
            --list-containers)
                action="list-containers"
                shift
                ;;
            --use-containers)
                action="use-containers"
                shift
                while [[ $# -gt 0 && ! "$1" =~ ^- ]]; do
                    container_args+=("$1")
                    shift
                done
                ;;
            --pull)
                action="pull"
                shift
                ;;
            --factory-reset)
                action="factory-reset"
                shift
                ;;
            *)
                oops "unknown option: $1"
                ;;
        esac
    done

    case $action in
        current)
            git fetch --tags --quiet 2>/dev/null || true
            check_versions
            ;;
        list-releases)
            git fetch --tags --quiet
            list_versions
            ;;
        apply)
            apply_update "$version"
            ;;
        list-containers)
            list_containers
            ;;
        use-containers)
            use_containers "${container_args[@]}"
            ;;
        pull)
            pull_containers
            ;;
        factory-reset)
            factory_reset
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"

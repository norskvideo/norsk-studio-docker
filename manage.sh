#!/usr/bin/env bash
set -eo pipefail
cd "${0%/*}"

source scripts/common.sh

TAG_PATTERN='2.*'

usage() {
    echo "Usage: ${0##*/} [options]"
    echo ""
    echo "Manage Norsk Studio releases, containers, and plugins"
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
    echo "Plugin options:"
    echo "  --list-plugins     List enabled libraries and local plugins"
    echo "  --enable-alpha     Enable alpha features"
    echo "  --disable-alpha    Disable alpha features"
    echo "  --enable-beta      Enable beta features"
    echo "  --disable-beta     Disable beta features"
    echo "  --enable-plugin <name>   Add plugin to library list"
    echo "  --disable-plugin <name>  Remove plugin from library list"
    echo "  --install-plugin <pkg>   Install npm package to plugins directory"
    echo "  --create-plugin <name>   Scaffold a new plugin using SDK"
    echo "  --build-image [--tag TAG]  Build image with plugins installed"
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
    echo "  ./manage.sh --enable-alpha"
    echo "  ./manage.sh --list-plugins"
    echo "  ./manage.sh --enable-plugin my-plugin"
    echo "  ./manage.sh --install-plugin @third-party/some-plugin"
    echo "  ./manage.sh --create-plugin my-plugin"
    echo "  ./manage.sh --build-image --tag myregistry/norsk-studio:custom"
}

get_current_version() {
    git_cmd describe --tags --abbrev=0 2>/dev/null || echo "unknown"
}

get_latest_version() {
    git_cmd tag -l "$TAG_PATTERN" | sort | tail -1
}

list_versions() {
    local current=$(get_current_version)
    local has_changes=""
    if [[ -n "$(git_cmd status --porcelain 2>/dev/null)" ]]; then
        has_changes=" + changes"
    fi

    echo "Available versions:"
    git_cmd tag -l "$TAG_PATTERN" | sort | while read -r tag; do
        if [[ "$tag" == "$current" ]]; then
            echo "  $tag (current$has_changes)"
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
        echo "  Update available: ./manage.sh --apply"
    fi

    echo ""
    echo "Containers:"
    get_container_config .

    # Get defaults from git for comparison
    local default_media default_studio
    default_media=$(git_cmd show HEAD:"$VERSIONS_FILE" 2>/dev/null | grep "^NORSK_MEDIA_IMAGE=" | sed 's/.*=//' || true)
    default_studio=$(git_cmd show HEAD:"$VERSIONS_FILE" 2>/dev/null | grep "^NORSK_STUDIO_IMAGE=" | sed 's/.*=//' || true)

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
    changes=$(git_cmd status --porcelain)
    if [[ -n "$changes" ]]; then
        echo "Local changes:"
        git_cmd status --short
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
    changed_files=$(git_cmd status --porcelain | awk '{print $2}')
    if [[ -n "$changed_files" ]]; then
        echo "Local changes detected:"
        git_cmd status --short
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
                git_cmd checkout -- .
                ;;
            r|R)
                git_cmd checkout -- .
                ;;
            *)
                exit 1
                ;;
        esac
    fi

    # Check for custom container versions
    if [[ -n "$(git_cmd diff --name-only $VERSIONS_FILE 2>/dev/null)" ]]; then
        echo "Custom container versions in $VERSIONS_FILE"
        read -p "Reset to release defaults? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git_cmd checkout "$VERSIONS_FILE"
        fi
    fi

    echo "Updating $current -> $target_version"
    git_cmd fetch --tags --quiet
    git_cmd -c advice.detachedHead=false checkout --quiet "$target_version" || oops "failed to checkout $target_version"

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
    get_container_config .
    local current_media="${NORSK_MEDIA_IMAGE#*:}"
    local current_studio="${NORSK_STUDIO_IMAGE#*:}"

    # Get locally installed images
    local installed_images
    installed_images=$(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null)

    echo "Norsk Media (norskvideo/norsk):"
    list_docker_tags norsk | while read -r tag; do
        local suffix=""
        if [[ "$tag" == "$current_media" ]]; then
            suffix=" (current)"
        fi
        if echo "$installed_images" | grep -q "^norskvideo/norsk:$tag$"; then
            suffix="$suffix (installed)"
        fi
        echo "  $tag$suffix"
    done
    echo ""
    echo "Norsk Studio (norskvideo/norsk-studio):"
    list_docker_tags norsk-studio | while read -r tag; do
        local suffix=""
        if [[ "$tag" == "$current_studio" ]]; then
            suffix=" (current)"
        fi
        if echo "$installed_images" | grep -q "^norskvideo/norsk-studio:$tag$"; then
            suffix="$suffix (installed)"
        fi
        echo "  $tag$suffix"
    done
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

    git_cmd checkout -- .
    git_cmd clean -fd
    echo "Reset complete."
}

# Plugin management functions
CONFIG_FILE="config/default.yaml"

get_enabled_libraries() {
    yq_cmd '.server.library[]' "$CONFIG_FILE" 2>/dev/null
}

library_is_enabled() {
    local name="$1"
    get_enabled_libraries | grep -qxF "$name"
}

enable_library() {
    local name="$1"
    if library_is_enabled "$name"; then
        echo "Already enabled: $name"
        return 0
    fi
    yq_cmd -i '.server.library += ["'"$name"'"]' "$CONFIG_FILE"
    echo "Enabled: $name"
}

disable_library() {
    local name="$1"
    if ! library_is_enabled "$name"; then
        echo "Not enabled: $name"
        return 0
    fi
    yq_cmd -i 'del(.server.library[] | select(. == "'"$name"'"))' "$CONFIG_FILE"
    echo "Disabled: $name"
}

list_plugins() {
    echo "Enabled libraries (in config/default.yaml):"
    get_enabled_libraries | while read -r lib; do
        echo "  $lib"
    done

    echo ""
    echo "Local plugins (in ./plugins/):"
    local found_plugins=false
    if [[ -d plugins ]]; then
        for dir in plugins/*/; do
            [[ -d "$dir" ]] || continue
            [[ -f "$dir/package.json" ]] || continue
            found_plugins=true
            local name
            name=$(node -p "require('./$dir/package.json').name" 2>/dev/null) || continue
            if library_is_enabled "$name"; then
                echo "  $name (enabled)"
            else
                echo "  $name (not in library list)"
            fi
        done
    fi
    if [[ "$found_plugins" == "false" ]]; then
        echo "  (none)"
    fi
}

install_npm_plugin() {
    local package="$1"

    if [[ -z "$package" ]]; then
        oops "package name required"
    fi

    # Create plugins directory if needed
    mkdir -p plugins

    echo "Fetching $package from npm..."

    # Create temp directory for download
    local tmpdir
    tmpdir=$(mktemp -d)
    trap "rm -rf '$tmpdir'" EXIT

    # Use npm pack to download the tarball
    (cd "$tmpdir" && npm pack "$package" --quiet) || oops "failed to fetch $package"

    # Find the tarball (npm pack outputs packagename-version.tgz)
    local tarball
    tarball=$(ls "$tmpdir"/*.tgz 2>/dev/null | head -1)
    if [[ -z "$tarball" ]]; then
        oops "no tarball found after npm pack"
    fi

    # Extract to get the package name from package.json
    tar -xzf "$tarball" -C "$tmpdir"

    local pkg_name
    pkg_name=$(node -p "require('$tmpdir/package/package.json').name" 2>/dev/null)
    if [[ -z "$pkg_name" ]]; then
        oops "could not read package name"
    fi

    # Determine target directory
    # Handle scoped packages: @scope/name -> plugins/@scope/name
    local target_dir="plugins/$pkg_name"
    if [[ "$pkg_name" == @*/* ]]; then
        local scope="${pkg_name%/*}"
        mkdir -p "plugins/$scope"
    fi

    # Check if already installed
    if [[ -d "$target_dir" ]]; then
        echo "Plugin already exists at $target_dir"
        read -p "Overwrite? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$target_dir"
        else
            exit 1
        fi
    fi

    # Move package to plugins directory
    mv "$tmpdir/package" "$target_dir"

    # Install dependencies
    echo "Installing dependencies..."
    (cd "$target_dir" && npm install --production --quiet) || oops "failed to install dependencies"

    echo "Installed to $target_dir"

    # Enable in config
    enable_library "$pkg_name"
}

create_plugin() {
    local name="$1"

    if [[ -z "$name" ]]; then
        oops "plugin name required"
    fi

    # Check if plugin already exists
    if [[ -d "plugins/$name" ]]; then
        oops "plugin already exists: plugins/$name"
    fi

    # Create plugins directory if needed
    mkdir -p plugins

    get_container_config .

    echo "Scaffolding plugin '$name' using SDK..."
    docker run --rm \
        -v "$PWD/plugins:/plugins" \
        "$NORSK_STUDIO_IMAGE" \
        npx studio-plugin create "/plugins/$name" || oops "failed to scaffold plugin"

    echo ""
    echo "Created plugins/$name"
    echo ""
    echo "Next steps:"
    echo "  cd plugins/$name"
    echo "  npm install"
    echo "  npm run build"
    echo "  cd ../.."
    echo "  ./manage.sh --enable-plugin $name"
    echo "  ./up.sh"
}

build_plugin_image() {
    local tag="${1:-norsk-studio:with-plugins}"
    local dockerfile=".plugin-build.Dockerfile"

    # Check for local plugins
    local has_plugins=false
    if [[ -d plugins ]]; then
        for dir in plugins/*/; do
            [[ -d "$dir" ]] || continue
            [[ -f "$dir/package.json" ]] || continue
            has_plugins=true
            break
        done
    fi

    if [[ "$has_plugins" == "false" ]]; then
        echo "No local plugins found in ./plugins/"
        echo "The built image would be identical to the base image."
        read -p "Continue anyway? [y/N] " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]] || exit 1
    fi

    get_container_config .

    # Generate Dockerfile
    cat > "$dockerfile" << EOF
FROM $NORSK_STUDIO_IMAGE

# Copy local plugins
COPY plugins/ /usr/src/app/plugins/

# Install each plugin
EOF

    # Add npm install for each plugin
    # Use --legacy-peer-deps to handle nightly version peer dependency mismatches
    for dir in plugins/*/; do
        [[ -d "$dir" ]] || continue
        [[ -f "$dir/package.json" ]] || continue
        local dirname
        dirname=$(basename "$dir")
        echo "RUN npm install --legacy-peer-deps ./plugins/$dirname" >> "$dockerfile"
    done

    echo "Building image: $tag"
    echo ""
    docker build -f "$dockerfile" -t "$tag" .
    local build_status=$?

    # Cleanup
    rm -f "$dockerfile"

    if [[ $build_status -eq 0 ]]; then
        echo ""
        echo "Built: $tag"
        echo "Push with: docker push $tag"
    else
        oops "build failed"
    fi
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
    local plugin_name=""
    local image_tag=""

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
            --list-plugins)
                action="list-plugins"
                shift
                ;;
            --enable-alpha)
                action="enable-alpha"
                shift
                ;;
            --disable-alpha)
                action="disable-alpha"
                shift
                ;;
            --enable-beta)
                action="enable-beta"
                shift
                ;;
            --disable-beta)
                action="disable-beta"
                shift
                ;;
            --enable-plugin)
                action="enable-plugin"
                shift
                if [[ $# -eq 0 || "$1" =~ ^- ]]; then
                    oops "--enable-plugin requires a plugin name"
                fi
                plugin_name="$1"
                shift
                ;;
            --disable-plugin)
                action="disable-plugin"
                shift
                if [[ $# -eq 0 || "$1" =~ ^- ]]; then
                    oops "--disable-plugin requires a plugin name"
                fi
                plugin_name="$1"
                shift
                ;;
            --install-plugin)
                action="install-plugin"
                shift
                if [[ $# -eq 0 || "$1" =~ ^- ]]; then
                    oops "--install-plugin requires a package name"
                fi
                plugin_name="$1"
                shift
                ;;
            --create-plugin)
                action="create-plugin"
                shift
                if [[ $# -eq 0 || "$1" =~ ^- ]]; then
                    oops "--create-plugin requires a plugin name"
                fi
                plugin_name="$1"
                shift
                ;;
            --build-image)
                action="build-image"
                shift
                ;;
            --tag)
                if [[ $# -lt 2 ]]; then
                    oops "--tag requires a value"
                fi
                image_tag="$2"
                shift 2
                ;;
            *)
                oops "unknown option: $1"
                ;;
        esac
    done

    case $action in
        current)
            git_cmd fetch --tags --quiet 2>/dev/null || true
            check_versions
            ;;
        list-releases)
            git_cmd fetch --tags --quiet
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
        list-plugins)
            list_plugins
            ;;
        enable-alpha)
            enable_library "@norskvideo/norsk-studio-alpha"
            ;;
        disable-alpha)
            disable_library "@norskvideo/norsk-studio-alpha"
            ;;
        enable-beta)
            enable_library "@norskvideo/norsk-studio-beta"
            ;;
        disable-beta)
            disable_library "@norskvideo/norsk-studio-beta"
            ;;
        enable-plugin)
            enable_library "$plugin_name"
            ;;
        disable-plugin)
            disable_library "$plugin_name"
            ;;
        install-plugin)
            install_npm_plugin "$plugin_name"
            ;;
        create-plugin)
            create_plugin "$plugin_name"
            ;;
        build-image)
            build_plugin_image "$image_tag"
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"

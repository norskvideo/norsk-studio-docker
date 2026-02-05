#!/bin/sh
# Link local plugins into node_modules for development
# Runs at container startup before studio-editor
#
# Plugins in /usr/src/app/plugins/ are symlinked into node_modules,
# allowing fast development iteration without rebuilding the container.
#
# Supports both regular packages (plugins/my-plugin/) and
# scoped packages (plugins/@scope/my-plugin/).

set -e

PLUGINS_DIR="/usr/src/app/plugins"
NODE_MODULES="/usr/src/app/node_modules"

# Exit early if no plugins directory
if [ ! -d "$PLUGINS_DIR" ]; then
    exit 0
fi

# Exit early if plugins directory is empty
if [ -z "$(ls -A "$PLUGINS_DIR" 2>/dev/null)" ]; then
    exit 0
fi

# Track if we linked anything
linked_count=0

# Function to link a single plugin directory
link_plugin() {
    plugin_dir="$1"

    # Skip if not a directory
    [ -d "$plugin_dir" ] || return 0

    # Skip if no package.json
    if [ ! -f "$plugin_dir/package.json" ]; then
        return 0
    fi

    # Get package name from package.json
    name=$(node -p "require('$plugin_dir/package.json').name" 2>/dev/null)
    if [ -z "$name" ] || [ "$name" = "undefined" ]; then
        echo "Warning: Skipping $plugin_dir - could not read package name" >&2
        return 0
    fi

    # Handle scoped packages (@scope/name -> node_modules/@scope/name)
    if echo "$name" | grep -q "^@"; then
        scope=$(echo "$name" | cut -d'/' -f1)
        mkdir -p "$NODE_MODULES/$scope"
    fi

    # Create symlink (remove existing first)
    target="$NODE_MODULES/$name"
    if [ -L "$target" ]; then
        rm "$target"
    elif [ -e "$target" ]; then
        echo "Warning: $target exists and is not a symlink, skipping" >&2
        return 0
    fi

    # Use absolute path for symlink target
    abs_plugin_dir=$(cd "$plugin_dir" && pwd)
    ln -s "$abs_plugin_dir" "$target"
    echo "Linked plugin: $name"
    linked_count=$((linked_count + 1))
}

# Link regular packages (plugins/my-plugin/)
for plugin_dir in "$PLUGINS_DIR"/*/; do
    # Skip scope directories (handled below)
    case "$plugin_dir" in
        "$PLUGINS_DIR"/@*/) continue ;;
    esac
    link_plugin "$plugin_dir"
done

# Link scoped packages (plugins/@scope/my-plugin/)
for plugin_dir in "$PLUGINS_DIR"/@*/*/; do
    link_plugin "$plugin_dir"
done

if [ "$linked_count" -gt 0 ]; then
    echo "Linked $linked_count plugin(s)"
fi

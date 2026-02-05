#!/bin/sh
# Link local plugins into node_modules for development
# Runs at container startup before studio-editor
#
# Plugins in /usr/src/app/plugins/ are symlinked into node_modules,
# allowing fast development iteration without rebuilding the container.

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

for plugin_dir in "$PLUGINS_DIR"/*/; do
    # Skip if not a directory (handles case where glob doesn't match)
    [ -d "$plugin_dir" ] || continue

    # Skip if no package.json
    if [ ! -f "$plugin_dir/package.json" ]; then
        echo "Warning: Skipping $plugin_dir - no package.json" >&2
        continue
    fi

    # Get package name from package.json
    name=$(node -p "require('$plugin_dir/package.json').name" 2>/dev/null)
    if [ -z "$name" ] || [ "$name" = "undefined" ]; then
        echo "Warning: Skipping $plugin_dir - could not read package name" >&2
        continue
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
        continue
    fi

    # Use absolute path for symlink target
    abs_plugin_dir=$(cd "$plugin_dir" && pwd)
    ln -s "$abs_plugin_dir" "$target"
    echo "Linked plugin: $name"
    linked_count=$((linked_count + 1))
done

if [ "$linked_count" -gt 0 ]; then
    echo "Linked $linked_count plugin(s)"
fi

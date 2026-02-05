# Local Plugins Directory

Place local plugin directories here for development.

## Development Workflow

1. Create a plugin using the SDK scaffolding:
   ```bash
   cd plugins
   npx @norskvideo/norsk-studio-sdk create my-plugin
   ```

2. Enable the plugin in config:
   ```bash
   ./manage.sh --enable-plugin my-plugin
   ```

3. Start Studio - plugins are automatically symlinked:
   ```bash
   ./up.sh
   ```

4. Edit plugin code and restart to see changes:
   ```bash
   ./down.sh && ./up.sh
   ```

## Installing NPM Plugins

To install a plugin from npm:

```bash
# Download and extract to plugins directory
./manage.sh --install-plugin @third-party/some-plugin

# Enable it
./manage.sh --enable-plugin @third-party/some-plugin

# Start Studio
./up.sh
```

This fetches the package from npm and extracts it to `plugins/`, where it's
treated like a local plugin (symlinked at startup).

## Production Deployment

To build a deployable image with plugins baked in:

```bash
./manage.sh --build-image --tag myregistry/norsk-studio:with-plugins
docker push myregistry/norsk-studio:with-plugins
```

The production image has plugins properly npm installed (not symlinked),
so no plugins mount is needed when deploying.

## Plugin Structure

Each plugin directory should contain:
- `package.json` with a valid `name` field
- Built server code in `lib/`
- Built client code in `client/`
- Optional UI bundle in `ui/`

See the SDK documentation for full plugin development details.

# Unification Plan

## Goal
Unify manual (up.sh) and cloud (norsk-containers.sh) deployment paths by making up.sh the single source of truth.

## Current State

**Deployment Paths:**
1. **Manual (up.sh)**: Interactive dev use, platform detection, flexible flags
2. **Cloud (norsk-containers.sh)**: Host mode, TURN, ICE servers, env-driven config
3. **Support (support-containers.sh)**: nginx + oauth2 proxy (cloud only) - OUT OF SCOPE

**Key Duplications:**
- TURN/ICE server config (identical logic in both)
- Hardware setup (quadra/nvidia user/group)
- URL prefix environment variables
- Compose file merging

**Files Referencing norsk-containers.sh:**
- deployed/systemd/norsk.service:10-11
- scripts/akamai_stack_script.sh:56
- scripts/akamai_quadra_stack_script.sh:56,90
- scripts/oracle_cloud_bootstrap.sh:58

## Decisions

1. **Logs**: Keep in up.sh --logs handling
2. **TURN**: Auto-add Google STUN fallback when --host-ip != 127.0.0.1
3. **Versions**: Unify to ./versions (move from deployed/versions)
4. **Hardware**: Extract "quadra"/"nvidia" from DEPLOY_HARDWARE path → --enable-X
5. **Support containers**: Keep separate (out of scope)
6. **Pull**: Expose action param - `./up.sh pull` for pre-pulling images
7. **Backward compat**: Breaking change OK, delete deployed/start.sh
8. **Simple vs Advanced**: Two modes - simple uses --host-ip with auto-config, advanced uses explicit flags
9. **Env vars**: Deprecate HOST_IP, PUBLIC_URL_PREFIX, STUDIO_URL_PREFIX, GLOBAL_ICE_SERVERS env vars in favor of flags

## Implementation

### 1. up.sh Changes

**Simple vs Advanced Modes:**

**Simple mode (auto-configuration):**
```bash
./up.sh                                    # localhost, no TURN
./up.sh --host-ip 1.2.3.4 --turn true     # Auto: PUBLIC_URL_PREFIX, ICE servers with reportedUrl
```
- `--host-ip` replaces `HOST_IP` env var
- `--turn true` auto-calculates ICE servers with reportedUrl
- Auto-appends Google STUN when --host-ip != 127.0.0.1
- Auto-sets PUBLIC_URL_PREFIX=http://<host-ip>:8080

**Advanced mode (explicit control):**
```bash
./up.sh \
  --url-prefix 'https://example.com/norsk' \
  --studio-url-prefix '/studio' \
  --ice-servers '[...]'
```
- Full manual control, no auto-calculation
- `--studio-url-prefix` requires `--url-prefix` (error if missing)
- Cannot mix with `--host-ip` (mutual exclusion, error if both)

**Add flags:**
- `--host-ip <ip>`: Set host IP for simple mode (replaces HOST_IP env var)
- `--ice-servers <json>`: Explicit ICE servers (advanced mode)
- `--url-prefix <url>`: Explicit PUBLIC_URL_PREFIX (advanced mode)
- `--studio-url-prefix <path>`: Explicit STUDIO_URL_PREFIX (advanced mode, requires --url-prefix)

**Validation:**
- Error if `--host-ip` + any advanced flag
- Error if `--studio-url-prefix` without `--url-prefix`

**Add --pull-only flag:**
Pull container images without starting (for bootstrap scripts)
- Calculates compose files based on flags
- Runs `docker compose ... pull` instead of `up -d`
- Bootstrap scripts call `./up.sh --pull-only` (via wrapper)

**Update usage text with simple vs advanced examples**

**Deprecate env vars:**
- `HOST_IP` → use `--host-ip`
- `PUBLIC_URL_PREFIX` → use `--url-prefix`
- `STUDIO_URL_PREFIX` → use `--studio-url-prefix`
- `GLOBAL_ICE_SERVERS` → use `--ice-servers`

### 2. Versions Unification

Move `deployed/versions` → `./versions`
- norsk-containers.sh already sources deployed/versions:3
- After move, both scripts source ./versions

### 3. deployed/norsk-containers.sh Rewrite

Thin wrapper that:
1. Sources norsk-config.sh
2. Calculates ICE servers with STUN fallback
3. Extracts hardware type from DEPLOY_HARDWARE path
4. Translates old interface (pull/up/down args) to new flags
5. Calls up.sh with cloud-specific flags

```bash
#!/usr/bin/env bash
source "$(dirname "$0")/norsk-config.sh"
cd "$(dirname "$0")/.." || exit 1

# Calculate ICE with STUN fallback
ice_servers='[
  {"url": "turn:127.0.0.1:3478", "reportedUrl": "turn:'$DEPLOY_PUBLIC_IP':3478", "username": "norsk", "credential": "norsk"},
  {"url": "turn:127.0.0.1:3478", "reportedUrl": "turn:'$DEPLOY_PUBLIC_IP':3478?transport=tcp", "username": "norsk", "credential": "norsk"},
  {"url": "stun:127.0.0.1:3478", "reportedUrl": "stun:stun.l.google.com:19302"}
]'

# Extract hardware type
hw_flag=""
if [[ "$DEPLOY_HARDWARE" == *"quadra"* ]]; then
  hw_flag="--enable-quadra"
elif [[ "$DEPLOY_HARDWARE" == *"nvidia"* ]]; then
  hw_flag="--enable-nvidia"
fi

# Translate old interface
action=""
if [[ "${1:-}" == "pull" ]]; then
  action="--pull-only"
  shift
elif [[ "${1:-}" == "down" ]]; then
  exec ./down.sh
fi

# Call up.sh
./up.sh \
  --network-mode host \
  --ice-servers "$ice_servers" \
  --url-prefix "${PUBLIC_URL_PREFIX:-https://$DEPLOY_HOSTNAME/norsk}" \
  --studio-url-prefix "${STUDIO_URL_PREFIX:-/studio}" \
  $hw_flag \
  $action \
  "$@"
```

### 4. File Operations

- Delete deployed/start.sh (no longer needed)
- systemd/norsk.service already calls norsk-containers.sh (no change needed)
- Cloud bootstrap scripts already call norsk-containers.sh (no change needed)

## Testing

1. Manual workflow: `./up.sh` with various flags ✅
   - `./up.sh --help` works
   - `--host-ip` + advanced flags = error (mutual exclusion) ✅
   - `--studio-url-prefix` without `--url-prefix` = error ✅
   - `--pull-only` correctly sets action to "pull" ✅
2. Cloud workflow: `deployed/norsk-containers.sh pull/up/down` - Needs testing
3. Verify systemd service still works - Needs testing
4. Check versions file sourcing works from both paths - Needs testing

## Implementation Status

✅ **Completed:**
- Deprecation warnings for env vars (HOST_IP, PUBLIC_URL_PREFIX, STUDIO_URL_PREFIX, GLOBAL_ICE_SERVERS)
- Simple mode: `--host-ip` flag with auto-config
- Advanced mode flags: `--ice-servers`, `--url-prefix`, `--studio-url-prefix`
- Validation: mutual exclusion and requirements
- `--pull-only` flag
- Updated usage text with examples
- Versions unification (./versions for norsk/coturn, deployed/versions for nginx/oauth2)
- Rewritten deployed/norsk-containers.sh as thin wrapper
- Deleted deployed/start.sh

⏳ **Pending:**
- Test cloud deployment workflow
- Verify systemd service compatibility
- Update bootstrap scripts if needed

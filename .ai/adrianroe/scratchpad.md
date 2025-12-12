# Norsk Studio Installation Refactoring

## Background and Motivation

Current state: installation logic scattered across multiple cloud-specific stackscripts with heavy duplication. Makes maintenance difficult, testing impossible, and adding new platforms (NVIDIA hardware, AWS EC2, etc.) requires copying entire scripts.

Goal: centralize installation logic in repo, make stackscripts minimal bootstrappers, enable shared logic across hardware profiles and cloud platforms.

## Key Challenges and Analysis

### Current Architecture Issues

1. **Duplication Across Stackscripts**
   - Lines 18-63 identical in akamai_stack_script.sh and akamai_quadra_stack_script.sh
   - Oracle bootstrap has similar duplicated logic
   - Each new platform requires copying ~50+ lines

2. **Hardware Logic Embedded in Cloud Scripts**
   - Quadra setup (lines 66-101) is 35 lines of Netint-specific logic
   - No separation between "cloud provider setup" vs "hardware setup"
   - NVIDIA support would require yet another duplicate stackscript

3. **Existing Modularity**
   - `deployed/` dir already has platform detection (detect.sh)
   - Platform-specific configs in deployed/{Google,Linode,local,Oracle}/norsk-config.sh
   - Common functions exist in scripts/common.sh but not used by stackscripts
   - Systemd services already modular (norsk-setup.service, norsk.service, nginx.service)

4. **Testing Gap**
   - Can't test stackscripts locally - they're designed for cloud-init
   - Changes require deploying to cloud to verify
   - No way to validate before committing

### Hardware Requirements Analysis

**Quadra (Netint):**
- External dependencies: Quadra_V5.2.0.zip, yasm-1.3.0.tar.gz
- System packages: pkg-config, gcc, ninja-build, python3-pip, flex, bison, libpng-dev, zlib1g-dev, gnutls-bin, uuid-runtime, uuid-dev, libglib2.0-dev, libxml2, libxml2-dev
- Build steps: yasm compile, libxcoder build
- Runtime: init_rsrc via nilibxcoder.service, user in disk group
- Config: DEPLOY_HARDWARE="quadra" env var

**NVIDIA (future):**
- TBD: NVIDIA driver install, container runtime config, device access

**None (software-only):**
- No additional setup

### Cloud Platform Differences

**Linode:**
- Public IP: `ip addr show eth0 | grep "inet\b" | awk '{print $2}' | cut -d/ -f1`
- UDF vars: NORSK_LICENSE, STUDIO_PASSWORD, DOMAIN_NAME, CERTBOT_EMAIL
- Branch: currently git-mgt (should be configurable)

**Google:**
- Public IP: metadata service
- Config: metadata attributes
- Branch: deployed

**Oracle:**
- Public IP: checkip.amazonaws.com
- Manual vendor file: deployed/vendor
- Iptables rules modification
- OAuth2 disabled by default

**Local/Dev:**
- Localhost defaults
- Port forwarding support
- No cert generation

## High-level Task Breakdown

### Phase 1: Create Unified Bootstrap Script Framework
- [ ] Create `scripts/bootstrap.sh` main orchestrator with argument parsing (--hardware, --platform, --license, --password, --domain, --certbot-email, --branch, --install-dir)
- [ ] Create `scripts/lib/` directory for shared modules
- [ ] Move common logic from stackscripts into `scripts/lib/00-common.sh` (docker install, user creation, deps)
- [ ] Create `scripts/lib/10-secrets.sh` for license and password setup
- [ ] Create `scripts/lib/20-platform.sh` for platform-specific config generation
- [ ] Create `scripts/lib/30-containers.sh` for docker pull operations
- [ ] Success: bootstrap.sh exists, sources modules, validates args, unattended operation

### Phase 2: Hardware Profile System
- [ ] Create `scripts/hardware/` directory
- [ ] Extract Quadra logic to `scripts/hardware/quadra.sh` (dependency check, download, build, usermod, systemd service setup)
- [ ] Create `scripts/hardware/none.sh` (empty/noop)
- [ ] Create `scripts/hardware/nvidia.sh` (stub for future)
- [ ] Add hardware profile detection/validation to bootstrap.sh
- [ ] Success: each hardware profile is self-contained, can be sourced independently

### Phase 3: Platform Config Unification
- [ ] Audit differences between platform configs (Linode, Google, Oracle, local)
- [ ] Create `scripts/platforms/` directory with linode.sh, google.sh, oracle.sh, local.sh
- [ ] Each platform script exports: get_public_ip(), get_config_vars(), platform_specific_setup()
- [ ] Migrate inline cat heredocs from stackscripts to platform modules
- [ ] Success: all platform-specific logic extracted from stackscripts

### Phase 4: Minimize Stackscripts
- [ ] Rewrite akamai_stack_script.sh to 10-15 lines (git clone, run bootstrap.sh with params)
- [ ] Rewrite akamai_quadra_stack_script.sh similarly
- [ ] Rewrite oracle_cloud_bootstrap.sh similarly
- [ ] Update git branch references (keep --branch flag in bootstrap.sh)
- [ ] Success: stackscripts are minimal bootstrappers under 20 lines each

### Phase 5: Testing Infrastructure
- [ ] Create `test/install/` directory
- [ ] Add test harness that can run bootstrap.sh in docker container
- [ ] Mock hardware detection for testing profiles
- [ ] Add CI integration (optional)
- [ ] Success: can test bootstrap.sh locally without cloud deployment

### Phase 6: Documentation & Migration
- [ ] Document bootstrap.sh usage and parameters
- [ ] Update README with new installation flow
- [ ] Document how to add new hardware profiles
- [ ] Document how to add new cloud platforms
- [ ] Success: clear docs for maintainers and future contributors

## Project Status Board

### Phase 1: Create Unified Bootstrap Script Framework ✓
- [x] Create scripts/bootstrap.sh main orchestrator
- [x] Create scripts/lib/ directory structure
- [x] Implement 00-common.sh (docker, user, deps)
- [x] Implement 10-secrets.sh (license, password)
- [x] Implement 20-platform.sh (config generation)
- [x] Implement 30-containers.sh (docker pulls)
- [x] Test bootstrap.sh argument parsing

### Phase 2: Hardware Profile System ✓
- [x] Create scripts/hardware/ directory
- [x] Extract quadra.sh from stackscript
- [x] Create none.sh profile
- [x] Create nvidia.sh stub
- [x] Integrate hardware selection into bootstrap.sh (already in bootstrap.sh)

### Phase 3: Platform Config Unification ✓
- [x] Create scripts/platforms/ directory
- [x] Implement linode.sh
- [x] Implement google.sh
- [x] Implement oracle.sh
- [x] Implement local.sh

### Phase 4: Minimize Stackscripts ✓
- [x] Rewrite akamai_stack_script.sh
- [x] Rewrite akamai_quadra_stack_script.sh
- [x] Rewrite oracle_cloud_bootstrap.sh

### Phase 5: Testing Infrastructure ✓
- [x] Create test/install/ framework
- [x] Add docker-based test runner
- [x] Add hardware profile mocking

### Phase 6: Documentation
- [ ] Write bootstrap.sh usage docs
- [ ] Update main README
- [ ] Document extension points

## Executor's Feedback or Assistance Requests

**Phase 1 complete**
- Created bootstrap.sh with arg parsing, validation, module loading
- Created lib modules: 00-common (docker/user/deps), 10-secrets (license/password), 20-platform (config), 30-containers (pulls)
- Arg parsing tested and validated

**Phase 3 complete**
- Created scripts/platforms/ directory
- Implemented linode.sh (IP from eth0, UDF vars)
- Implemented google.sh (IP from metadata, reads domain/email from metadata)
- Implemented oracle.sh (IP from checkip.amazonaws.com, iptables TODO, oauth2 matches Linode)
- Implemented local.sh (localhost, port forwarding support)
- All platform scripts generate norsk-config.sh in deployed/{Platform}/

**Phase 2 complete**
- Created scripts/hardware/ directory
- Extracted quadra.sh (downloads, builds libxcoder, usermod disk group, systemd service)
- Created none.sh (noop for software-only)
- Created nvidia.sh (stub with TODO, exits with error)
- Hardware integration already present in bootstrap.sh (lines 160-166)

**Phase 4 complete**
- Rewrote akamai_stack_script.sh: 64 lines → 36 lines (docker, git, clone, bootstrap.sh call)
- Rewrote akamai_quadra_stack_script.sh: 108 lines → 44 lines (includes media downloads, bootstrap.sh --hardware=quadra)
- Rewrote oracle_cloud_bootstrap.sh: 72 lines → 37 lines (bootstrap.sh call)
- All stackscripts now minimal bootstrappers calling scripts/bootstrap.sh

**Phase 4 enhancements complete**
- Unified akamai_stack_script.sh and akamai_quadra_stack_script.sh into single script
- Added hardware UDF (auto/none/quadra), auto-detection via lspci
- Moved media downloads to 00-common.sh with --download-media flag
- Removed Docker install from stackscripts (now only in 00-common.sh)
- Stackscripts now minimal: git install, clone, run bootstrap.sh
- Deleted akamai_quadra_stack_script.sh

**Phase 5 complete**
- Created test/install/ framework with README
- Created test-args.sh (validates parsing, checks file existence)
- Created Dockerfile.test and test-docker.sh (Ubuntu container tests)
- Created mock-hardware/{quadra,nvidia}.sh for testing without hardware
- Tests validate: arg parsing, help output, module syntax, file existence

**Ready for Phase 6** (documentation)?

---

## AWS EC2 Platform Extension

**Goal:** Extend refactored bootstrap framework to support EC2 deployments with Terraform IaC.

### Implementation Complete

**Platform Module** (`scripts/platforms/aws.sh`):
- IMDSv2 token-based metadata access (secure)
- Public IP from `http://169.254.169.254/latest/meta-data/public-ipv4`
- Generates `deployed/AWS/norsk-config.sh`
- Writes vendor file for detection

**Hardware Detection** (`scripts/bootstrap.sh:116-134`):
- Extended auto-detection: `lspci | grep -iq nvidia` for GPU
- Mirrors Quadra pattern (`lspci | grep -iq netint`)
- Priority: Quadra → NVIDIA → none

**Platform Detection** (20-platform.sh, detect.sh):
- BIOS vendor match: `Amazon*|EC2*` → `aws`
- Fallback to vendor file (Oracle pattern)

**UserData Scripts:**
- `scripts/aws_ec2_userdata.sh` - standalone SSM+tags hybrid
- `terraform/aws/userdata.sh` - Terraform template version

**Terraform Infrastructure** (`terraform/aws/`):
- **main.tf**: VPC, subnet, IGW, route table, security group, EC2, EIP, IAM role/policy, SSM parameters
- **variables.tf**: 15 input vars (instance type, hardware profile, secrets, domain, networking)
- **outputs.tf**: 12 outputs (IPs, URLs, SSH command, resource IDs)
- **terraform.tfvars.example**: Documented examples for all scenarios
- **README.md**: Complete deployment guide with troubleshooting

**Parameter Security:**
- Secrets (license, password) → SSM Parameter Store (SecureString)
- Non-secrets (domain, email) → EC2 instance tags via IMDSv2
- No secrets in UserData

**IAM Permissions:**
- `ssm:GetParameter` on `/norsk/*`
- `ec2:DescribeTags` for tag metadata

### Files Created
- `scripts/platforms/aws.sh` (43 lines)
- `scripts/aws_ec2_userdata.sh` (70 lines)
- `terraform/aws/main.tf` (273 lines)
- `terraform/aws/variables.tf` (103 lines)
- `terraform/aws/outputs.tf` (64 lines)
- `terraform/aws/userdata.sh` (61 lines)
- `terraform/aws/terraform.tfvars.example` (42 lines)
- `terraform/aws/README.md` (292 lines)
- `deployed/AWS/` directory

### Files Modified
- `scripts/lib/20-platform.sh` - added AWS detection (lines 20-22, 34)
- `deployed/detect.sh` - added AWS vendor matching (complete rewrite to case statement)
- `scripts/bootstrap.sh` - added NVIDIA detection (lines 123-125)

## Nginx Basic Auth Security Architecture & Password Management

### Current Security Flow

**1. Initial Password Setup (Bootstrap)**
- `scripts/lib/10-secrets.sh:setup_secrets()` generates .htpasswd at install time
- Input: `$STUDIO_PASSWORD` from platform (UDF/metadata/SSM/tags)
- Hash generation: `xmartlabs/htpasswd` Docker image (bcrypt)
- Output: `support/oauth2/secrets/.htpasswd`
- Permissions: `644`, owned by `norsk:norsk`
- Format: `norsk-studio-admin:<bcrypt-hash>`

**2. Runtime Password Refresh (Setup)**
- `deployed/setup.sh` runs before nginx starts (via norsk-setup.service)
- Lines 10-19: checks if .htpasswd needs regeneration
- Regenerates if: file empty OR only has default admin user AND platform has `admin-password.sh`
- Platform scripts: `deployed/{Google,local}/admin-password.sh`
  - Google: pulls from metadata or falls back to `<hostname>-norsk-studio-password`
  - local: uses `<hostname>-norsk-studio-password`
- Same Docker image for consistency

**3. Nginx Integration**
- `support/nginx.yaml` mounts .htpasswd as Docker secret
- Path in container: `/run/secrets/.htpasswd`
- `AUTH_METHOD=oauth2` set by `deployed/support-containers.sh:17`
- `support/oauth2/nginx/location.conf`: `auth_basic_user_file /run/secrets/.htpasswd`
- Also used by oauth2-proxy auth endpoint (`server.conf`)

**4. Storage Locations**
- **Host:** `support/oauth2/secrets/.htpasswd` (permanent, survives restarts)
- **Container:** `/run/secrets/.htpasswd` (Docker secret mount, read-only)
- Generated at: bootstrap (initial) or setup.sh (every service start if conditions met)

### Current Gaps

**No Manual Password Change Mechanism**
- User cannot change password post-deployment
- Only auto-regenerates from platform metadata (Google) or hostname fallback
- No CLI tool or API endpoint for password updates
- No force-change workflow for security compliance

**No Password Rotation Policy**
- No expiry tracking
- No mandatory change after first login
- No audit log of password changes

### Proposed Solution

**Option A: CLI Tool (Simplest)**
```bash
/var/norsk-studio/norsk-studio-docker/deployed/change-password.sh
```
- Prompts for new password (stdin, hidden)
- Validates strength (min length, complexity)
- Generates new .htpasswd via same Docker image
- Atomic write (temp file + mv)
- Triggers nginx reload: `systemctl reload nginx.service` (uses ExecReload)
- Logs change to syslog

**Option B: Web UI Endpoint**
- Add `/studio/admin/password` route
- Requires current password + new password
- Updates .htpasswd server-side
- Triggers reload
- More complex, requires Studio code changes

**Option C: Platform Metadata + Timestamp**
- Extend `admin-password.sh` to include timestamp check
- Store last-change timestamp in `deployed/{Platform}/password-changed`
- Force regeneration if timestamp file missing (first boot)
- User changes via platform metadata update + service restart
- Platform-specific, not universal

### Recommendation: Option A (CLI Tool)

**Rationale:**
- Platform-agnostic (works on Linode/Google/Oracle/AWS/local)
- Minimal dependencies (just htpasswd Docker image)
- Immediate effect (reload, not restart)
- No Studio code changes
- Scriptable for automation/Terraform

**Requirements (User Confirmed):**
- Force change: mandatory on bootstrap for EC2 (and similar platforms)
- Password policy: lenient (min 8 chars, no complexity requirements)
- Audit: minimal logging (production uses SSO integration)
- Single user only (norsk-studio-admin) - multi-user/roles is separate task

**Implementation Plan:**

**Phase 1: CLI Password Change Tool**
- [ ] Create `deployed/change-password.sh` script
  - Prompts for new password twice (hidden via `read -s`)
  - Validates: non-empty, min 8 chars, matches confirmation
  - Generates .htpasswd via `xmartlabs/htpasswd` Docker image
  - Atomic write: `.htpasswd.tmp` → `.htpasswd`
  - Reloads nginx: `systemctl reload nginx.service` or direct Docker exec
  - Removes `.password-must-change` marker if exists
  - Success criteria: can run manually, password updates, nginx accepts new password

**Phase 2: Force Change on EC2 Bootstrap**
- [ ] Modify `scripts/lib/10-secrets.sh`
  - Add platform detection (check for `$PLATFORM` var)
  - Create marker `support/oauth2/secrets/.password-must-change` for EC2/AWS
  - Success criteria: marker created on EC2 bootstrap, not on other platforms

**Phase 3: Force Change Enforcement (nginx/oauth2-proxy)**

**Architecture Note:** oauth2-proxy handles login page (nginx error_page 401 → /oauth2/sign_in), not Studio. oauth2-proxy uses htpasswd for auth but **has no built-in password change endpoint** ([source](https://github.com/oauth2-proxy/oauth2-proxy/issues/1261)).

**Options:**
1. **Custom nginx endpoint** (`/oauth2/change-password`)
   - POST handler runs `change-password.sh` via CGI/subprocess
   - Returns success/error as HTML form response
   - Challenges: nginx doesn't natively run shell scripts, requires lua/njs module or sidecar service

2. **Lightweight password change service**
   - New container in support stack (Flask/Go HTTP server)
   - Endpoint: `/password-change` (GET: form, POST: update)
   - Validates current password against .htpasswd
   - Generates new hash, writes atomically
   - Signals oauth2-proxy reload (SIGHUP or restart)
   - Success criteria: standalone, minimal dependencies, integrates with oauth2-proxy login flow

3. **Redirect to external change tool**
   - On `.password-must-change` marker, oauth2-proxy redirects to docs/instructions
   - User SSHs to server, runs `change-password.sh`
   - Simple but poor UX

**Selected: Option 2 (Lightweight Service)**

**Implementation Tasks:**

**Phase 1: CLI Password Change Tool (SSH/admin access)**
- [ ] Create `deployed/change-password.sh`
  - Interactive: prompts for new password twice (read -s)
  - Non-interactive: accepts password via stdin for automation
  - Validates: non-empty, min 8 chars, confirmation match
  - Generates bcrypt hash via `xmartlabs/htpasswd` Docker image
  - Atomic write: `.htpasswd.tmp` → `oauth2/secrets/.htpasswd`
  - Restarts oauth2-proxy: `docker restart oauth2-proxy`
  - Removes `.password-must-change` marker if exists
  - Logs to syslog
  - Success criteria: manual password change works, nginx accepts new creds

**Phase 2: Password Change Microservice**
- [ ] Create `support/password-change/` directory structure
  - `Dockerfile` (python:3.12-alpine base)
  - `requirements.txt` (flask, bcrypt)
  - `app.py` (Flask server)
  - `templates/change.html` (password change form)

- [ ] Implement Flask app
  - `GET /` → HTML form (current password, new password, confirm)
  - `POST /` → validate + update handler
    - Reads `/run/secrets/.htpasswd` to verify current password
    - Validates new password (min 8 chars, matches confirm)
    - Calls htpasswd Docker image to generate new hash
    - Atomic write to `/mnt/htpasswd/.htpasswd` (volume mount)
    - Restarts oauth2-proxy via Docker socket
    - Removes `/mnt/htpasswd/.password-must-change` marker
    - Returns success/error page
  - `GET /health` → readiness check
  - Success criteria: container builds, runs, responds to requests

- [ ] Add to compose stack
  - Create `support/password-change.yaml`
  - Service definition with volumes (oauth2/secrets, docker.sock)
  - Port 5000 (internal only, proxied by nginx)
  - Depends on oauth2-proxy

- [ ] Update `deployed/support-containers.sh`
  - Add `-f password-change.yaml` to compose command
  - Success criteria: password-change service starts with nginx

**Phase 3: nginx Integration**
- [ ] Add nginx location block
  - `support/oauth2/nginx/server.conf` or new include file
  - `location /password-change` → `http://password-change:5000`
  - Protect with `auth_request /oauth2/auth` (must be logged in)
  - Success criteria: route accessible when authenticated

- [ ] Add banner for force-change
  - Detect `.password-must-change` marker in password-change service
  - Show warning banner on password change page: "Password change required before using Studio"
  - Add "Change Password" link visible on oauth2-proxy error page (302 redirect after login)
  - Success criteria: user sees prompt to change password

**Phase 4: Bootstrap Integration**
- [ ] Modify `scripts/lib/10-secrets.sh`
  - Detect platform via `$PLATFORM` variable
  - For AWS/EC2: create `support/oauth2/secrets/.password-must-change` marker
  - For other platforms: skip marker
  - Success criteria: marker created only on EC2 bootstrap

**Phase 5: Testing & Documentation**
- [ ] Test password change flow
  - Deploy to test EC2 instance
  - Verify marker created
  - Access Studio → redirected to login
  - Login with default password
  - Navigate to `/password-change`
  - Change password successfully
  - Verify marker removed
  - Verify new password works

- [ ] Update documentation
  - README: password change instructions (web UI + CLI)
  - Document force-change behavior on EC2
  - Document SSO integration path for production
  - Success criteria: clear instructions for users

**Phase 4: Documentation**
- [ ] Add password change instructions to README
- [ ] Document force-change workflow for EC2
- [ ] Note SSO integration path for production

---

## Lessons

- **set -e and conditional echo**: `[[ -n "$VAR" ]] && echo` fails with set -e when VAR unset. Use explicit `if [[ -n "${VAR:-}" ]]; then echo; fi` instead
- **Quadra detection**: `lspci | grep -iq netint` detects Netint Quadra hardware
- **NVIDIA detection**: `lspci | grep -iq nvidia` detects NVIDIA GPU (T4, A10G, etc)
- **EC2 IMDSv2**: More secure than IMDSv1, requires token header on all metadata requests
- **Terraform templatefile**: Use for UserData to inject vars at apply time, not runtime

## Decisions

1. **Branch:** git-mgt (for now)
2. **Install type:** Fresh installs only
3. **Rollback:** No
4. **Hardware detection:** Explicit (we know what we're installing)
5. **Systemd structure:** Option C - hardware profiles install their own services
6. **Oracle iptables:** Keep with TODO comment (unknown if needed)
7. **Oracle oauth2:** Match Linode (enabled)
8. **Migration:** No support for existing deployments
9. **Execution:** Step-by-step, wait for user approval between phases
10. **Script naming:** scripts/bootstrap.sh (unattended, distinct from interactive install)
11. **EC2 parameters:** Hybrid SSM (secrets) + Tags (non-secrets)
12. **IaC tool:** Terraform (multi-cloud ready vs CloudFormation lock-in)
13. **GPU detection:** `lspci | grep -iq nvidia` (mirrors Quadra pattern)

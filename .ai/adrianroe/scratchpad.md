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
14. **GCP parameters:** Secret Manager (secrets) + Metadata (non-secrets) - already used by existing platform

---

## GCP (Google Cloud Platform) Terraform Implementation

**Goal:** Mirror AWS Terraform implementation for GCP, leveraging existing Google platform support.

### Current State Analysis

**Existing Google Platform Support:**
- `scripts/platforms/google.sh` - metadata service integration
- `deployed/Google/norsk-config.sh` - runtime config
- `deployed/Google/admin-password.sh` - password from metadata
- Uses metadata attributes: `deploy_domain_name`, `deploy_certbot_email`, `norsk-studio-admin-password`
- No Secret Manager integration yet
- No Terraform IaC

**AWS Implementation (reference):**
- SSM Parameter Store for secrets
- EC2 tags for non-secrets
- Terraform: VPC, subnet, IGW, security group, EIP, IAM role
- UserData script calls bootstrap.sh
- 15 input vars, 12 outputs
- README with deployment guide

### GCP Architecture Design

**GCP Service Mapping:**
| AWS | GCP Equivalent |
|-----|---------------|
| SSM Parameter Store | Secret Manager |
| EC2 Tags | Instance Metadata |
| IAM Role | Service Account |
| Security Group | Firewall Rules |
| Elastic IP | Static External IP |
| UserData | startup-script metadata |
| AMI | Image Family (ubuntu-2404-lts) |
| EBS Volume | Persistent Disk |

### Implementation Plan

**terraform/gcp/ structure:**
```
terraform/gcp/
├── main.tf              # VPC, subnet, firewall, compute instance, static IP, service account
├── variables.tf         # 15+ input vars (project, region, zone, machine type, secrets, domain, etc)
├── outputs.tf           # 12+ outputs (IPs, URLs, SSH command, resource IDs)
├── startup-script.sh    # Template: clone repo, call bootstrap.sh
├── terraform.tfvars.example  # Documented examples
└── README.md            # Deployment guide
```

**Key Design Decisions:**

1. **Secret Storage:**
   - Secret Manager for license + password (like AWS SSM)
   - Service account with `secretmanager.secretAccessor` role
   - Modify `scripts/platforms/google.sh` to check Secret Manager first, fallback to metadata

2. **Metadata Usage:**
   - Domain, email → metadata attributes (already implemented)
   - Hardware profile → metadata attribute (new)
   - Repo branch → metadata attribute (new)

3. **Networking:**
   - Auto-create VPC + subnet (like AWS), OR use existing
   - Firewall rules: 22 (SSH), 80 (HTTP), 443 (HTTPS), 6791 (WebSocket), 5001/udp
   - Static external IP for stable public address

4. **Compute:**
   - Default: n2-standard-4 (4 vCPU, 16GB RAM, ~$0.19/hr)
   - GPU: n1-standard-4 + nvidia-tesla-t4 (~$0.35/hr + $0.35/hr GPU)
   - Image: ubuntu-2404-noble-amd64 (matches AWS)
   - Boot disk: 50GB SSD (pd-ssd or pd-balanced)

5. **Service Account:**
   - Custom SA with minimal permissions
   - Roles: `secretmanager.secretAccessor`, `logging.logWriter`, `monitoring.metricWriter`

6. **Startup Script:**
   - Similar to AWS UserData
   - Fetch secrets from Secret Manager via gcloud CLI
   - Fetch config from metadata
   - Clone repo, run bootstrap.sh

### Files to Create/Modify

**New Files:**
1. `terraform/gcp/main.tf` (~300 lines)
   - Provider config (project, region)
   - VPC + subnet (conditional, like AWS)
   - Firewall rules (ingress/egress)
   - Service account + IAM bindings
   - Secret Manager secrets
   - Static external IP
   - Compute instance

2. `terraform/gcp/variables.tf` (~120 lines)
   - gcp_project (required)
   - gcp_region (default: us-central1)
   - gcp_zone (default: us-central1-a)
   - machine_type (default: n2-standard-4)
   - image_family (default: ubuntu-2404-noble-amd64)
   - ssh_user (default: ubuntu)
   - norsk_license_json (sensitive)
   - studio_password (sensitive)
   - domain_name, certbot_email
   - hardware_profile (auto|none|quadra|nvidia)
   - repo_branch (default: git-mgt)
   - boot_disk_size (default: 50)
   - use_gpu (bool, default: false)
   - gpu_type (default: nvidia-tesla-t4)
   - network_name, subnet_name (optional, for existing VPC)
   - project_name (for labels)

3. `terraform/gcp/outputs.tf` (~70 lines)
   - instance_id, instance_name
   - public_ip, private_ip
   - norsk_studio_url
   - ssh_command
   - startup_script_log (gcloud compute instances get-serial-port-output)
   - vpc_id, subnet_id
   - firewall_rule_names
   - service_account_email
   - secret_manager_ids

4. `terraform/gcp/startup-script.sh` (~80 lines)
   - Install gcloud CLI (if not present)
   - Fetch license + password from Secret Manager
   - Fetch domain, email, hardware from metadata
   - Install git
   - Clone repo
   - Run bootstrap.sh

5. `terraform/gcp/terraform.tfvars.example` (~50 lines)
   - Examples for all scenarios:
     - Software-only
     - NVIDIA GPU (n1-standard-4 + T4)
     - Custom VPC
     - Domain + SSL

6. `terraform/gcp/README.md` (~250 lines)
   - Prerequisites (gcloud, terraform, project setup)
   - Quick start
   - Machine types + GPU options
   - Cost estimation
   - Troubleshooting (startup script logs, service account permissions)
   - Cleanup

**Modified Files:**
1. `scripts/platforms/google.sh` (~60 lines, +20)
   - Add Secret Manager fetch for license + password
   - Check if `gcloud` available
   - Fetch `/norsk/license` and `/norsk/password` from Secret Manager
   - Fallback to metadata for password (backward compat)
   - Export vars for bootstrap.sh

2. `scripts/lib/10-secrets.sh` (optional enhancement)
   - Already handles $STUDIO_PASSWORD from platform
   - May need adjustment if Secret Manager returns different format

### Terraform Resource Breakdown

**main.tf resources:**
```hcl
# Provider
provider "google" { project, region }

# Data sources
data "google_compute_image" "ubuntu_2404"  # Image lookup
data "google_compute_zones" "available"     # Zone list

# Networking (conditional)
resource "google_compute_network" "vpc"             # VPC
resource "google_compute_subnetwork" "subnet"       # Subnet
resource "google_compute_firewall" "allow_ssh"      # Port 22
resource "google_compute_firewall" "allow_http"     # Port 80
resource "google_compute_firewall" "allow_https"    # Port 443
resource "google_compute_firewall" "allow_ws"       # Port 6791
resource "google_compute_firewall" "allow_udp"      # Port 5001

# IAM
resource "google_service_account" "norsk_studio"    # Service account
resource "google_project_iam_member" "secret_accessor"  # Secret Manager role

# Secrets
resource "google_secret_manager_secret" "norsk_license"       # License secret
resource "google_secret_manager_secret_version" "license_v1"  # License value
resource "google_secret_manager_secret" "studio_password"     # Password secret
resource "google_secret_manager_secret_version" "password_v1" # Password value

# Compute
resource "google_compute_address" "static_ip"       # Static external IP
resource "google_compute_instance" "norsk_studio"   # VM instance
  # metadata: startup-script, deploy_domain_name, deploy_certbot_email, hardware_profile
  # service_account: email, scopes
  # network_interface: subnetwork, access_config (static IP)
  # boot_disk: size, type, image
  # (optional) guest_accelerator for GPU
```

### Hardware Profile Support

**CPU-only (default):**
- Machine: n2-standard-4
- Cost: ~$0.19/hr

**NVIDIA GPU:**
- Machine: n1-standard-4 (GPU requires N1 family)
- Accelerator: nvidia-tesla-t4 (count: 1)
- GPU drivers: installed by hardware/nvidia.sh
- Cost: ~$0.19/hr + $0.35/hr = $0.54/hr

**Quadra:**
- Not typically available on GCP
- Would require bare metal or custom image
- Likely not supported in initial implementation

### Testing Strategy

1. **Validation:**
   - `terraform validate`
   - `terraform plan` (check resource count)

2. **Deployment:**
   - Test with software-only first
   - Test with NVIDIA GPU
   - Test with custom VPC
   - Test with domain + SSL

3. **Verification:**
   - Check startup script logs: `gcloud compute instances get-serial-port-output`
   - SSH to instance, verify services running
   - Access Studio via public IP
   - Verify Secret Manager access

### Cost Estimation

**Software-only (n2-standard-4):**
- Compute: ~$0.19/hr (~$137/mo)
- Disk 50GB SSD: ~$8.50/mo
- Static IP: ~$7.50/mo (if reserved but unused)
- **Total: ~$153/mo**

**GPU (n1-standard-4 + T4):**
- Compute: ~$0.19/hr (~$137/mo)
- GPU: ~$0.35/hr (~$252/mo)
- Disk: ~$8.50/mo
- Static IP: ~$7.50/mo
- **Total: ~$405/mo**

### Implementation Phases

**Phase 1: Core Terraform Structure**
- Create terraform/gcp/ directory
- main.tf: provider, data sources, locals
- variables.tf: all input vars
- outputs.tf: all outputs
- terraform.tfvars.example

**Phase 2: Networking & IAM**
- VPC + subnet (conditional on existing network)
- Firewall rules (SSH, HTTP, HTTPS, WS, UDP)
- Service account + IAM bindings

**Phase 3: Secret Manager**
- Secret resources for license + password
- IAM binding for service account access

**Phase 4: Compute Instance**
- Static external IP
- Compute instance resource
- Boot disk config
- Metadata for startup script + config
- (Optional) GPU accelerator support

**Phase 5: Startup Script**
- startup-script.sh template
- Fetch secrets from Secret Manager
- Fetch config from metadata
- Clone repo + bootstrap.sh call
- GPU reboot logic (if needed)

**Phase 6: Platform Script Enhancement**
- Modify scripts/platforms/google.sh
- Add Secret Manager fetch (gcloud secrets)
- Maintain backward compat with metadata

**Phase 7: Documentation**
- README.md with deployment guide
- Troubleshooting section
- Cost breakdown
- GPU setup instructions

**Phase 8: Testing**
- Validate terraform
- Deploy test instance
- Verify all components
- Document any issues

### Unresolved Questions

1. **Quadra support on GCP?** (likely no - rare/unsupported)
2. ~~**GPU driver auto-install** - does hardware/nvidia.sh work on GCP Ubuntu 24.04?~~ → Planning now
3. **Secret Manager regional replication** - single region or multi-region? → auto replication used
4. **VPC peering** - support connecting to existing peered VPCs? → yes, via network_name/subnet_name vars
5. **Custom service account** - user-provided SA or always create new? → both supported via service_account_email var
6. **Metadata vs labels** - instance metadata for runtime config, labels for organization? → yes, implemented
7. **Startup script size limit** - inline vs GCS bucket? (64KB limit) → inline template, under limit
8. ~~**Ubuntu 24.04 image** - confirm family name `ubuntu-2404-noble-amd64`?~~ → ubuntu-2404-lts-amd64 (confirmed in main.tf)

---

## NVIDIA Driver Implementation for GCP

**Goal:** Implement `scripts/hardware/nvidia.sh` for GPU-accelerated Norsk Studio on GCP.

**User Requirements:**
- Driver version >= 575
- nvidia-smi available
- Container runtime integration (Docker/Norsk)

### Current State

**Terraform (GCP):**
- GPU support: n1-standard-4 + nvidia-tesla-t4 (main.tf:238-244)
- Metadata: hardware_profile passed to startup script
- Reboot logic: startup-script.sh:75-78 reboots if `DEPLOY_HARDWARE="nvidia"`

**Stub Implementation:**
- `scripts/hardware/nvidia.sh`: 11 lines, exits 1 with TODO
- No driver install, no container runtime config

**Reference (Quadra):**
- `scripts/hardware/quadra.sh`: downloads binaries, compiles deps, systemd service, usermod

### Research Findings

**NVIDIA Driver 575+ on Ubuntu 24.04:**
- Officially backported to Ubuntu repos ([UbuntuHandbook](https://ubuntuhandbook.org/index.php/2025/07/ubuntu-adding-nvidia-575-driver-support-for-24-04-22-04-lts/))
- Version 575.57.08 available ([NVIDIA docs](https://docs.nvidia.com/datacenter/tesla/tesla-release-notes-575-57-08/index.html))
- Multiple install methods: ubuntu-drivers, apt, CUDA repo
- Includes nvidia-smi utility

**Container Runtime Integration:**
- nvidia-container-toolkit v1.17.7+ supports Ubuntu 24.04 ([Lindevs](https://lindevs.com/install-nvidia-container-toolkit-on-ubuntu))
- Enables `docker run --gpus` flag
- Requires Docker runtime config: `nvidia-ctk runtime configure --runtime=docker`

**GCP Considerations:**
- GCP provides automated install scripts ([GCP docs](https://docs.cloud.google.com/compute/docs/gpus/install-drivers-gpu))
- Scripts may not fully support Ubuntu 24.04 secure boot yet
- Recommendation: use Ubuntu native methods for 24.04

### Key Challenges and Analysis

**1. Driver Installation Method**

**Options:**
- **A) ubuntu-drivers autoinstall** - detects GPU, picks best driver
- **B) apt install nvidia-driver-575-server** - explicit version control
- **C) GCP automated script** - cloud-native but may lag Ubuntu 24.04 support
- **D) CUDA repository** - includes CUDA toolkit (unnecessary for Norsk)

**Recommendation: Option B (apt explicit install)**
- Guarantees version >= 575
- Server variant optimized for datacenter GPUs (T4, A10G)
- No CUDA overhead (Norsk uses driver APIs only)
- Ubuntu repos = tested/stable for 24.04

**2. Reboot Requirement**

Kernel modules (nvidia.ko, nvidia-uvm.ko) require reboot after install.

**Current flow:**
- startup-script.sh:75-78 checks `DEPLOY_HARDWARE="nvidia"` → reboot
- Second boot: services start with GPU available

**3. Container Runtime Configuration**

**Steps:**
1. Install nvidia-container-toolkit from NVIDIA repo
2. Run `nvidia-ctk runtime configure --runtime=docker`
3. Reload docker: `systemctl restart docker`
4. Test: `docker run --rm --gpus all nvidia/cuda:12.6.3-base-ubuntu24.04 nvidia-smi`

**4. Prerequisites**

- `linux-headers-$(uname -r)` - kernel headers for DKMS
- `build-essential` - compiler for module builds
- Docker installed - already handled by 00-common.sh

**5. Error Handling**

- Verify GPU detected: `lspci | grep -i nvidia`
- Check driver loaded: `nvidia-smi` (post-reboot)
- Verify Docker integration: `docker run --gpus all`

### Implementation Design

**scripts/hardware/nvidia.sh structure:**

```bash
#!/usr/bin/env bash
# NVIDIA GPU hardware profile
# Installs driver >= 575 + container toolkit

setup_hardware() {
  # 1. Verify GPU present
  # 2. Install prerequisites (headers, build-essential)
  # 3. Install NVIDIA driver 575-server from Ubuntu repos
  # 4. Install nvidia-container-toolkit from NVIDIA repo
  # 5. Configure Docker runtime
  # 6. Mark reboot needed (checked by startup-script.sh)
}
```

**Driver installation:**
```bash
apt-get update
apt-get install -y linux-headers-$(uname -r) build-essential
apt-get install -y nvidia-driver-575-server nvidia-utils-575-server
```

**Container toolkit:**
```bash
# Add NVIDIA repo
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

apt-get update
apt-get install -y nvidia-container-toolkit

# Configure Docker
nvidia-ctk runtime configure --runtime=docker
systemctl restart docker
```

**Reboot coordination:**
- nvidia.sh doesn't reboot itself (called during bootstrap)
- startup-script.sh detects `DEPLOY_HARDWARE="nvidia"` in norsk-config.sh
- Reboots once after full bootstrap completes
- Post-reboot: norsk.service starts with GPU access

### Opinions & Recommendations

**Driver Version Strategy:**
- **Target: 575-server (not 575)** - server variant for stability
- Justification: T4/A10G are datacenter GPUs, need server drivers
- Alternative: 570-server (older but stable) if 575 issues found

**Testing Strategy:**
1. **Pre-reboot verification:**
   - Driver installed: `dpkg -l | grep nvidia-driver-575`
   - Toolkit installed: `which nvidia-ctk`
   - Docker config: `cat /etc/docker/daemon.json | grep nvidia`

2. **Post-reboot verification:**
   - Driver loaded: `nvidia-smi` shows GPU + driver version
   - Docker integration: `docker run --rm --gpus all nvidia/cuda:12.6.3-base-ubuntu24.04 nvidia-smi`

**Risks & Mitigations:**
- **Risk:** 575 not yet in Ubuntu repos for 24.04
  - **Mitigation:** Fallback to 570-server, or use graphics-drivers PPA
- **Risk:** Secure boot conflicts with unsigned modules
  - **Mitigation:** GCP instances typically don't use secure boot, or use signed ubuntu-drivers
- **Risk:** Container toolkit repo changes
  - **Mitigation:** Pin specific version if needed

### Implementation Plan

**Phase 1: nvidia.sh Core Implementation**
- [ ] Replace stub with driver install logic
  - Verify GPU present via lspci
  - Install linux-headers + build-essential
  - Install nvidia-driver-575-server + nvidia-utils-575-server
  - Exit cleanly if no GPU found (hardware=auto fallback)
  - Success: driver packages installed, no errors

**Phase 2: Container Runtime Integration**
- [ ] Add nvidia-container-toolkit installation
  - Add NVIDIA repo w/ GPG key
  - Install nvidia-container-toolkit package
  - Configure Docker runtime via nvidia-ctk
  - Restart docker daemon
  - Success: `nvidia-ctk --version` works, docker config has nvidia runtime

**Phase 3: Verification & Testing**
- [ ] Add pre-reboot checks
  - Verify driver packages installed
  - Verify toolkit installed
  - Verify docker daemon.json configured
  - Success: all checks pass before reboot

**Phase 4: Post-Reboot Validation**
- [ ] Test on GCP with T4
  - Deploy via terraform w/ use_gpu=true
  - SSH post-reboot, check nvidia-smi output
  - Test docker GPU access
  - Verify Norsk can access GPU
  - Success: nvidia-smi shows driver 575+, docker test passes

**Phase 5: Documentation**
- [ ] Update README.md
  - Document GPU setup
  - Add nvidia-smi verification steps
  - Add troubleshooting section
  - Success: clear GPU deployment instructions

### Implementation Decisions

1. **Driver version:** Fail if 575-server unavailable (no fallback)
2. **Install method:** Explicit `apt install nvidia-driver-575-server`
3. **Nouveau blacklist:** Skip (package handles automatically)
4. **CUDA toolkit:** No (Norsk uses Video Codec SDK only)
5. **Test image:** nvidia/cuda:12.6.3-base-ubuntu24.04
6. **Docker config:** nvidia-ctk writes daemon.json, Compose reads it via `driver: nvidia`
7. **Norsk config:** yaml/hardware-devices/nvidia.yaml already correct (no changes)

### High-Level Task Breakdown

**Phase 1: nvidia.sh Implementation** ✓
- [x] Verify GPU present via lspci
- [x] Install prerequisites (linux-headers, build-essential)
- [x] Check nvidia-driver-575-server availability
- [x] Install nvidia-driver-575-server + nvidia-utils-575-server
- [x] Add NVIDIA container toolkit repo
- [x] Install nvidia-container-toolkit
- [x] Configure Docker runtime via nvidia-ctk
- [x] Restart Docker daemon
- [x] Export DEPLOY_HARDWARE="nvidia" to norsk-config.sh
- [x] Success: packages installed, docker configured, no errors

**Phase 2: Testing on GCP**
- [ ] Deploy test instance via terraform (use_gpu=true, n1-standard-4 + T4)
- [ ] SSH post-reboot, verify nvidia-smi shows driver 575+
- [ ] Test docker GPU access: `docker run --rm --gpus all nvidia/cuda:12.6.3-base-ubuntu24.04 nvidia-smi`
- [ ] Verify Norsk containers start with GPU access
- [ ] Check norsk logs for GPU device detection
- [ ] Success: full GPU stack operational

**Phase 3: Documentation**
- [ ] Update terraform/gcp/README.md with GPU validation steps
- [ ] Add troubleshooting section for GPU issues
- [ ] Document nvidia-smi verification
- [ ] Success: clear deployment & validation instructions

### Detailed Implementation Plan

**scripts/hardware/nvidia.sh structure:**

```bash
#!/usr/bin/env bash
# NVIDIA GPU hardware profile
# Installs driver 575-server + container toolkit for Ubuntu 24.04

setup_hardware() {
  echo "Setting up NVIDIA GPU support..."

  # 1. Verify GPU present
  if ! lspci | grep -qi nvidia; then
    echo "No NVIDIA GPU detected via lspci"
    exit 1
  fi

  # 2. Install prerequisites
  apt-get update
  apt-get install -y linux-headers-$(uname -r) build-essential

  # 3. Check driver availability
  if ! apt-cache policy nvidia-driver-575-server | grep -q 'Candidate:'; then
    echo "ERROR: nvidia-driver-575-server not available in repos"
    echo "Available drivers:"
    apt-cache search nvidia-driver | grep server
    exit 1
  fi

  # 4. Install NVIDIA driver 575-server
  echo "Installing NVIDIA driver 575-server..."
  apt-get install -y nvidia-driver-575-server nvidia-utils-575-server

  # 5. Add NVIDIA container toolkit repo
  echo "Adding NVIDIA container toolkit repository..."
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
    gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

  curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

  # 6. Install nvidia-container-toolkit
  apt-get update
  apt-get install -y nvidia-container-toolkit

  # 7. Configure Docker runtime
  echo "Configuring Docker for NVIDIA runtime..."
  nvidia-ctk runtime configure --runtime=docker
  systemctl restart docker

  # 8. Export hardware config
  echo 'export DEPLOY_HARDWARE="nvidia"' >> "$REPO_DIR/deployed/${PLATFORM^}/norsk-config.sh"

  echo "NVIDIA setup complete - reboot required for driver to load"
}
```

**Verification checks (manual after deployment):**
```bash
# Post-reboot verification
nvidia-smi  # Should show driver 575+, GPU model, memory

# Docker GPU test
docker run --rm --gpus all nvidia/cuda:12.6.3-base-ubuntu24.04 nvidia-smi

# Norsk container check
docker ps | grep norsk-media
docker logs norsk-media | grep -i nvidia
```

### Testing Strategy

**Pre-deployment validation:**
- Syntax check: `bash -n scripts/hardware/nvidia.sh`
- Mock test: run with `lspci` stubbed (test/install/mock-hardware/nvidia.sh)

**GCP deployment test:**
1. Create terraform.tfvars:
   ```hcl
   use_gpu = true
   machine_type = "n1-standard-4"
   gpu_type = "nvidia-tesla-t4"
   hardware_profile = "auto"  # or "nvidia"
   ```
2. `terraform apply`
3. Monitor: `gcloud compute instances get-serial-port-output` (watch for reboot)
4. SSH post-reboot, run verification commands
5. Test Norsk workflow with GPU encode/decode

**Success criteria:**
- ✓ nvidia-smi shows driver >= 575
- ✓ Docker test container can access GPU
- ✓ norsk-media container starts without errors
- ✓ GPU shows up in Norsk Studio hardware panel
- ✓ Can create workflow using NVIDIA encode node

### Risk Mitigation

**Risk 1:** 575-server not in Ubuntu 24.04 repos yet
- **Check:** Run `apt-cache policy nvidia-driver-575-server` on fresh 24.04 instance
- **Mitigation:** If unavailable, add graphics-drivers PPA or use 570-server (update script)

**Risk 2:** Container toolkit repo changes URL/format
- **Mitigation:** Pin to stable branch (already using /stable/deb/)

**Risk 3:** Reboot loop if driver fails to load
- **Mitigation:** Check dmesg/journalctl for nvidia module errors, test on single instance first

**Risk 4:** Docker restart breaks running containers
- **Mitigation:** Occurs during bootstrap (no containers running yet), safe

### Sources

- [UbuntuHandbook - NVIDIA 575 Driver Support](https://ubuntuhandbook.org/index.php/2025/07/ubuntu-adding-nvidia-575-driver-support-for-24-04-22-04-lts/)
- [NVIDIA Data Center Driver 575.57.08 Release Notes](https://docs.nvidia.com/datacenter/tesla/tesla-release-notes-575-57-08/index.html)
- [Lindevs - NVIDIA Container Toolkit Ubuntu 24.04](https://lindevs.com/install-nvidia-container-toolkit-on-ubuntu)
- [GCP - Install GPU Drivers](https://docs.cloud.google.com/compute/docs/gpus/install-drivers-gpu)

### Executor's Feedback

**Phase 1 Complete (scripts/hardware/nvidia.sh implementation):**
- Implemented 69-line script replacing 11-line stub
- GPU detection via lspci (exits if no GPU found)
- Prerequisites: linux-headers, build-essential, pciutils
- Driver check: fails fast if nvidia-driver-575-server unavailable
- Driver install: nvidia-driver-575-server + nvidia-utils-575-server
- Container toolkit: NVIDIA repo + nvidia-container-toolkit package
- Docker config: nvidia-ctk runtime configure + systemd restart
- Hardware flag: exports DEPLOY_HARDWARE="nvidia" to norsk-config.sh
- Uses DEBIAN_FRONTEND=noninteractive (matches quadra.sh pattern)
- Syntax validated: bash -n passes

**Ready for Phase 2 (GCP testing):**
- Need terraform.tfvars with use_gpu=true, n1-standard-4, nvidia-tesla-t4
- Need to verify 575-server availability on fresh Ubuntu 24.04 GCP instance
- Need to test full bootstrap flow: driver install → reboot → nvidia-smi verification

**Implementation notes:**
- Added pciutils to prerequisites (provides lspci if not present)
- Error messages to stderr with clear diagnostics
- Reboot message at end (handled by startup-script.sh:75-78)

### Background and Motivation

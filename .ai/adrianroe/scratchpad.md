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

**Phase 4 enhancement complete**
- Unified akamai_stack_script.sh and akamai_quadra_stack_script.sh into single script
- Added hardware UDF (none/quadra), conditional media downloads, conditional reboot
- Deleted akamai_quadra_stack_script.sh

**Phase 5 complete**
- Created test/install/ framework with README
- Created test-args.sh (validates parsing, checks file existence)
- Created Dockerfile.test and test-docker.sh (Ubuntu container tests)
- Created mock-hardware/{quadra,nvidia}.sh for testing without hardware
- Tests validate: arg parsing, help output, module syntax, file existence

**Ready for Phase 6** (documentation)?

## Lessons

*None yet - execution phase not started*

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

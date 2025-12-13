# Norsk Studio - GCP Compute Engine Terraform Deployment

Deploy Norsk Studio on Google Cloud Platform with automated configuration via Terraform.

## Prerequisites

1. **Terraform** >= 1.5.0 ([install](https://developer.hashicorp.com/terraform/downloads))
2. **gcloud CLI** configured with credentials ([setup](https://cloud.google.com/sdk/docs/install))
3. **GCP Project** with billing enabled
4. **APIs Enabled**:
   - Compute Engine API
   - Secret Manager API
   - Cloud Resource Manager API
5. **Norsk License** JSON

## Quick Start

```bash
# 1. Authenticate with GCP
gcloud auth application-default login

# 2. Copy example variables
cp terraform.tfvars.example terraform.tfvars

# 3. Edit terraform.tfvars with your values
vim terraform.tfvars

# 4. Initialize Terraform
terraform init

# 5. Preview changes
terraform plan

# 6. Deploy
terraform apply

# 7. Get access URL
terraform output norsk_studio_url
```

## Configuration

### Required Variables

```hcl
gcp_project        = "my-gcp-project"      # GCP project ID
ssh_keys           = ["ubuntu:ssh-rsa..."] # SSH public keys
norsk_license_json = "{\"license\":\"...\"}" # Norsk license JSON
studio_password    = "changeme123"         # Admin password (min 8 chars)
```

### Hardware Profiles

| Profile | Machine Type | Use Case |
|---------|-------------|----------|
| `auto` (default) | Any | Detect via lspci (recommended) |
| `none` | n2-standard-4 | Software-only encoding |
| `nvidia` | n1-standard-4 + T4 | NVIDIA GPU acceleration |

**Note:** Quadra hardware not typically available on GCP.

**GPU Instances:**
- `n1-standard-4` + `nvidia-tesla-t4` - 1x T4 (16GB GPU, 4 vCPU, 15GB RAM) - ~$0.54/hr
- `n1-standard-4` + `nvidia-tesla-p4` - 1x P4 (8GB GPU) - ~$0.60/hr
- `n1-standard-8` + `nvidia-tesla-v100` - 1x V100 (16GB GPU, 8 vCPU, 30GB RAM) - ~$2.48/hr

### Domain & SSL

For HTTPS with Let's Encrypt:

```hcl
domain_name   = "studio.example.com"
certbot_email = "admin@example.com"
```

**Manual DNS setup required:**
1. Deploy with Terraform
2. Get public IP: `terraform output public_ip`
3. Create DNS A record: `studio.example.com` → `<public_ip>`
4. Wait for DNS propagation (5-30 min)
5. Certbot will auto-configure HTTPS on first access

### Networking

**Create new VPC** (default):
```hcl
# Leave network_name and subnet_name empty
```

**Use existing VPC:**
```hcl
network_name = "my-existing-vpc"
subnet_name  = "my-existing-subnet"
```

**Security:**
```hcl
allowed_ssh_cidrs  = ["1.2.3.4/32"]  # Your IP only
allowed_http_cidrs = ["0.0.0.0/0"]    # Public access
```

## Outputs

After deployment, Terraform provides:

```bash
terraform output norsk_studio_url     # http://1.2.3.4 or https://domain.com
terraform output ssh_command           # gcloud compute ssh ...
terraform output startup_script_log    # View installation progress
```

## Architecture

```
Terraform
  ↓
Compute Engine Instance (Ubuntu 24.04 LTS)
  ├─ Service Account → Secret Manager + Logging
  ├─ Static External IP
  ├─ Firewall Rules (22, 80, 443, 6791, 5001/udp)
  └─ Startup script
       ↓
     Fetch from Secret Manager:
       - norsk-license
       - norsk-studio-password
     Fetch from metadata:
       - deploy_domain_name, deploy_certbot_email, hardware_profile
       ↓
     Clone repo → ./scripts/bootstrap.sh
       ↓
     Install:
       ├─ Docker, Norsk Engine/Studio
       ├─ Hardware drivers (if detected)
       ├─ nginx, oauth2-proxy
       └─ systemd services
```

## Secret Security

- **Secrets** (license, password) → GCP Secret Manager (encrypted at rest)
- **Non-secrets** (domain, email) → Instance metadata
- **Never** in startup script text (only fetched at runtime)

## Troubleshooting

### Check installation progress
```bash
# View serial console output (includes startup script)
gcloud compute instances get-serial-port-output norsk-studio-instance \
  --zone=us-central1-a

# Or use terraform output
terraform output startup_script_log | bash

# SSH to instance
terraform output ssh_command | bash

# Check startup script log directly
sudo tail -f /var/log/startup-script.log
```

### Check systemd services
```bash
systemctl status norsk.service
systemctl status nginx.service
journalctl -u norsk-setup.service -f
```

### Verify platform detection
```bash
cat /opt/norsk-studio/deployed/vendor  # Should show "Google"
sudo dmidecode -s bios-vendor  # Should show "Google"
```

### Verify hardware detection
```bash
lspci | grep -i nvidia   # Check for NVIDIA GPU
cat /opt/norsk-studio/deployed/Google/norsk-config.sh | grep HARDWARE
```

### Access denied to Secret Manager
```bash
# Check service account
gcloud compute instances describe norsk-studio-instance \
  --zone=us-central1-a \
  --format="get(serviceAccounts[].email)"

# Verify IAM binding
gcloud secrets get-iam-policy norsk-license
gcloud secrets get-iam-policy norsk-studio-password

# Test secret access from instance
gcloud secrets versions access latest --secret=norsk-license
```

### GPU not detected
```bash
# Verify GPU attached
gcloud compute instances describe norsk-studio-instance \
  --zone=us-central1-a \
  --format="get(guestAccelerators)"

# Check if drivers installed
nvidia-smi

# Check hardware profile in metadata
gcloud compute instances describe norsk-studio-instance \
  --zone=us-central1-a \
  --format="get(metadata.items.hardware_profile)"
```

## Cost Estimation

**Software-only (n2-standard-4):**
- Compute: ~$0.19/hr (~$137/mo)
- Disk 50GB balanced: ~$2/mo
- Static IP: Free (while attached)
- **Total: ~$139/mo**

**GPU (n1-standard-4 + T4):**
- Compute: ~$0.19/hr (~$137/mo)
- GPU T4: ~$0.35/hr (~$252/mo)
- Disk: ~$2/mo
- **Total: ~$391/mo**

**Committed Use Discounts:**
- 1-year commit: ~30% discount
- 3-year commit: ~50% discount

## Cleanup

```bash
# Destroy all resources
terraform destroy

# Manually delete secrets if needed
gcloud secrets delete norsk-license --quiet
gcloud secrets delete norsk-studio-password --quiet
```

## Advanced

### Custom Image
```hcl
image_family  = "ubuntu-2404-lts-amd64"
image_project = "ubuntu-os-cloud"
```

### Multiple Environments
```bash
# Use workspaces
terraform workspace new staging
terraform workspace new production
terraform workspace select staging
terraform apply -var-file=staging.tfvars
```

### Remote State
```hcl
# backend.tf
terraform {
  backend "gcs" {
    bucket = "my-terraform-state"
    prefix = "norsk-studio"
  }
}
```

### Custom Service Account
```hcl
# Use existing service account
service_account_email = "my-sa@my-project.iam.gserviceaccount.com"
```

### VPC Peering
```hcl
# Connect to existing peered VPC
network_name = "my-peered-vpc"
subnet_name  = "my-subnet-in-peered-vpc"
```

## Enable Required APIs

```bash
gcloud services enable compute.googleapis.com
gcloud services enable secretmanager.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
```

## Permissions

**Terraform user needs:**
- `roles/compute.admin` (or fine-grained compute permissions)
- `roles/iam.serviceAccountAdmin` (to create service account)
- `roles/secretmanager.admin` (to create secrets)
- `roles/resourcemanager.projectIamAdmin` (to grant SA permissions)

**Instance service account needs:**
- `roles/secretmanager.secretAccessor` (to read secrets)
- `roles/logging.logWriter` (for Cloud Logging)
- `roles/monitoring.metricWriter` (for Cloud Monitoring)

## Support

- **Norsk Studio**: https://github.com/norskvideo/norsk-studio-docker
- **Terraform Google Provider**: https://registry.terraform.io/providers/hashicorp/google/latest/docs
- **GCP Compute Engine**: https://cloud.google.com/compute/docs

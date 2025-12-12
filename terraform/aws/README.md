# Norsk Studio - AWS EC2 Terraform Deployment

Deploy Norsk Studio on AWS EC2 with automated configuration via Terraform.

## Prerequisites

1. **Terraform** >= 1.5.0 ([install](https://developer.hashicorp.com/terraform/downloads))
2. **AWS CLI** configured with credentials ([setup](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html))
3. **EC2 Key Pair** in target region ([create](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html))
4. **Norsk License** JSON

## Quick Start

```bash
# 1. Copy example variables
cp terraform.tfvars.example terraform.tfvars

# 2. Edit terraform.tfvars with your values
vim terraform.tfvars

# 3. Initialize Terraform
terraform init

# 4. Preview changes
terraform plan

# 5. Deploy
terraform apply

# 6. Get access URL
terraform output norsk_studio_url
```

## Configuration

### Required Variables

```hcl
key_name           = "my-keypair"              # EC2 key pair name
norsk_license_json = "{\"license\":\"...\"}"  # Norsk license JSON
studio_password    = "changeme123"             # Admin password
```

### Hardware Profiles

| Profile | Instance Type | Use Case |
|---------|--------------|----------|
| `auto` (default) | Any | Detect via lspci (recommended) |
| `none` | t3.xlarge+ | Software-only encoding |
| `nvidia` | g4dn.xlarge, g5.xlarge | NVIDIA GPU acceleration |
| `quadra` | t3.xlarge+ | Netint Quadra (requires physical card) |

**GPU Instances:**
- `g4dn.xlarge` - NVIDIA T4 (16GB GPU, 4 vCPU, 16GB RAM) - ~$0.526/hr
- `g5.xlarge` - NVIDIA A10G (24GB GPU, 4 vCPU, 16GB RAM) - ~$1.006/hr

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
# Leave vpc_id and subnet_id empty
```

**Use existing VPC:**
```hcl
vpc_id    = "vpc-0123456789abcdef0"
subnet_id = "subnet-0123456789abcdef0"
```

**Security:**
```hcl
allowed_ssh_cidrs  = ["1.2.3.4/32"]  # Your IP only
allowed_http_cidrs = ["0.0.0.0/0"]    # Public access
```

## Outputs

After deployment, Terraform provides:

```bash
terraform output norsk_studio_url  # http://1.2.3.4 or https://domain.com
terraform output ssh_command        # ssh -i ~/.ssh/key.pem ubuntu@1.2.3.4
terraform output userdata_log       # View installation progress
```

## Architecture

```
Terraform
  ↓
EC2 Instance (Ubuntu 22.04)
  ├─ IMDSv2 enabled (secure metadata)
  ├─ IAM instance profile → SSM read access
  ├─ Elastic IP (stable public IP)
  ├─ Security Group (22, 80, 443, 6791)
  └─ UserData script
       ↓
     Fetch from SSM:
       - /norsk/license (SecureString)
       - /norsk/password (SecureString)
     Fetch from tags:
       - DomainName, CertbotEmail
       ↓
     Clone repo → ./scripts/bootstrap.sh
       ↓
     Install:
       ├─ Docker, Norsk Engine/Studio
       ├─ Hardware drivers (if detected)
       ├─ nginx, oauth2-proxy
       └─ systemd services
```

## Parameter Security

- **Secrets** (license, password) → AWS SSM Parameter Store (encrypted)
- **Non-secrets** (domain, email) → EC2 instance tags
- **Never** in UserData (visible in console/API)

## Troubleshooting

### Check installation progress
```bash
ssh ubuntu@<public_ip>
sudo tail -f /var/log/ec2-userdata.log
```

### Check systemd services
```bash
systemctl status norsk.service
systemctl status nginx.service
journalctl -u norsk-setup.service -f
```

### Verify platform detection
```bash
cat /var/norsk-studio/norsk-studio-docker/deployed/vendor  # Should show "AWS"
cat /sys/class/dmi/id/bios_vendor  # Should show "Amazon EC2"
```

### Verify hardware detection
```bash
lspci | grep -i nvidia   # Check for NVIDIA GPU
lspci | grep -i netint   # Check for Quadra
cat /var/norsk-studio/norsk-studio-docker/deployed/AWS/norsk-config.sh | grep HARDWARE
```

### Access denied to SSM parameters
```bash
# Check IAM role attached
aws sts get-caller-identity

# Verify instance profile
curl -H "X-aws-ec2-metadata-token: $(curl -X PUT http://169.254.169.254/latest/api/token -H 'X-aws-ec2-metadata-token-ttl-seconds: 21600')" \
  http://169.254.169.254/latest/meta-data/iam/info
```

## Cost Estimation

**Software-only (t3.xlarge):**
- Instance: ~$0.1664/hr (~$120/mo)
- EBS 50GB: ~$5/mo
- Elastic IP: Free (while attached)
- **Total: ~$125/mo**

**GPU (g4dn.xlarge):**
- Instance: ~$0.526/hr (~$380/mo)
- EBS 50GB: ~$5/mo
- **Total: ~$385/mo**

## Cleanup

```bash
# Destroy all resources
terraform destroy

# Manually delete SSM parameters if needed
aws ssm delete-parameter --name /norsk/license
aws ssm delete-parameter --name /norsk/password
```

## Advanced

### Custom AMI
```hcl
ami_id = "ami-0123456789abcdef0"  # Use specific Ubuntu 22.04 AMI
```

### Multiple environments
```bash
# Use workspaces
terraform workspace new staging
terraform workspace new production
terraform workspace select staging
terraform apply -var-file=staging.tfvars
```

### Remote state
```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "norsk-studio/terraform.tfstate"
    region = "us-east-1"
  }
}
```

## Support

- **Norsk Studio**: https://github.com/norskvideo/norsk-studio-docker
- **Terraform AWS Provider**: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- **EC2 Instance Types**: https://aws.amazon.com/ec2/instance-types/

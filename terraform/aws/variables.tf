# Terraform variables for Norsk Studio EC2 deployment

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type (use g4dn.xlarge/g5.xlarge for NVIDIA GPU)"
  type        = string
  default     = "t3.xlarge"
}

variable "ami_id" {
  description = "Ubuntu 22.04 LTS AMI ID (leave empty for auto-lookup)"
  type        = string
  default     = ""
}

variable "key_name" {
  description = "EC2 key pair name for SSH access"
  type        = string
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_http_cidrs" {
  description = "CIDR blocks allowed HTTP/HTTPS access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "norsk_license_json" {
  description = "Norsk license JSON (stored in SSM Parameter Store)"
  type        = string
  sensitive   = true
}

variable "studio_password" {
  description = "Norsk Studio admin password (stored in SSM Parameter Store)"
  type        = string
  sensitive   = true
}

variable "domain_name" {
  description = "Optional domain name for HTTPS (requires manual DNS setup)"
  type        = string
  default     = ""
}

variable "certbot_email" {
  description = "Email for Let's Encrypt certbot renewal notices"
  type        = string
  default     = ""
}

variable "hardware_profile" {
  description = "Hardware profile override (auto|none|quadra|nvidia)"
  type        = string
  default     = "auto"
  validation {
    condition     = contains(["auto", "none", "quadra", "nvidia"], var.hardware_profile)
    error_message = "hardware_profile must be one of: auto, none, quadra, nvidia"
  }
}

variable "repo_branch" {
  description = "Git branch to deploy"
  type        = string
  default     = "git-mgt"
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 50
}

variable "enable_imdsv2" {
  description = "Enforce IMDSv2 (recommended for security)"
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "Existing VPC ID (leave empty to create new VPC)"
  type        = string
  default     = ""
}

variable "subnet_id" {
  description = "Existing subnet ID (leave empty to create new subnet)"
  type        = string
  default     = ""
}

variable "project_name" {
  description = "Project name for resource tagging"
  type        = string
  default     = "norsk-studio"
}

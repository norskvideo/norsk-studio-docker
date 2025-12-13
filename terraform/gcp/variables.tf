# Terraform variables for Norsk Studio GCP deployment

variable "gcp_project" {
  description = "GCP project ID for deployment"
  type        = string
}

variable "gcp_region" {
  description = "GCP region for deployment"
  type        = string
  default     = "us-central1"
}

variable "gcp_zone" {
  description = "GCP zone for deployment (leave empty for auto-select from region)"
  type        = string
  default     = ""
}

variable "machine_type" {
  description = "GCP machine type (use n1-standard-4 for GPU support)"
  type        = string
  default     = "n2-standard-4"
}

variable "image_family" {
  description = "Ubuntu image family"
  type        = string
  default     = "ubuntu-2404-lts-amd64"
}

variable "image_project" {
  description = "GCP project containing the image"
  type        = string
  default     = "ubuntu-os-cloud"
}

variable "ssh_keys" {
  description = "SSH public keys for instance access (format: 'username:ssh-rsa AAAA...')"
  type        = list(string)
  default     = []
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
  description = "Norsk license JSON (stored in Secret Manager)"
  type        = string
  sensitive   = true
}

variable "studio_password" {
  description = "Norsk Studio admin password (stored in Secret Manager)"
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
  description = "Hardware profile override (auto|none|nvidia)"
  type        = string
  default     = "auto"
  validation {
    condition     = contains(["auto", "none", "nvidia"], var.hardware_profile)
    error_message = "hardware_profile must be one of: auto, none, nvidia (quadra not supported on GCP)"
  }
}

variable "repo_branch" {
  description = "Git branch to deploy"
  type        = string
  default     = "git-mgt"
}

variable "boot_disk_size" {
  description = "Boot disk size in GB"
  type        = number
  default     = 50
}

variable "boot_disk_type" {
  description = "Boot disk type (pd-standard, pd-balanced, pd-ssd)"
  type        = string
  default     = "pd-balanced"
}

variable "use_gpu" {
  description = "Attach GPU to instance (requires n1-standard machine type)"
  type        = bool
  default     = false
}

variable "gpu_type" {
  description = "GPU type (nvidia-tesla-t4, nvidia-tesla-p4, nvidia-tesla-v100)"
  type        = string
  default     = "nvidia-tesla-t4"
}

variable "gpu_count" {
  description = "Number of GPUs to attach"
  type        = number
  default     = 1
}

variable "network_name" {
  description = "Existing VPC network name (leave empty to create new VPC)"
  type        = string
  default     = ""
}

variable "subnet_name" {
  description = "Existing subnet name (leave empty to create new subnet)"
  type        = string
  default     = ""
}

variable "service_account_email" {
  description = "Existing service account email (leave empty to create new SA)"
  type        = string
  default     = ""
}

variable "project_name" {
  description = "Project name for resource labeling"
  type        = string
  default     = "norsk-studio"
}

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
}

# Data sources for image and zone lookup
data "google_compute_image" "ubuntu_2404" {
  family  = var.image_family
  project = var.image_project
}

data "google_compute_zones" "available" {
  region = var.gcp_region
  status = "UP"
}

locals {
  zone           = var.gcp_zone != "" ? var.gcp_zone : data.google_compute_zones.available.names[0]
  create_network = var.network_name == ""
  create_subnet  = var.subnet_name == ""
  create_sa      = var.service_account_email == ""
  network_name   = local.create_network ? google_compute_network.vpc[0].name : var.network_name
  subnet_name    = local.create_subnet ? google_compute_subnetwork.subnet[0].name : var.subnet_name
  sa_email       = local.create_sa ? google_service_account.norsk_studio[0].email : var.service_account_email
}

# VPC Network (if not provided)
resource "google_compute_network" "vpc" {
  count                   = local.create_network ? 1 : 0
  name                    = "${var.project_name}-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

# Subnet (if not provided)
resource "google_compute_subnetwork" "subnet" {
  count         = local.create_subnet ? 1 : 0
  name          = "${var.project_name}-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.gcp_region
  network       = local.network_name
}

# Firewall Rules
resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.project_name}-allow-ssh"
  network = local.network_name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.allowed_ssh_cidrs
  target_tags   = ["${var.project_name}-instance"]
}

resource "google_compute_firewall" "allow_http" {
  name    = "${var.project_name}-allow-http"
  network = local.network_name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = var.allowed_http_cidrs
  target_tags   = ["${var.project_name}-instance"]
}

resource "google_compute_firewall" "allow_https" {
  name    = "${var.project_name}-allow-https"
  network = local.network_name

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = var.allowed_http_cidrs
  target_tags   = ["${var.project_name}-instance"]
}

resource "google_compute_firewall" "allow_websocket" {
  name    = "${var.project_name}-allow-websocket"
  network = local.network_name

  allow {
    protocol = "tcp"
    ports    = ["6791"]
  }

  source_ranges = var.allowed_http_cidrs
  target_tags   = ["${var.project_name}-instance"]
}

resource "google_compute_firewall" "allow_udp" {
  name    = "${var.project_name}-allow-udp"
  network = local.network_name

  allow {
    protocol = "udp"
    ports    = ["5001"]
  }

  source_ranges = var.allowed_http_cidrs
  target_tags   = ["${var.project_name}-instance"]
}

# Service Account (if not provided)
resource "google_service_account" "norsk_studio" {
  count        = local.create_sa ? 1 : 0
  account_id   = "${var.project_name}-sa"
  display_name = "Norsk Studio Service Account"
  description  = "Service account for Norsk Studio instance"
}

# IAM binding for Secret Manager access
resource "google_project_iam_member" "secret_accessor" {
  project = var.gcp_project
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${local.sa_email}"

  depends_on = [google_service_account.norsk_studio]
}

resource "google_project_iam_member" "logging_writer" {
  project = var.gcp_project
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${local.sa_email}"

  depends_on = [google_service_account.norsk_studio]
}

resource "google_project_iam_member" "monitoring_writer" {
  project = var.gcp_project
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${local.sa_email}"

  depends_on = [google_service_account.norsk_studio]
}

# Secret Manager - Norsk License
resource "google_secret_manager_secret" "norsk_license" {
  secret_id = "norsk-license"

  replication {
    auto {}
  }

  labels = {
    project = var.project_name
  }
}

resource "google_secret_manager_secret_version" "norsk_license" {
  secret      = google_secret_manager_secret.norsk_license.id
  secret_data = var.norsk_license_json
}

resource "google_secret_manager_secret_iam_member" "license_access" {
  secret_id = google_secret_manager_secret.norsk_license.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.sa_email}"

  depends_on = [google_service_account.norsk_studio]
}

# Secret Manager - Studio Password
resource "google_secret_manager_secret" "studio_password" {
  secret_id = "norsk-studio-password"

  replication {
    auto {}
  }

  labels = {
    project = var.project_name
  }
}

resource "google_secret_manager_secret_version" "studio_password" {
  secret      = google_secret_manager_secret.studio_password.id
  secret_data = var.studio_password
}

resource "google_secret_manager_secret_iam_member" "password_access" {
  secret_id = google_secret_manager_secret.studio_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${local.sa_email}"

  depends_on = [google_service_account.norsk_studio]
}

# Static External IP
resource "google_compute_address" "static_ip" {
  name         = "${var.project_name}-ip"
  address_type = "EXTERNAL"
  region       = var.gcp_region
}

# Compute Instance
resource "google_compute_instance" "norsk_studio" {
  name         = "${var.project_name}-instance"
  machine_type = var.machine_type
  zone         = local.zone

  tags = ["${var.project_name}-instance"]

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu_2404.self_link
      size  = var.boot_disk_size
      type  = var.boot_disk_type
    }
  }

  network_interface {
    subnetwork = local.subnet_name

    access_config {
      nat_ip = google_compute_address.static_ip.address
    }
  }

  # GPU configuration (optional)
  dynamic "guest_accelerator" {
    for_each = var.use_gpu ? [1] : []
    content {
      type  = var.gpu_type
      count = var.gpu_count
    }
  }

  scheduling {
    # GPU instances require on_host_maintenance = TERMINATE
    on_host_maintenance = var.use_gpu ? "TERMINATE" : "MIGRATE"
    automatic_restart   = true
  }

  service_account {
    email  = local.sa_email
    scopes = ["cloud-platform"]
  }

  metadata = merge(
    {
      deploy_domain_name   = var.domain_name
      deploy_certbot_email = var.certbot_email
      hardware_profile     = var.hardware_profile
      repo_branch          = var.repo_branch
      startup-script       = templatefile("${path.module}/startup-script.sh", {
        gcp_project = var.gcp_project
        repo_branch = var.repo_branch
      })
    },
    length(var.ssh_keys) > 0 ? { ssh-keys = join("\n", var.ssh_keys) } : {}
  )

  labels = {
    project = var.project_name
  }

  lifecycle {
    ignore_changes = [
      boot_disk[0].initialize_params[0].image,
      metadata["ssh-keys"]
    ]
  }

  depends_on = [
    google_secret_manager_secret_iam_member.license_access,
    google_secret_manager_secret_iam_member.password_access,
    google_project_iam_member.secret_accessor,
    google_project_iam_member.logging_writer,
    google_project_iam_member.monitoring_writer
  ]
}

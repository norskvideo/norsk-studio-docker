# Terraform outputs for Norsk Studio GCP deployment

output "instance_id" {
  description = "Compute instance ID"
  value       = google_compute_instance.norsk_studio.instance_id
}

output "instance_name" {
  description = "Compute instance name"
  value       = google_compute_instance.norsk_studio.name
}

output "public_ip" {
  description = "Public IP address (static)"
  value       = google_compute_address.static_ip.address
}

output "private_ip" {
  description = "Private IP address"
  value       = google_compute_instance.norsk_studio.network_interface[0].network_ip
}

output "norsk_studio_url" {
  description = "Norsk Studio access URL"
  value       = var.domain_name != "" ? "https://${var.domain_name}" : "http://${google_compute_address.static_ip.address}"
}

output "ssh_command" {
  description = "SSH command to access instance"
  value       = "gcloud compute ssh ${google_compute_instance.norsk_studio.name} --zone=${local.zone}"
}

output "startup_script_log" {
  description = "Command to view startup script execution log"
  value       = "gcloud compute instances get-serial-port-output ${google_compute_instance.norsk_studio.name} --zone=${local.zone}"
}

output "zone" {
  description = "Zone used for deployment"
  value       = local.zone
}

output "network_name" {
  description = "VPC network name"
  value       = local.network_name
}

output "subnet_name" {
  description = "Subnet name"
  value       = local.subnet_name
}

output "service_account_email" {
  description = "Service account email"
  value       = local.sa_email
}

output "secret_ids" {
  description = "Secret Manager secret IDs"
  value = {
    license  = google_secret_manager_secret.norsk_license.secret_id
    password = google_secret_manager_secret.studio_password.secret_id
  }
}

output "firewall_rules" {
  description = "Firewall rule names"
  value = [
    google_compute_firewall.allow_ssh.name,
    google_compute_firewall.allow_http.name,
    google_compute_firewall.allow_https.name,
    google_compute_firewall.allow_websocket.name,
    google_compute_firewall.allow_udp.name
  ]
}

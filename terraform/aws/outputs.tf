# Terraform outputs for Norsk Studio deployment

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.norsk_studio.id
}

output "public_ip" {
  description = "Public IP address (Elastic IP)"
  value       = aws_eip.norsk_studio.public_ip
}

output "instance_public_ip" {
  description = "EC2 instance public IP (before EIP association)"
  value       = aws_instance.norsk_studio.public_ip
}

output "private_ip" {
  description = "Private IP address"
  value       = aws_instance.norsk_studio.private_ip
}

output "norsk_studio_url" {
  description = "Norsk Studio access URL"
  value       = var.domain_name != "" ? "https://${var.domain_name}" : "http://${aws_eip.norsk_studio.public_ip}"
}

output "ssh_command" {
  description = "SSH command to access instance"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${aws_eip.norsk_studio.public_ip}"
}

output "userdata_log" {
  description = "Command to view UserData execution log"
  value       = "ssh ubuntu@${aws_eip.norsk_studio.public_ip} 'sudo tail -f /var/log/ec2-userdata.log'"
}

output "vpc_id" {
  description = "VPC ID used for deployment"
  value       = local.vpc_id
}

output "subnet_id" {
  description = "Subnet ID used for deployment"
  value       = local.subnet_id
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.norsk_studio.id
}

output "iam_role_arn" {
  description = "IAM role ARN"
  value       = aws_iam_role.norsk_studio.arn
}

output "ssm_parameter_names" {
  description = "SSM parameter names for secrets"
  value = {
    license  = aws_ssm_parameter.norsk_license.name
    password = aws_ssm_parameter.studio_password.name
  }
}

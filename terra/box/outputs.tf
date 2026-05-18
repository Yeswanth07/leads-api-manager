# ──────────────────────────────────────────────
# Network
# ──────────────────────────────────────────────
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.leads.id
}

# ──────────────────────────────────────────────
# Public Access
# ──────────────────────────────────────────────
output "nginx_public_ip" {
  description = "Public IP of the Nginx reverse proxy (EIP)"
  value       = aws_eip.nginx.public_ip
}

output "bastion_public_ip" {
  description = "Public IP of the Bastion Host"
  value       = aws_instance.bastion.public_ip
}

# ──────────────────────────────────────────────
# Application URLs (via Nginx)
# ──────────────────────────────────────────────
output "app_url" {
  description = "Leads API URL via Nginx"
  value       = "http://${aws_eip.nginx.public_ip}/leads"
}

output "pgadmin_url" {
  description = "pgAdmin URL via Nginx (login: admin@admin.com / admin)"
  value       = "http://${aws_eip.nginx.public_ip}/pgadmin/"
}

output "redis_commander_url" {
  description = "Redis Commander URL via Nginx"
  value       = "http://${aws_eip.nginx.public_ip}/redis/"
}

output "kibana_url" {
  description = "Kibana URL via Nginx"
  value       = "http://${aws_eip.nginx.public_ip}/kibana/"
}

# ──────────────────────────────────────────────
# Private Backend
# ──────────────────────────────────────────────
output "main_private_ip" {
  description = "Private IP of the consolidated backend server"
  value       = aws_instance.main.private_ip
}

# ──────────────────────────────────────────────
# SSH Commands
# ──────────────────────────────────────────────
output "ssh_bastion" {
  description = "SSH command to connect to the Bastion Host"
  value       = "ssh -i ${local_file.private_key.filename} ubuntu@${aws_instance.bastion.public_ip}"
}

output "ssh_main_via_bastion" {
  description = "SSH command to reach the private backend via Bastion (ProxyJump)"
  value       = "ssh -i ${local_file.private_key.filename} -J ubuntu@${aws_instance.bastion.public_ip} ubuntu@${aws_instance.main.private_ip}"
}

output "private_key_file" {
  description = "Path to the generated SSH private key file"
  value       = local_file.private_key.filename
}

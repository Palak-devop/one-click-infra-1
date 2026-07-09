output "jenkins_bastion_public_ip" {
  description = "Public IP of Jenkins / Bastion Host"
  value       = aws_instance.jenkins_bastion.public_ip
}

output "vm_insert_select_1_private_ip" {
  description = "Private IP of VM Ingestion/Query 1"
  value       = aws_instance.vm_insert_select_1.private_ip
}

output "vm_storage_1_private_ip" {
  description = "Private IP of VM Storage 1"
  value       = aws_instance.vm_storage_1.private_ip
}

output "vm_insert_select_2_private_ip" {
  description = "Private IP of VM Ingestion/Query 2"
  value       = aws_instance.vm_insert_select_2.private_ip
}

output "vm_storage_2_private_ip" {
  description = "Private IP of VM Storage 2"
  value       = aws_instance.vm_storage_2.private_ip
}

output "monitoring_private_ip" {
  description = "Private IP of Monitoring Host (Nginx/Exporters/vmagent)"
  value       = aws_instance.monitoring.private_ip
}

output "grafana_private_ip" {
  description = "Private IP of Grafana Server"
  value       = aws_instance.grafana.private_ip
}

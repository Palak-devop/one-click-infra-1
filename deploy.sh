#!/bin/bash
# Master deployment script for one-click infrastructure provisioning and monitoring stack setup.
set -e

echo "=========================================================="
echo "🚀 Starting One-Click Monitoring Stack Deploy..."
echo "=========================================================="

# Check if AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
  echo "❌ Error: AWS CLI credentials not configured. Please run 'aws configure' first."
  exit 1
fi

# Navigate to terraform directory and run apply
echo "1. Provisioning AWS Infrastructure via Terraform..."
cd terraform
terraform init
terraform apply -auto-approve

# Extract IP addresses from Terraform outputs
echo "2. Extracting resource IP addresses..."
bastion_ip=$(terraform output -raw jenkins_bastion_public_ip)
vm_insert_select_1_ip=$(terraform output -raw vm_insert_select_1_private_ip)
vm_storage_1_ip=$(terraform output -raw vm_storage_1_private_ip)
vm_insert_select_2_ip=$(terraform output -raw vm_insert_select_2_private_ip)
vm_storage_2_ip=$(terraform output -raw vm_storage_2_private_ip)
monitoring_ip=$(terraform output -raw monitoring_private_ip)
grafana_ip=$(terraform output -raw grafana_private_ip)

cd ..

# Generate dynamic Ansible inventory from template
echo "3. Generating Ansible Inventory file..."
sed -e "s/\${bastion_public_ip}/$bastion_ip/g" \
    -e "s/\${vm_insert_select_1_private_ip}/$vm_insert_select_1_ip/g" \
    -e "s/\${vm_storage_1_private_ip}/$vm_storage_1_ip/g" \
    -e "s/\${vm_insert_select_2_private_ip}/$vm_insert_select_2_ip/g" \
    -e "s/\${vm_storage_2_private_ip}/$vm_storage_2_ip/g" \
    -e "s/\${monitoring_private_ip}/$monitoring_ip/g" \
    -e "s/\${grafana_private_ip}/$grafana_ip/g" \
    ansible/inventory.ini.tpl > ansible/inventory.ini

echo "Ansible Inventory created successfully!"

# Check if monitoring-key.pem exists
if [ ! -f "terraform/monitoring-key.pem" ]; then
  echo "⚠️ Warning: 'terraform/monitoring-key.pem' not found. Please place your private SSH key in that path to allow Ansible connections."
  echo "Once placed, run the following manually to finish configuration:"
  echo "  cp terraform/monitoring-key.pem ansible/monitoring-key.pem && chmod 400 ansible/monitoring-key.pem"
  echo "  cd ansible && ansible-playbook -i inventory.ini playbook.yml"
  exit 0
fi

# Copy key to ansible directory and restrict permissions
cp terraform/monitoring-key.pem ansible/monitoring-key.pem
chmod 400 ansible/monitoring-key.pem

# Run Ansible Playbook
echo "4. Deploying VictoriaMetrics Cluster, Exporters, and Grafana via Ansible..."
cd ansible
ansible-playbook -i inventory.ini playbook.yml

# Clean up SSH key copy
rm -f monitoring-key.pem

echo "=========================================================="
echo "🎉 Deployment Completed Successfully!"
echo "=========================================================="
echo "Access points:"
echo "  - Jenkins Host: http://${bastion_ip}:8080"
echo "  - Grafana Host (Private): http://${grafana_ip}:3000"
echo "  - Local Port Forwarding Tunnel for Grafana:"
echo "    ssh -N -L 3000:${grafana_ip}:3000 -i terraform/monitoring-key.pem ubuntu@${bastion_ip}"
echo "=========================================================="

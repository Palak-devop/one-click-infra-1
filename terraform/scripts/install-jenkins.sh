#!/bin/bash
# Bootstrap Script to install Jenkins, Git, Terraform, and Ansible on EC2-1 (Ubuntu 22.04 LTS)
set -e

echo "Starting Jenkins and DevOps tools installation..."

# Update system
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install -y gnupg software-properties-common curl git unzip wget

# 1. Install Java OpenJDK 17 (Required for Jenkins)
sudo apt-get install -y openjdk-17-jdk openjdk-17-jre

# 2. Install Jenkins
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/" | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y jenkins

# Enable & Start Jenkins Service
sudo systemctl enable jenkins
sudo systemctl start jenkins

# 3. Install Terraform
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com/gpg $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update -y
sudo apt-get install -y terraform

# 4. Install Ansible
sudo apt-add-repository --yes --update ppa:ansible/ansible
sudo apt-get install -y ansible

# Configure permissions for Jenkins user to run commands
sudo mkdir -p /var/lib/jenkins/.ssh
sudo chown -R jenkins:jenkins /var/lib/jenkins/.ssh
sudo chmod 700 /var/lib/jenkins/.ssh

# Allow jenkins user to run passwordless sudo (needed for some local command operations if any)
echo "jenkins ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/jenkins

echo "DevOps environment configuration complete!"

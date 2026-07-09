# AWS Clustered Monitoring Stack: VictoriaMetrics & Grafana

This repository contains the complete Infrastructure-as-Code (Terraform) and Configuration Management (Ansible) codebase to deploy a production-grade, highly-available, and secure monitoring system on AWS. The setup features a **VictoriaMetrics Cluster** (`vmstorage`, `vminsert`, `vmselect`), **Grafana** with auto-provisioned dashboards, and metric collection agents (`vmagent` and Prometheus exporters) running in private subnets across two Availability Zones (AZs) in the `ap-south-1` region (Mumbai).

---

## 🏗️ Architecture Design (7 EC2 Instances)

```
                       [ Developer / Operator ]
                                  │
                          (Public Subnet 1)
                                  │
                     ┌────────────▼────────────┐
                     │    EC2-1: Jenkins       │ (Ansible Controller / Bastion)
                     │    (Port 8080, SSH 22)  │
                     └────────────┬────────────┘
                                  │ (SSH Jump Tunnel)
         ┌────────────────────────┼────────────────────────┐
         ▼ (Private Subnet 1 - AZ-a)                      ▼ (Private Subnet 2 - AZ-b)
  ┌──────────────┐                                 ┌──────────────┐
  │    EC2-6:    │ (Nginx Web Server               │    EC2-7:    │ (Grafana Server
  │  Monitoring  │  + exporters + vmagent)         │   Grafana    │  Port 3000)
  └──────┬───────┘                                 └──────┬───────┘
         │ (Writes metrics to Ingestion)                  │ (Queries metrics)
         ├────────────────────────┬───────────────────────┤
         ▼                        ▼                       ▼
  ┌──────────────┐         ┌──────────────┐        ┌──────────────┐
  │    EC2-2:    │         │    EC2-4:    │        │  vmselect    │ (Query API
  │  vminsert-1  │         │  vminsert-2  │        │ (Dual Nodes) │  Port 8481)
  └──────┬───────┘         └──────┬───────┘        └──────┬───────┘
         │                        │                       │
         └───────────┬────────────┘                       │ (Queries storage)
                     ▼                                    │
         ┌────────────────────────┐                       │
         │  Storage Layer (8400)  ◄───────────────────────┘
         ├────────────────────────┤
         ▼                        ▼
  ┌──────────────┐         ┌──────────────┐
  │    EC2-3:    │         │    EC2-5:    │
  │ vmstorage-1  │         │ vmstorage-2  │
  │ (EBS Volume) │         │ (EBS Volume) │
  └──────────────┘         └──────────────┘
```

---

## 🟢 PHASE 1 - Local Machine Preparation

Before starting, configure your local development machine with the required tools:

### 1. Install Ubuntu WSL (Windows Subsystem for Linux)
Open PowerShell as Administrator and run:
```powershell
wsl --install -d Ubuntu
```
Restart your computer if prompted, and configure your Ubuntu UNIX username and password.

### 2. Install Required Packages inside WSL
Open your Ubuntu WSL terminal and run:
```bash
sudo apt-get update && sudo apt-get install -y git curl unzip gnupg software-properties-common
```

### 3. Install AWS CLI & Configure Credentials
```bash
# Download and Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip

# Configure your AWS credentials
aws configure
# Enter your AWS Access Key, Secret Access Key, Default Region (ap-south-1), and Output format (json)
```

### 4. Install Terraform CLI
```bash
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com/gpg $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install -y terraform
```

### 5. Install Ansible
```bash
sudo apt-add-repository --yes --update ppa:ansible/ansible
sudo apt-get install -y ansible
```

---

## 🟢 PHASE 2 - Initialize GitHub Repository

Create a private or public GitHub repository named `victoriametrics-monitoring-project` and push this codebase to it.

```bash
# Initialize and push to your git repository
git init
git add .
git commit -m "feat: Add Terraform, Ansible, and Jenkins monitoring stack codebase"
git branch -M main
git remote add origin https://github.com/YOUR_GITHUB_USERNAME/victoriametrics-monitoring-project.git
git push -u origin main
```

---

## 🟢 PHASE 3 - Initial AWS Infrastructure Provisioning

To set up the Jenkins server and routing baseline, run Terraform locally first.

### 1. Generate SSH Key Pair in AWS Console
1. Log in to your AWS Console, navigate to **EC2** > **Key Pairs**.
2. Click **Create key pair**.
3. Name: `monitoring-key`, Format: `pem`.
4. Click Create and download the `monitoring-key.pem` file. Save it inside your local workspace directory (`Tool_evaluation/terraform/` or copy it to WSL `~/.ssh/monitoring-key.pem`).
5. Set permission for the key: `chmod 400 monitoring-key.pem`.

### 2. Deploy Infrastructure
In your WSL terminal:
```bash
cd terraform/
terraform init
terraform plan
terraform apply -auto-approve
```
*Wait ~5-7 minutes.* Terraform will provision the entire VPC network, set up the NAT Gateway, create the Bastion/Jenkins host (`EC2-1`), provision the private EC2 instances, attach the EBS volumes, and output the IP addresses.

### 3. Bootstrap Jenkins Server
The `EC2-1` Jenkins server uses a startup user-data script to automatically install **Jenkins**, **Git**, **Terraform**, and **Ansible**.
1. Copy the output `jenkins_bastion_public_ip`.
2. Connect to the Jenkins Web Console: `http://<jenkins_bastion_public_ip>:8080`.
3. To retrieve the Administrator password, SSH into the host:
   ```bash
   ssh -i /path/to/monitoring-key.pem ubuntu@<jenkins_bastion_public_ip>
   ```
4. Run the following command to get the password:
   ```bash
   sudo cat /var/lib/jenkins/secrets/initialAdminPassword
   ```
5. Paste this password into the Jenkins web interface, install suggested plugins, and create an Admin User.

---

## 🟢 PHASE 4 - Setup GitHub Webhook & Jenkins Pipeline

### 1. Add GitHub Webhook
1. Go to your GitHub repository > **Settings** > **Webhooks** > **Add webhook**.
2. Payload URL: `http://<jenkins_bastion_public_ip>:8080/github-webhook/`.
3. Content type: `application/json`.
4. Events: Just the `push` event.
5. Click **Add webhook**.

### 2. Configure Credentials in Jenkins Console
Navigate to **Jenkins Dashboard** > **Manage Jenkins** > **Credentials** > **System** > **Global credentials (unrestricted)**. Add two credentials:

1. **AWS Credentials**:
   - Kind: `Username with password`
   - Scope: `Global`
   - ID: `aws-credentials`
   - Username: `<Your_AWS_Access_Key_ID>`
   - Password: `<Your_AWS_Secret_Access_Key>`
   
2. **SSH Key Credential**:
   - Kind: `Secret file`
   - Scope: `Global`
   - ID: `monitoring-ssh-key`
   - Upload File: Upload your downloaded `monitoring-key.pem` private key.

### 3. Create Pipeline Job
1. Click **New Item** > Name: `monitoring-infrastructure-pipeline` > Select **Pipeline** > Click **OK**.
2. Under **General**, check **GitHub project** and enter your repo URL.
3. Under **Build Triggers**, check **GitHub hook trigger for GITScm polling**.
4. Under **Pipeline**:
   - Definition: `Pipeline script from SCM`
   - SCM: `Git`
   - Repository URL: `https://github.com/YOUR_GITHUB_USERNAME/victoriametrics-monitoring-project.git`
   - Branch Specifier: `*/main`
   - Script Path: `Jenkinsfile`
5. Click **Save**.

---

## 🟢 PHASE 5, 6 & 7 - Automated Deployment via Jenkins

1. Run the build once manually by clicking **Build with Parameters** > Select **ACTION: `apply`** > **Build**.
2. Jenkins will pull the code, verify the infrastructure state, export the private IPs into `ansible/inventory.ini`, copy the private SSH key, and execute the Ansible playbook.
3. Ansible will configure the nodes through the Bastion proxy tunnel:
   - Sets up system services and standard tools (`common` role).
   - Formats and mounts the EBS volumes on the two storage nodes (`vmstorage-1` and `vmstorage-2`).
   - Configures the dual `vminsert` nodes to stream metrics across both storage nodes.
   - Configures the dual `vmselect` nodes to fetch query results.
   - Installs Nginx and `nginx_exporter` on `EC2-6`.
   - Configures `vmagent` on `EC2-6` to scrape system metrics and stream them to the cluster.
   - Installs and boots Grafana on `EC2-7`, automatically loading the VictoriaMetrics datasources and preloaded system dashboards.

---

## 🟢 PHASE 8 - Monitoring Dashboard Verification

Since Grafana (`EC2-7`) and VictoriaMetrics are inside private subnets, they are not exposed directly to the internet. 

### Accessing Grafana
1. Run an SSH local port-forwarding tunnel from your local WSL machine:
   ```bash
   ssh -N -L 3000:<grafana_private_ip>:3000 -i /path/to/monitoring-key.pem ubuntu@<jenkins_bastion_public_ip>
   ```
   *(Find the `grafana_private_ip` and `jenkins_bastion_public_ip` in the Jenkins console log or Terraform outputs).*
2. Open your web browser locally and navigate to: `http://localhost:3000`.
3. Log in using default credentials:
   - Username: `admin`
   - Password: `admin` *(You will be prompted to set a new password).*
4. Navigate to **Dashboards** > **Browse**. You will see:
   - **System Node Exporter Dashboard**: Shows real-time CPU, RAM, Disk, and Network metrics of all 6 private subnet nodes.
   - **Nginx Web Server Dashboard**: Monitors active connections and request rates generated on the Nginx monitoring server.

---

## 🟢 PHASE 9 & 10 - High Availability & Disaster Recovery

### Clustered High Availability
- **Ingestion**: If `vminsert-1` goes down, `vmagent` continues streaming metrics to `vminsert-2` without data loss.
- **Storage**: Storage nodes (`vmstorage-1` and `vmstorage-2`) store partitions independently.
- **Query**: Grafana can query either `vmselect-1` or `vmselect-2` datasource seamlessly.

### Disaster Recovery EBS Snapshots
To back up the data stored in VictoriaMetrics volumes:
1. Log into the Jenkins server.
2. The script located at `scripts/snapshot.sh` takes automated AWS snapshots of the active storage volumes.
3. You can set this script to run daily on the host using `cron`:
   ```bash
   crontab -e
   # Add the following line to run daily backups at midnight:
   0 0 * * * /home/ubuntu/scripts/snapshot.sh >> /var/log/vm_backup.log 2>&1
   ```

---

## 🟢 Clean Up (Destroying Infrastructure to save credits)

To avoid incurring unexpected charges on your AWS credits:
1. Open the Jenkins pipeline dashboard.
2. Click **Build with Parameters** > Select **ACTION: `destroy`** > **Build**.
3. Jenkins will execute `terraform destroy` and cleanly delete all instances, EBS volumes, security groups, and networking components.
4. Alternatively, you can run the destroy command from your local machine's WSL terminal inside the `terraform` directory:
   ```bash
   terraform destroy -auto-approve
   ```

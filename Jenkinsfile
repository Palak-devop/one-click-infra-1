pipeline {
    agent any

    parameters {
        choice(name: 'ACTION', choices: ['apply', 'destroy'], description: 'Terraform Action to Perform')
    }

    environment {
        AWS_CREDENTIALS = credentials('aws-credentials') // Jenkins AWS Credentials ID
        SSH_KEY_CREDENTIAL = credentials('monitoring-ssh-key') // Jenkins SSH Key Credential ID (Secret File)
        TF_VAR_jenkins_instance_type = "t3.micro"
        TF_VAR_vm_instance_type = "t3.micro"
        TF_VAR_monitoring_instance_type = "t3.micro"
        TF_VAR_grafana_instance_type = "t3.micro"
    }

    stages {
        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Init') {
            steps {
                withEnv(["AWS_ACCESS_KEY_ID=${env.AWS_CREDENTIALS_USR}", "AWS_SECRET_ACCESS_KEY=${env.AWS_CREDENTIALS_PSW}"]) {
                    sh 'terraform -chdir=terraform init'
                }
            }
        }

        stage('Terraform Plan') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                withEnv(["AWS_ACCESS_KEY_ID=${env.AWS_CREDENTIALS_USR}", "AWS_SECRET_ACCESS_KEY=${env.AWS_CREDENTIALS_PSW}"]) {
                    sh 'terraform -chdir=terraform plan -out=tfplan'
                }
            }
        }

        stage('Terraform Apply / Destroy') {
            steps {
                withEnv(["AWS_ACCESS_KEY_ID=${env.AWS_CREDENTIALS_USR}", "AWS_SECRET_ACCESS_KEY=${env.AWS_CREDENTIALS_PSW}"]) {
                    script {
                        if (params.ACTION == 'apply') {
                            sh 'terraform -chdir=terraform apply -auto-approve tfplan'
                        } else {
                            sh 'terraform -chdir=terraform destroy -auto-approve'
                        }
                    }
                }
            }
        }

        stage('Configure Ansible Inventory') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                sh '''
                bastion_ip=$(terraform -chdir=terraform output -raw jenkins_bastion_public_ip)
                vm_insert_select_1_ip=$(terraform -chdir=terraform output -raw vm_insert_select_1_private_ip)
                vm_storage_1_ip=$(terraform -chdir=terraform output -raw vm_storage_1_private_ip)
                vm_insert_select_2_ip=$(terraform -chdir=terraform output -raw vm_insert_select_2_private_ip)
                vm_storage_2_ip=$(terraform -chdir=terraform output -raw vm_storage_2_private_ip)
                monitoring_ip=$(terraform -chdir=terraform output -raw monitoring_private_ip)
                grafana_ip=$(terraform -chdir=terraform output -raw grafana_private_ip)

                sed -e "s/\\${bastion_public_ip}/$bastion_ip/g" \
                    -e "s/\\${vm_insert_select_1_private_ip}/$vm_insert_select_1_ip/g" \
                    -e "s/\\${vm_storage_1_private_ip}/$vm_storage_1_ip/g" \
                    -e "s/\\${vm_insert_select_2_private_ip}/$vm_insert_select_2_ip/g" \
                    -e "s/\\${vm_storage_2_private_ip}/$vm_storage_2_ip/g" \
                    -e "s/\\${monitoring_private_ip}/$monitoring_ip/g" \
                    -e "s/\\${grafana_private_ip}/$grafana_ip/g" \
                    ansible/inventory.ini.tpl > ansible/inventory.ini
                '''
            }
        }

        stage('Execute Ansible Playbook') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                // Copy the SSH key from Jenkins credentials to the workspace and set correct permissions
                sh 'rm -f ansible/monitoring-key.pem'
                sh 'cp $SSH_KEY_CREDENTIAL ansible/monitoring-key.pem'
                sh 'chmod 400 ansible/monitoring-key.pem'

                // Run Ansible Playbook using the generated inventory
                sh 'cd ansible && ansible-playbook -i inventory.ini playbook.yml'

                // Clean up key from workspace
                sh 'rm -f ansible/monitoring-key.pem'
            }
        }

        stage('Post-Deployment Health Check') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                script {
                    def grafana_ip = sh(script: 'terraform -chdir=terraform output -raw grafana_private_ip', returnStdout: true).trim()
                    def bastion_ip = sh(script: 'terraform -chdir=terraform output -raw jenkins_bastion_public_ip', returnStdout: true).trim()
                    
                    echo "Infrastructure successfully created!"
                    echo "Access your Bastion/Jenkins Host at: http://${bastion_ip}:8080"
                    echo "Access Grafana within the VPC at: http://${grafana_ip}:3000"
                    echo "Set up SSH tunnel to access Grafana locally: ssh -L 3000:${grafana_ip}:3000 -i <key.pem> ubuntu@${bastion_ip}"
                }
            }
        }
    }
}

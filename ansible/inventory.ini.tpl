[jenkins_bastion]
bastion ansible_host=${bastion_public_ip}

[vm_insert_select]
vm-insert-select-1 ansible_host=${vm_insert_select_1_private_ip}
vm-insert-select-2 ansible_host=${vm_insert_select_2_private_ip}

[vm_storage]
vm-storage-1 ansible_host=${vm_storage_1_private_ip}
vm-storage-2 ansible_host=${vm_storage_2_private_ip}

[monitoring]
monitoring-node ansible_host=${monitoring_private_ip}

[grafana]
grafana-node ansible_host=${grafana_private_ip}

[private_hosts:children]
vm_insert_select
vm_storage
monitoring
grafana

[private_hosts:vars]
ansible_ssh_private_key_file=./monitoring-key.pem
ansible_ssh_common_args='-o StrictHostKeyChecking=no'

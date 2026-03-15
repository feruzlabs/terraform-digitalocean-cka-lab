output "master_ip" {
  description = "Master node public IP address"
  value       = digitalocean_droplet.master.ipv4_address
}

output "worker_ips" {
  description = "Worker nodes public IP addresses"
  value       = digitalocean_droplet.worker[*].ipv4_address
}

output "kubeconfig_command" {
  description = "Run this command to save kubeconfig locally (replace with your key path if needed)"
  value       = "ssh -o StrictHostKeyChecking=no root@${digitalocean_droplet.master.ipv4_address} 'sudo cat /etc/kubernetes/admin.conf' > kubeconfig && export KUBECONFIG=$PWD/kubeconfig"
}

output "ssh_master" {
  description = "SSH command to connect to master"
  value       = "ssh root@${digitalocean_droplet.master.ipv4_address}"
}

output "kubeconfig_setup" {
  description = "Commands to configure local kubectl with the cluster"
  value       = <<-EOT
    Run these commands to configure local kubectl:

    ssh root@${digitalocean_droplet.master.ipv4_address} \
      'cat /etc/kubernetes/admin.conf' > ~/.kube/config

    sed -i 's/127.0.0.1/${digitalocean_droplet.master.ipv4_address}/' \
      ~/.kube/config

    kubectl get nodes
  EOT
}

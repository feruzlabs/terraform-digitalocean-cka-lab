#!/bin/bash
set -e

echo "=== Configuring Kubernetes master (kubeadm init + Flannel) ==="

# Disable swap at runtime (required for kubelet)
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/' /etc/fstab

# Enable SSH password login for root
echo "root:TestPassword123!" | chpasswd
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd

# Load modules and set sysctl at runtime
modprobe overlay
modprobe br_netfilter
sysctl -p /etc/sysctl.d/k8s.conf 2>/dev/null || true

# Initialize control plane (Flannel CIDR)
kubeadm init --pod-network-cidr=192.168.0.0/16

# Setup kubeconfig for root
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config
chown root:root /root/.kube/config

kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml

echo "Waiting for Calico to be ready..."
sleep 30

kubectl -n kube-system set env daemonset/calico-node \
  CALICO_IPV4POOL_IPIP=Never \
  CALICO_IPV4POOL_VXLAN=Always

# Generate join command for workers and serve via HTTP so workers can fetch without SSH
kubeadm token create --print-join-command > /tmp/join-command
chmod 644 /tmp/join-command
nohup python3 -m http.server 8080 --directory /tmp \
  > /tmp/http-server.log 2>&1 &
sleep 2
echo "HTTP server started, testing..."
curl -sf http://localhost:8080/join-command && \
  echo "HTTP server OK" || echo "WARNING: HTTP server not responding"

echo "=== Master node ready. Join command at /tmp/join-command, HTTP server on port 8080 ==="

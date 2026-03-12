#!/bin/bash
set -e

# Wait for cloud-init to fully complete first
echo "Waiting for cloud-init to finish..."
cloud-init status --wait 2>/dev/null || sleep 60

# Now stop all apt related services
systemctl stop unattended-upgrades 2>/dev/null || true
systemctl disable unattended-upgrades 2>/dev/null || true
systemctl stop apt-daily.timer 2>/dev/null || true
systemctl stop apt-daily-upgrade.timer 2>/dev/null || true
systemctl disable apt-daily.timer 2>/dev/null || true
systemctl disable apt-daily-upgrade.timer 2>/dev/null || true

# Kill any remaining apt/dpkg processes
pkill -f apt-get 2>/dev/null || true
pkill -f dpkg 2>/dev/null || true
sleep 3

# Clean up any stale locks
rm -f /var/lib/apt/lists/lock
rm -f /var/lib/dpkg/lock-frontend
rm -f /var/lib/dpkg/lock
rm -f /var/cache/apt/archives/lock
dpkg --configure -a 2>/dev/null || true

echo "System ready for apt operations"

echo "=== Installing Kubernetes master with kubeadm ==="

# Disable swap (required for kubelet)
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/' /etc/fstab

# Enable SSH password login for root
echo "root:TestPassword123!" | chpasswd
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd

# Load modules and set sysctl
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

# Install containerd
apt-get update
apt-get install -y ca-certificates curl gnupg apt-transport-https

install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Verify key was imported
gpg --no-default-keyring \
  --keyring /etc/apt/keyrings/docker.gpg \
  --fingerprint 2>/dev/null || true

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y containerd.io

mkdir -p /etc/containerd
containerd config default | sed 's/SystemdCgroup = false/SystemdCgroup = true/' | tee /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

# Install kubeadm, kubelet, kubectl
apt-get install -y apt-transport-https
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
systemctl enable kubelet

# Initialize control plane (Flannel CIDR)
kubeadm init --pod-network-cidr=10.244.0.0/16

# Setup kubeconfig for root
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config
chown root:root /root/.kube/config

# Install Flannel CNI (pinned version)
kubectl apply -f https://github.com/flannel-io/flannel/releases/download/v0.25.1/kube-flannel.yml

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

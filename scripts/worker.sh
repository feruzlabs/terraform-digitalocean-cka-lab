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

MASTER_IP="${master_ip}"

echo "=== Installing Kubernetes worker (joining master $MASTER_IP) ==="

# Disable swap
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/' /etc/fstab

# Enable SSH password login for root
echo "root:TestPassword123!" | chpasswd
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd

# Load modules and sysctl
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

# Install kubeadm, kubelet (no kubectl needed on workers)
apt-get install -y apt-transport-https
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet kubeadm
apt-mark hold kubelet kubeadm
systemctl enable kubelet

# Wait for master to be ready and fetch join command via HTTP (curl avoids set -e exit on failure)
echo "Waiting for master to be ready..."
JOIN_CMD=""
for i in $(seq 1 60); do
  JOIN_CMD=$(curl -sf http://$MASTER_IP:8080/join-command || true)
  if [ -n "$JOIN_CMD" ]; then
    echo "Master ready, joining cluster..."
    break
  fi
  echo "Attempt $i/60: master not ready, retrying in 10s..."
  sleep 10
done

if [ -z "$JOIN_CMD" ]; then
  echo "ERROR: Failed to get join command from master after 60 attempts"
  exit 1
fi

sudo $JOIN_CMD

echo "=== Worker joined cluster ==="

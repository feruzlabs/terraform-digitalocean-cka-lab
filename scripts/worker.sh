#!/bin/bash
set -e

MASTER_IP="${master_ip}"

echo "=== Configuring Kubernetes worker (joining master $MASTER_IP) ==="

# Disable swap at runtime
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

# CKA Lab – Kubernetes cluster on DigitalOcean

Terraform project to deploy a small Kubernetes cluster on DigitalOcean for **CKA exam practice**.

## Quick Start (First time setup)

1. Install: **terraform**, **packer**, **git**
2. Get a [DigitalOcean API token](https://cloud.digitalocean.com/account/api/tokens)
3. Create an SSH key: `ssh-keygen -t rsa -b 4096`
4. Clone the repo and `cd cka-lab`
5. Create `terraform.tfvars` with your credentials:
   ```hcl
   do_token             = "your-digitalocean-api-token"
   ssh_public_key_path  = "/path/to/your/id_rsa.pub"
   ssh_private_key_path = "/path/to/your/id_rsa"
   ```
6. Run: **`make setup`** (builds Packer image + inits Terraform)
7. Run: **`make up`** (creates the cluster)
8. Done! Get kubeconfig from Terraform output, then: **`kubectl get nodes`**

## Daily use

| Command     | Description              |
|------------|---------------------------|
| `make up`  | Cluster yaratish (create) |
| `make down`| Cluster o'chirish (destroy) |

## What you get

| Node   | Size           | Cost   |
|--------|----------------|--------|
| 1 master | s-2vcpu-4gb  | $24/mo |
| 2 workers | s-2vcpu-2gb each | $18/mo each |

- **Region:** Frankfurt (fra1)
- **OS:** Ubuntu 22.04
- **Kubernetes:** installed with kubeadm, **Flannel** as CNI

## Prerequisites

1. [Terraform](https://www.terraform.io/downloads) installed (e.g. 1.x).
2. [Packer](https://www.packer.io/downloads) installed (optional; for building the custom K8s node image).
3. [DigitalOcean](https://www.digitalocean.com/) account and **API token**.
4. SSH key pair (e.g. `~/.ssh/id_rsa` and `~/.ssh/id_rsa.pub`).

## Build the Kubernetes node image (Packer)

Build a custom image with Kubernetes 1.28 (containerd, kubeadm, kubelet, kubectl) pre-installed. This speeds up cluster creation and avoids apt/cloud-init issues at runtime.

```bash
cd cka-lab
packer init packer/
packer build -var do_token=YOUR_TOKEN packer/k8s-node.pkr.hcl
```

Replace `YOUR_TOKEN` with your DigitalOcean API token. When the build finishes, a snapshot named **cka-k8s-node-1-28** will appear in your account. Terraform will use it automatically when you run `terraform apply`.

If you skip this step, Terraform will use the default `ubuntu-22-04-x64` image and install Kubernetes on each droplet at boot (slower, more prone to apt locks).

## Setup

1. Clone or copy this project and go to the folder:
   ```bash
   cd cka-lab
   ```

2. Create `terraform.tfvars` and set **required** variables (or use env vars):
   ```hcl
   do_token             = "your-digitalocean-api-token"
   ssh_public_key_path  = "C:/Users/You/.ssh/id_rsa.pub"   # Windows
   ssh_private_key_path = "C:/Users/You/.ssh/id_rsa"       # Windows
   ```
   On Linux/macOS you can use `~/.ssh/id_rsa.pub` and `~/.ssh/id_rsa`.

   Or use environment variables (no need to put token in a file):
   ```bash
   export TF_VAR_do_token="your-token"
   export TF_VAR_ssh_public_key_path="$HOME/.ssh/id_rsa.pub"
   export TF_VAR_ssh_private_key_path="$HOME/.ssh/id_rsa"
   ```

3. Initialize Terraform:
   ```bash
   terraform init
   ```

## Commands

### Create the cluster (cluster yaratish)

```bash
terraform apply
```

Type `yes` when asked. This will:

- Create 1 master and 2 worker droplets in Frankfurt.
- Run `master.sh` on the master (kubeadm init + Flannel).
- Run `worker.sh` on each worker (kubeadm join).

Takes about 10–15 minutes. When it finishes, Terraform will print **master IP**, **worker IPs**, and the **kubeconfig** command.

### Get kubeconfig

After `terraform apply` succeeds, run the command Terraform shows, for example:

```bash
ssh -o StrictHostKeyChecking=no root@<MASTER_IP> 'sudo cat /etc/kubernetes/admin.conf' > kubeconfig
export KUBECONFIG=$PWD/kubeconfig
```

Then:

```bash
kubectl get nodes
```

You should see the master and two workers as `Ready`.

### Destroy the cluster (cluster o'chirish)

```bash
terraform destroy
```

Type `yes` when asked. This deletes all droplets and stops billing.

## File structure

```
cka-lab/
├── main.tf          # Provider, snapshot data source, droplets, provisioners
├── variables.tf     # Input variables (incl. k8s_snapshot_name)
├── outputs.tf       # master IP, worker IPs, kubeconfig command
├── terraform.tfvars # Your values (create from example)
├── README.md
├── packer/
│   ├── k8s-node.pkr.hcl   # Packer config (DO snapshot cka-k8s-node-1-28)
│   └── scripts/
│       └── install-k8s.sh # Pre-install containerd + kubeadm 1.28 in image
└── scripts/
    ├── master.sh    # kubeadm init + Flannel on master (runtime only)
    └── worker.sh    # kubeadm join on workers (runtime only)
```

## Tips

- Keep your **DO API token** and **SSH private key** secret; don’t commit them.
- If a run fails, fix the issue and run `terraform apply` again; Terraform will continue from the last state.
- For CKA practice, use `kubectl` with `KUBECONFIG` pointing to the downloaded `kubeconfig` file.

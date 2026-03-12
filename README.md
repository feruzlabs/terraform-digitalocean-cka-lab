# CKA Lab – Kubernetes cluster on DigitalOcean

Terraform project to deploy a small Kubernetes cluster on DigitalOcean for **CKA exam practice**.

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
2. [DigitalOcean](https://www.digitalocean.com/) account and **API token**.
3. SSH key pair (e.g. `~/.ssh/id_rsa` and `~/.ssh/id_rsa.pub`).

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
├── main.tf          # Provider, droplets, provisioners
├── variables.tf     # Input variables
├── outputs.tf       # master IP, worker IPs, kubeconfig command
├── terraform.tfvars # Your values (create from example)
├── README.md
└── scripts/
    ├── master.sh    # kubeadm init + Flannel on master
    └── worker.sh    # kubeadm join on workers
```

## Tips

- Keep your **DO API token** and **SSH private key** secret; don’t commit them.
- If a run fails, fix the issue and run `terraform apply` again; Terraform will continue from the last state.
- For CKA practice, use `kubectl` with `KUBECONFIG` pointing to the downloaded `kubeconfig` file.

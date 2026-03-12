terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

# SSH key added to all droplets (use your public key)
resource "digitalocean_ssh_key" "cka" {
  name       = "cka-lab-${terraform.workspace}"
  public_key = file(var.ssh_public_key_path)
}

# Master node (control plane)
resource "digitalocean_droplet" "master" {
  name   = "cka-master"
  region = var.region
  size   = var.master_size
  image  = var.image

  ssh_keys = [digitalocean_ssh_key.cka.fingerprint]

  connection {
    type        = "ssh"
    user        = "root"
    host        = self.ipv4_address
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "file" {
    source      = "${path.module}/scripts/master.sh"
    destination = "/tmp/master.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/master.sh",
      "/tmp/master.sh"
    ]
  }
}

# Worker nodes
resource "digitalocean_droplet" "worker" {
  count  = var.worker_count
  name   = "cka-worker-${count.index + 1}"
  region = var.region
  size   = var.worker_size
  image  = var.image

  depends_on = [digitalocean_droplet.master]

  ssh_keys = [digitalocean_ssh_key.cka.fingerprint]

  connection {
    type        = "ssh"
    user        = "root"
    host        = self.ipv4_address
    private_key = file(var.ssh_private_key_path)
  }

  provisioner "file" {
    content     = templatefile("${path.module}/scripts/worker.sh", { master_ip = digitalocean_droplet.master.ipv4_address })
    destination = "/tmp/worker.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/worker.sh",
      "/tmp/worker.sh"
    ]
  }
}

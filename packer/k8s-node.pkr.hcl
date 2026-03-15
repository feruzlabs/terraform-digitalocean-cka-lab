packer {
  required_plugins {
    digitalocean = {
      version = ">= 1.0.0"
      source  = "github.com/digitalocean/digitalocean"
    }
  }
}

variable "do_token" {
  type      = string
  sensitive = true
}

source "digitalocean" "k8s_node" {
  api_token     = var.do_token
  image         = "ubuntu-22-04-x64"
  region        = "fra1"
  size          = "s-2vcpu-2gb"
  snapshot_name = "cka-k8s-node-1-28"
  ssh_username  = "root"
}

build {
  name = "cka-k8s-node"

  sources = ["source.digitalocean.k8s_node"]

  provisioner "file" {
    source      = "${path.root}/scripts/install-k8s.sh"
    destination = "/tmp/install-k8s.sh"
  }

  provisioner "shell" {
    inline = [
      "chmod +x /tmp/install-k8s.sh",
      "/tmp/install-k8s.sh"
    ]
  }
}

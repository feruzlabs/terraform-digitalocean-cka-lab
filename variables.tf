variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "ssh_public_key_path" {
  description = "Path to your SSH public key (e.g. ~/.ssh/id_rsa.pub)"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to your SSH private key (for provisioners)"
  type        = string
}

variable "region" {
  description = "DigitalOcean region (e.g. fra1 for Frankfurt)"
  type        = string
  default     = "fra1"
}

variable "master_size" {
  description = "Droplet size for master node"
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "worker_size" {
  description = "Droplet size for worker nodes"
  type        = string
  default     = "s-2vcpu-2gb"
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

variable "image" {
  description = "Droplet image (Ubuntu 22.04)"
  type        = string
  default     = "ubuntu-22-04-x64"
}

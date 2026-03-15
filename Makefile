# CKA Lab – Makefile
#
# Usage:
#   export DO_TOKEN=your-digitalocean-api-token   # set once per shell
#   make setup    # first time: init Packer, build image, init Terraform
#   make up       # create cluster (1 master + 2 workers)
#   make down     # destroy cluster
#   make rebuild  # rebuild Packer image only (e.g. after changing install-k8s.sh)
#
# If DO_TOKEN is not set, targets that need it will print an error and exit.
# You can also run: make up DO_TOKEN=your-token

.PHONY: check-token setup up down rebuild

check-token:
	@if [ -z "$$DO_TOKEN" ]; then \
		echo ""; \
		echo "  Error: DO_TOKEN is not set."; \
		echo "  Set your DigitalOcean API token first:"; \
		echo "    export DO_TOKEN=your-digitalocean-api-token"; \
		echo ""; \
		exit 1; \
	fi

setup: check-token
	packer init packer/
	packer build -var do_token=$$DO_TOKEN packer/k8s-node.pkr.hcl
	terraform init

up: check-token
	TF_VAR_do_token=$$DO_TOKEN terraform apply -auto-approve

down: check-token
	TF_VAR_do_token=$$DO_TOKEN terraform destroy -auto-approve

rebuild: check-token
	packer build -var do_token=$$DO_TOKEN packer/k8s-node.pkr.hcl

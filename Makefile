.PHONY: help init plan provision inventory galaxy configure destroy clean

ENV_FILE := .env.secrets
OP := op run --env-file=$(ENV_FILE) --

help:
	@echo "Usage:"
	@echo "  make init        - Initialize provisioning engine backend"
	@echo "  make plan        - Preview infrastructure changes"
	@echo "  make provision   - Apply infrastructure changes (creates VMs); wait ~60s before running inventory"
	@echo "  make inventory   - Read VM IPs from tofu output and write configuration/inventory/hosts.yaml"
	@echo "  make galaxy      - Install Ansible Galaxy collections (run once after cloning)"
	@echo "  make configure   - Run Ansible: OS baseline, game server, and observability setups"
	@echo "  make destroy     - Tear down all infrastructure"
	@echo "  make clean       - Remove generated files (inventory hosts.yaml)"

init:
	$(OP) tofu -chdir=provisioning init

plan:
	$(OP) tofu -chdir=provisioning plan

provision:
	$(OP) tofu -chdir=provisioning apply -auto-approve

inventory:
	@echo "Reading VM IPs from Terraform state..."
	@GAME_IP=$$($(OP) tofu -chdir=provisioning output -raw vm_primary_ip) && \
	  mkdir -p configuration/inventory && \
	  printf 'all:\n  children:\n    game_servers:\n      hosts:\n        dayz-server:\n          ansible_host: %s\n          ansible_user: debian\n    observability:\n      hosts:\n' "$$GAME_IP" \
	  > configuration/inventory/hosts.yaml && \
	  echo "Inventory written — game server: $$GAME_IP"

configure:
	$(OP) ansible-playbook -i configuration/inventory/hosts.yaml configuration/site.yaml

destroy:
	$(OP) tofu -chdir=provisioning destroy

clean:
	rm -f configuration/inventory/hosts.yaml

galaxy:
	ansible-galaxy collection install -r configuration/requirements.yaml

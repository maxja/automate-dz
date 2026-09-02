.PHONY: help init plan provision configure destroy clean

ENV_FILE := .env.secrets
OP := op run --env-file=$(ENV_FILE) --

help:
	@echo "Usage:"
	@echo "  make init        - Initialize provisioning engine backend"
	@echo "  make plan        - Preview infrastructure changes"
	@echo "  make provision   - Apply infrastructure changes (creates VM)"
	@echo "  make configure   - Run OS baseline, game server, and telemetry setups"
	@echo "  make destroy     - Tear down infrastructure"

init:
	$(OP) tofu -chdir=provisioning init

plan:
	$(OP) tofu -chdir=provisioning plan

provision:
	$(OP) tofu -chdir=provisioning apply -auto-approve

configure:
	$(OP) ansible-playbook -i configuration/inventory/hosts.yaml configuration/site.yaml

destroy:
	$(OP) tofu -chdir=provisioning destroy

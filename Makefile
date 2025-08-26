INFRA_DIR := ./tofu
INFRA_PLAN_FILE := plan.tfplan

ENV_FILE := ./.env

.PHONY: help
help:
	@echo "Current configs:"
	@echo "  INFRA_DIR: $(INFRA_DIR)"
	@echo "  INFRA_PLAN_FILE: $(INFRA_PLAN_FILE)"
	@echo "  ENV_FILE: $(ENV_FILE)"
	@echo "Available targets:"
	@echo "  infra-init       Initialize infrastructure"
	@echo "  infra-plan       Plan infrastructure changes"
	@echo "  infra-apply      Apply infrastructure changes"

.PHONY: infra-init
infra-init:
	test -f $(ENV_FILE) && source $(ENV_FILE) && \
	tofu -chdir=$(INFRA_DIR) init

.PHONY: infra-plan
infra-plan:
	test -f $(ENV_FILE) && source $(ENV_FILE) && \
  tofu -chdir=$(INFRA_DIR) plan -out=$(INFRA_PLAN_FILE)

.PHONY: infra-apply
infra-apply:
	test -f $(ENV_FILE) && source $(ENV_FILE) && \
	test -f $(INFRA_DIR)/$(INFRA_PLAN_FILE) && \
	tofu -chdir=$(INFRA_DIR) apply $(INFRA_PLAN_FILE)

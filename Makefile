SHELL := /bin/bash
INFRA_DIR := ./tofu
INFRA_PLAN_FILE := plan.tfplan

ENV_FILE := ./.env

KUBECONFIG_CMD := $$(tofu -chdir=$(INFRA_DIR) output -raw kubeconfig_path 2>/dev/null || echo "")

.PHONY: help
help:
	@echo "Current configs:"
	@echo "  INFRA_DIR: $(INFRA_DIR)"
	@echo "  INFRA_PLAN_FILE: $(INFRA_PLAN_FILE)"
	@echo "  ENV_FILE: $(ENV_FILE)"
	@echo "Dynamically obtained values:"
	@echo "  KUBECONFIG_CMD: $(KUBECONFIG_CMD)"
	@echo ""
	@echo "Available targets:"
	@echo "  IaC targets:"
	@echo "    infra-init       Initialize infrastructure"
	@echo "    infra-plan       Plan infrastructure changes"
	@echo "    infra-apply      Apply infrastructure changes"
	@echo "  Other targets:"
	@echo "    clean            Clean up generated files"


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


.PHONY: clean
clean:
	@echo "Cleaning up generated files..."; \
	files=( \
		"$(INFRA_DIR)/$(INFRA_PLAN_FILE)" \
		"$(INFRA_DIR)/$(KUBECONFIG_CMD)" \
	); \
	for file in $${files[@]}; do \
		if [ -n "$$file" ] && [ -f "$$file" ]; then \
			rm -f $$file; \
			echo "Removed $$file"; \
		fi; \
	done && \
	echo "Clean up completed."

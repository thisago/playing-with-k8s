SHELL := /bin/bash
INFRA_DIR := ./tofu
INFRA_PLAN_FILE := plan.tfplan
INFRA_TFSTATE_DIR := $(INFRA_DIR)/tfstates

ENV_FILE := ./.env

KUBECONFIG_PATH := $$(tofu -chdir=$(INFRA_DIR) output -raw kubeconfig_path 2>/dev/null || echo "")

.PHONY: help
help:
	@echo "Current configs:"
	@echo "  INFRA_DIR: $(INFRA_DIR)"
	@echo "  INFRA_PLAN_FILE: $(INFRA_PLAN_FILE)"
	@echo "  ENV_FILE: $(ENV_FILE)"
	@echo "  INFRA_TFSTATE_DIR: $(INFRA_TFSTATE_DIR)"
	@echo "Dynamically obtained values:"
	@echo "  KUBECONFIG_PATH: $(KUBECONFIG_PATH)"
	@echo ""
	@echo "Available targets:"
	@echo "  IaC targets:"
	@echo "    tofu-init       Initialize infrastructure"
	@echo "    tofu-plan       Plan infrastructure changes"
	@echo "    tofu-apply      Apply infrastructure changes"
	@echo "    tofu-refresh    Refresh infrastructure state"
	@echo "  Other targets:"
	@echo "    clean            Clean up generated files"

.PHONY: tofu-init
tofu-init:
	test -f $(ENV_FILE) && source $(ENV_FILE) && \
	tofu -chdir=$(INFRA_DIR) init

.PHONY: tofu-plan
tofu-plan:
	test -f $(ENV_FILE) && source $(ENV_FILE) && \
	tofu -chdir=$(INFRA_DIR) plan -out=$(INFRA_PLAN_FILE)

.PHONY: tofu-apply
tofu-apply:
	test -f $(ENV_FILE) && source $(ENV_FILE) && \
	test -f $(INFRA_DIR)/$(INFRA_PLAN_FILE) && \
	tofu -chdir=$(INFRA_DIR) apply $(INFRA_PLAN_FILE)
	$(MAKE) tofu-commit-tfstate

.PHONY: tofu-refresh
tofu-refresh:
	test -f $(ENV_FILE) && source $(ENV_FILE) && \
	tofu -chdir=$(INFRA_DIR) refresh
	$(MAKE) tofu-commit-tfstate

.PHONY: tofu-commit-tfstate
tofu-commit-tfstate:
	@cd $(INFRA_TFSTATE_DIR) && \
	if ! git diff --quiet; then \
		pre-commit run --all-files; \
		git add . && \
		git commit -m "chore: tfstate"; \
	else \
		echo "Nothing to commit"; \
	fi

.PHONY: clean
clean:
	@echo "Cleaning up generated files..."; \
	files=( \
		"$(INFRA_DIR)/$(INFRA_PLAN_FILE)" \
		"$(INFRA_DIR)/$(KUBECONFIG_PATH)" \
	); \
	for file in $${files[@]}; do \
		if [ -n "$$file" ] && [ -f "$$file" ]; then \
			rm -f $$file; \
			echo "Removed $$file"; \
		fi; \
	done && \
	echo "Clean up completed."

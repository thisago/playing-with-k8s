SHELL := /bin/bash
INFRA_DIR := ./tofu
HELM_DIR := ./helm
INFRA_PLAN_FILE := plan.tfplan
INFRA_TFSTATE_DIR := $(INFRA_DIR)/tfstates

ENV_FILE := ./.env

KUBECONFIG_PATH := $$(tofu -chdir=$(INFRA_DIR) output -raw kubeconfig_path 2>/dev/null || echo "")

TOFU := tofu -chdir="$(INFRA_DIR)"
HELMFILE := helmfile -f "$(HELM_DIR)/helmfile.yaml"

.PHONY: help
help:
	@echo "Current configs:"
	@echo "  INFRA_DIR: $(INFRA_DIR)"
	@echo "  HELM_DIR: $(HELM_DIR)"
	@echo "  INFRA_PLAN_FILE: $(INFRA_PLAN_FILE)"
	@echo "  ENV_FILE: $(ENV_FILE)"
	@echo "  INFRA_TFSTATE_DIR: $(INFRA_TFSTATE_DIR)"
	@echo "  TOFU: $(TOFU)"
	@echo "  HELM: $(HELM)"
	@echo "  HELMFILE: $(HELMFILE)"
	@echo "Dynamically obtained values:"
	@echo "  KUBECONFIG_PATH: $(KUBECONFIG_PATH)"
	@echo ""
	@echo "Available targets:"
	@echo "  Tofu targets:"
	@echo "    tofu-init       Initialize infrastructure"
	@echo "    tofu-plan       Plan infrastructure changes"
	@echo "    tofu-apply      Apply infrastructure changes"
	@echo "    tofu-refresh    Refresh infrastructure state"
	@echo "  Helm/helmfile targets:"
	@echo "    helmfile-apply  Runs apply command with kubeconfig set"
	@echo "  Other targets:"
	@echo "    clean            Clean up generated files"

.PHONY: tofu-init
tofu-init:
	test -f $(ENV_FILE) && source $(ENV_FILE) && \
	$(TOFU) init

.PHONY: tofu-plan
tofu-plan:
	test -f $(ENV_FILE) && source $(ENV_FILE) && \
	$(TOFU) plan -out=$(INFRA_PLAN_FILE)

.PHONY: tofu-apply
tofu-apply:
	test -f $(ENV_FILE) && source $(ENV_FILE) && \
	test -f $(INFRA_DIR)/$(INFRA_PLAN_FILE) && \
	$(TOFU) apply $(INFRA_PLAN_FILE)
	$(MAKE) tofu-commit-tfstate

.PHONY: tofu-refresh
tofu-refresh:
	test -f $(ENV_FILE) && source $(ENV_FILE) && \
	$(TOFU) refresh
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

# Helm

.PHONY: helmfile-apply
helmfile-apply:
	export KUBECONFIG="$(INFRA_DIR)/$(KUBECONFIG_PATH)"; \
	test -f "$$KUBECONFIG" && \
	$(HELMFILE) apply

# Others

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

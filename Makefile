SHELL := /bin/bash

INFRA_DIR := ./clusters
HELM_DIR := ./helm
INFRA_PLAN_FILE := plan.tfplan
INFRA_TFSTATE_DIR := $(INFRA_DIR)/tfstates

ENV_FILE := ./.env

TOFU := tofu -chdir="$(INFRA_DIR)"
HELM := helm
HELMFILE := helmfile -f "$(HELM_DIR)/helmfile.yaml"

# Define the cluster auth
ENV ?= dev
KUBECONFIG_DEV := /home/$$USER/.kube/config
KUBECONFIG_PROD := $(INFRA_DIR)/$$($(TOFU) output -raw kubeconfig_path 2>/dev/null || echo "")
KUBECONFIG_EFFECTIVE := $(if $(filter $(ENV),dev),$(KUBECONFIG_DEV),$(KUBECONFIG_PROD))

.PHONY: help
help:
	@echo "Current configs:"
	@echo "  ENV: $(ENV)"
	@echo "  ENV_FILE: $(ENV_FILE)"
	@echo "  INFRA_DIR: $(INFRA_DIR)"
	@echo "  INFRA_PLAN_FILE: $(INFRA_PLAN_FILE)"
	@echo "  INFRA_TFSTATE_DIR: $(INFRA_TFSTATE_DIR)"
	@echo "  TOFU: $(TOFU)"
	@echo "  KUBECONFIG_DEV: $(KUBECONFIG_DEV)"
	@echo "  HELM_DIR: $(HELM_DIR)"
	@echo "  HELM: $(HELM)"
	@echo "  HELMFILE: $(HELMFILE)"
	@echo "Dynamically obtained values:"
	@echo "  KUBECONFIG_PROD: $(KUBECONFIG_PROD)"
	@echo "  KUBECONFIG_EFFECTIVE: $(KUBECONFIG_EFFECTIVE)"
	@echo ""
	@echo "Available targets:"
	@echo "  Tofu targets:"
	@echo "    tofu-init       Initialize infrastructure"
	@echo "    tofu-plan       Plan infrastructure changes"
	@echo "    tofu-apply      Apply infrastructure changes"
	@echo "    tofu-refresh    Refresh infrastructure state"
	@echo "  Helm/helmfile targets:"
	@echo "    helmfile-apply    Runs apply command with kubeconfig set"
	@echo "    helmfile-diff     Runs diff helmfile command"
	@echo "    helmfile-destroy  Runs destroy helmfile command"
	@echo "    helm-test         Tests all charts"
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

.PHONY: helm-test
helm-test:
	helmfile -f $(HELM_DIR)/helmfile.yaml test --cleanup

.PHONY: helmfile-apply
helmfile-apply: internal-guard-cluster
	export KUBECONFIG="$(KUBECONFIG_EFFECTIVE)"; \
	$(HELMFILE) apply

.PHONY: helmfile-diff
helmfile-diff: internal-guard-cluster
	export KUBECONFIG="$(KUBECONFIG_EFFECTIVE)"; \
	$(HELMFILE) diff

.PHONY: helmfile-destroy
helmfile-destroy:
	export KUBECONFIG="$(KUBECONFIG_EFFECTIVE)"; \
	$(HELMFILE) destroy


# Others

.PHONY: clean
clean:
	@echo "Cleaning up generated files..."; \
	files=( \
		"$(INFRA_DIR)/$(INFRA_PLAN_FILE)" \
		"$(INFRA_DIR)/$(KUBECONFIG_PROD)" \
	); \
	for file in $${files[@]}; do \
		if [ -n "$$file" ] && [ -f "$$file" ]; then \
			rm -f $$file; \
			echo "Removed $$file"; \
		fi; \
	done && \
	echo "Clean up completed."

# Internal
internal-guard-cluster:
	@export KUBECONFIG="$(KUBECONFIG_EFFECTIVE)"; \
	test -f "$$KUBECONFIG" && \
	if [ "$(ENV)" != "dev" ]; then exit 0; fi; \
	cluster=$$(kubectl config view --minify -o jsonpath='{.clusters[0].name}'); \
	if [ "$$cluster" != "minikube" ] && [ "$$cluster" != "docker-desktop" ]; then \
		echo "Your local kubeconfig ($(KUBECONFIG_DEV)) seems to not be local (cluster: $$cluster)!"; \
		exit 1; \
	fi

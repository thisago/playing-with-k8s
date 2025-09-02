SHELL := /bin/bash

INFRA_DIR := ./clusters
HELM_DIR := ./helm
INFRA_PLAN_FILE := plan.tfplan
INFRA_TFSTATE_DIR := $(INFRA_DIR)/tfstates

ENV_FILE := ./.env

TOFU := tofu -chdir="$(INFRA_DIR)"
HELM := helm
HELMFILE_YAML := $(HELM_DIR)/helmfile.yaml
HELMFILE := helmfile -f "$(HELMFILE_YAML)"
KUBECTL := kubectl

# Define the cluster auth
ENV ?= dev
KUBECONFIG_DEV := /home/$$USER/.kube/config
KUBECONFIG_PROD := $$($(TOFU) output -raw kubeconfig_path 2>/dev/null | xargs -IPATH realpath '$(INFRA_DIR)/PATH' || echo "")
# See https://github.com/roboll/helmfile/issues/173
KUBECONFIG_EFFECTIVE := $(if $(filter $(ENV),dev),$(KUBECONFIG_DEV),$(KUBECONFIG_PROD))

# Helpers
YQ_HELMFILE := cat "$(HELMFILE_YAML)" | yq

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
	@echo "  HELMFILE_YAML: $(HELMFILE_YAML)"
	@echo "  HELMFILE: $(HELMFILE)"
	@echo "  KUBECTL: $(KUBECTL)"
	@echo "Dynamically obtained values:"
	@echo "  KUBECONFIG_PROD: $(KUBECONFIG_PROD)"
	@echo "  KUBECONFIG_EFFECTIVE: $(KUBECONFIG_EFFECTIVE)"
	@echo ""
	@echo "Available targets:"
	@echo "  Tofu targets:"
	@echo "    tofu-init                Initialize infrastructure"
	@echo "    tofu-plan                Plan infrastructure changes"
	@echo "    tofu-apply               Apply infrastructure changes"
	@echo "    tofu-refresh             Refresh infrastructure state"
	@echo "  Helm/helmfile targets:"
	@echo "    helmfile-apply           Runs apply command with kubeconfig set"
	@echo "    helmfile-diff            Runs diff helmfile command"
	@echo "    helmfile-destroy         Runs destroy helmfile command"
	@echo "    helmfile-sync            Runs sync helmfile command"
	@echo "    helm-test                Tests all charts"
	@echo "  KubeCTL targets:"
	@echo "    kubectl-loadBalancer-ip  Gets load balancer public IP"
	@echo "  Other targets:"
	@echo "    clean                    Clean up generated files"

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
	$(MAKE) internal-tofu-commit-tfstate

.PHONY: tofu-refresh
tofu-refresh:
	test -f $(ENV_FILE) && source $(ENV_FILE) && \
	$(TOFU) refresh
	$(MAKE) internal-tofu-commit-tfstate

# Helm

.PHONY: helm-test
helm-test:
	$(HELMFILE) test --cleanup

.PHONY: helmfile-apply
helmfile-apply: internal-guard-cluster
	export KUBECONFIG="$(KUBECONFIG_EFFECTIVE)"; \
	$(HELMFILE) apply

.PHONY: helmfile-diff
helmfile-diff: internal-guard-cluster
	export KUBECONFIG="$(KUBECONFIG_EFFECTIVE)"; \
	$(HELMFILE) diff

.PHONY: helmfile-sync
helmfile-sync:
	export KUBECONFIG="$(KUBECONFIG_EFFECTIVE)"; \
	$(HELMFILE) sync

.PHONY: helmfile-destroy
helmfile-destroy:
	export KUBECONFIG="$(KUBECONFIG_EFFECTIVE)"; \
	$(HELMFILE) destroy

# kubectl

.PHONY: kubectl-loadBalancer-ip
kubectl-loadBalancer-ip:
	@export KUBECONFIG="$(KUBECONFIG_EFFECTIVE)"; \
	$(KUBECTL) get svc ingress-nginx-controller -n "$$($(YQ_HELMFILE) '.releases.[0].name')" -o=jsonpath='{.status.loadBalancer.ingress[0].ip}'

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

.PHONY: internal-tofu-commit-tfstate
internal-tofu-commit-tfstate:
	@cd $(INFRA_TFSTATE_DIR) && \
	if ! git diff --quiet; then \
		pre-commit run --all-files; \
		git add . && \
		git commit -m "chore: tfstate"; \
	else \
		echo "Nothing to commit"; \
	fi

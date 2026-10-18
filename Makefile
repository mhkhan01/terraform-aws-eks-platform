SHELL := /bin/bash
.DEFAULT_GOAL := all

EXAMPLES := $(wildcard examples/*)
MODULES  := $(wildcard modules/*)

# Local kind lab
KIND_CLUSTER         ?= eks-platform-lab
ARGOCD_CHART_VERSION ?= 10.10.3

.PHONY: all fmt validate lint test security docs kind-up kind-down kind-argocd-ui

all: fmt validate lint test security

fmt: ## Check formatting
	terraform fmt -check -recursive

validate: ## init (no backend) and validate every example
	@set -e; for d in $(EXAMPLES); do \
		echo "==> $$d"; \
		terraform -chdir=$$d init -backend=false -input=false >/dev/null; \
		terraform -chdir=$$d validate; \
	done

lint: ## tflint across the repo
	tflint --init
	tflint --recursive --format compact

test: ## terraform test with mocked providers (no AWS credentials needed)
	@set -e; for d in $(EXAMPLES); do \
		echo "==> $$d"; \
		terraform -chdir=$$d init -backend=false -input=false >/dev/null; \
		terraform -chdir=$$d test; \
	done

security: ## checkov static analysis
	checkov -d . --config-file .checkov.yaml --quiet

docs: ## regenerate module READMEs
	@set -e; for m in $(MODULES); do \
		terraform-docs markdown table --output-file README.md --output-mode inject $$m; \
	done

kind-up: ## free local lab: kind cluster + Argo CD + root app-of-apps
	kind create cluster --name $(KIND_CLUSTER) --config local/kind-config.yaml
	helm repo add argo https://argoproj.github.io/argo-helm --force-update
	helm upgrade --install argocd argo/argo-cd \
		--version $(ARGOCD_CHART_VERSION) \
		--namespace argocd --create-namespace \
		--values local/argocd-values.yaml \
		--wait --timeout 10m
	kubectl apply -f local/root-app.yaml
	@echo "Argo CD is up. Run 'make kind-argocd-ui' and open http://localhost:8080"
	@echo -n "admin password: "; kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo

kind-argocd-ui: ## port-forward the Argo CD UI to localhost:8080
	kubectl -n argocd port-forward svc/argocd-server 8080:80

kind-down: ## delete the local lab
	kind delete cluster --name $(KIND_CLUSTER)

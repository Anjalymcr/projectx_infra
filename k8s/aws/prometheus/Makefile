HELM_RELEASE_NAME := prometheus
HELM_NAMESPACE    := monitoring
VALUES_FILE       := values.yaml

.PHONY: helm-init helm-deploy helm-uninstall prometheus-forward

helm-init:
	@echo "=> Adding Prometheus Helm Repo"
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo update

helm-deploy: helm-init
	@echo "=> Deploying Prometheus"
	helm dependency build .
	helm upgrade --install $(HELM_RELEASE_NAME) . \
		--namespace $(HELM_NAMESPACE) --create-namespace \
		--values $(VALUES_FILE)

helm-uninstall:
	@echo "=> Removing Prometheus"
	helm uninstall $(HELM_RELEASE_NAME) --namespace $(HELM_NAMESPACE)

prometheus-forward:
	@echo "=> Port-forwarding Prometheus to http://localhost:9090"
	kubectl --namespace $(HELM_NAMESPACE) port-forward deploy/prometheus-server 9090

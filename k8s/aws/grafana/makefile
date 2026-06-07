HELM_RELEASE_NAME := grafana
HELM_NAMESPACE    := monitoring
VALUES_FILE       := values.yaml

.PHONY: helm-init helm-deploy helm-uninstall grafana-pw grafana-forward

helm-init:
	@echo "=> Adding Grafana Helm Repo"
	helm repo add grafana https://grafana.github.io/helm-charts
	helm repo update

helm-deploy: helm-init
	@echo "=> Deploying Grafana"
	helm dependency build .
	helm upgrade --install $(HELM_RELEASE_NAME) . \
		--namespace $(HELM_NAMESPACE) --create-namespace \
		--values $(VALUES_FILE)

helm-uninstall:
	@echo "=> Removing Grafana"
	helm uninstall $(HELM_RELEASE_NAME) --namespace $(HELM_NAMESPACE)

grafana-pw:
	@echo "=> Grafana admin password:"
	@kubectl get secret --namespace $(HELM_NAMESPACE) $(HELM_RELEASE_NAME) -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

grafana-forward: grafana-pw
	@echo "=> Port-forwarding Grafana to http://localhost:3000"
	kubectl --namespace $(HELM_NAMESPACE) port-forward deploy/$(HELM_RELEASE_NAME) 3000

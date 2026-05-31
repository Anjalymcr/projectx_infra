HELM_RELEASE_NAME := jenkins
HELM_NAMESPACE    := jenkins
VALUES_FILE       := values.yaml
STORAGE_DIR       := ../../../deploy/aws/dev/storage
EKS_DIR           := ../../../deploy/aws/dev/eks

.PHONY: helm-init helm-deploy helm-uninstall

helm-init:
	@echo "=> Adding Jenkins Helm Repo"
	helm repo add jenkinsci https://charts.jenkins.io
	helm repo update

helm-deploy: helm-init
	$(eval EFS_ID := $(shell cd $(STORAGE_DIR) && terraform output -raw efs_id))
	$(eval JENKINS_ROLE_ARN := $(shell cd $(EKS_DIR) && terraform output -raw jenkins_irsa_role_arn))
	@echo "=> Deploying Jenkins with EFS_ID: $(EFS_ID) and Role: $(JENKINS_ROLE_ARN)"
	helm dependency build .
	helm upgrade --install $(HELM_RELEASE_NAME) . \
		--namespace $(HELM_NAMESPACE) --create-namespace \
		--values $(VALUES_FILE) \
		--set persistence.efsId=$(EFS_ID) \
		--set jenkins.controller.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$(JENKINS_ROLE_ARN)

helm-uninstall:
	@echo "=> Removing Jenkins"
	helm uninstall $(HELM_RELEASE_NAME) --namespace $(HELM_NAMESPACE)

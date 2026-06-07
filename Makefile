##################################################
# GLOBAL SETTINGS
##################################################
ENV             ?= dev
AWS_REGION      ?= ap-southeast-2
AWS_PROFILE		?= svc-deployer
# Modular Layer Paths
INFRA_DIR    := deploy/aws/$(ENV)/infra
STORAGE_DIR  := deploy/aws/$(ENV)/storage
IAM_DIR      := deploy/aws/$(ENV)/iam
EKS_DIR      := deploy/aws/$(ENV)/eks

MY_IP := $(shell curl -s https://ifconfig.me)/32

##################################################
# LAYER 1: BASE INFRA (VPC & NETWORKING)
##################################################

.PHONY: infra-init infra-plan infra-apply

infra-init:
	@echo "=> Initializing Infra Layer"
	cd $(INFRA_DIR) && terraform init

infra-plan: infra-init
	@echo "=> Planning Infra Layer"
	cd $(INFRA_DIR) && terraform plan -var-file=../common.tfvars -var-file=env.tfvars

infra-apply:
	@echo "=> Deploying Infra Layer"
	cd $(INFRA_DIR) && terraform apply -var-file=../common.tfvars -var-file=env.tfvars -auto-approve

##################################################
# LAYER 2: STORAGE (RDS, EFS, ECR, S3)
##################################################

.PHONY: storage-init storage-plan storage-apply

storage-init:
	@echo "=> Initializing Storage Layer"
	cd $(STORAGE_DIR) && terraform init

storage-plan: storage-init
	@echo "=> Planning Storage Layer"
	cd $(STORAGE_DIR) && terraform plan -var-file=../common.tfvars -var-file=env.tfvars

storage-apply: infra-apply
	@echo "=> Deploying Storage Layer (RDS, Secrets, SGs)"
	cd $(STORAGE_DIR) && terraform apply -var-file=../common.tfvars -var-file=env.tfvars -auto-approve

##################################################
# LAYER 3: IAM (ROLES & POLICIES)
##################################################

.PHONY: iam-init iam-plan iam-apply

iam-init:
	@echo "=> Initializing IAM Layer"
	cd $(IAM_DIR) && terraform init

iam-plan: iam-init
	@echo "=> Planning IAM Layer"
	cd $(IAM_DIR) && terraform plan -var-file=../common.tfvars -var-file=env.tfvars

iam-apply: infra-apply
	@echo "=> Deploying IAM Layer"
	cd $(IAM_DIR) && terraform apply -var-file=../common.tfvars -var-file=env.tfvars -auto-approve

##################################################
# LAYER 4: COMPUTE (EKS CLUSTER)
##################################################

.PHONY: eks-init eks-plan eks-apply

eks-init:
	@echo "=> Initializing EKS Layer"
	cd $(EKS_DIR) && terraform init

eks-plan: eks-init
	@echo "=> Planning EKS Layer"
	cd $(EKS_DIR) && terraform plan -var-file=../common.tfvars -var-file=env.tfvars -var="my_ip_cidr=$(MY_IP)"

eks-apply: infra-apply iam-apply
	@echo "=> Deploying EKS Layer (Restricted to IP: $(MY_IP))"
	cd $(EKS_DIR) && terraform apply -var-file=../common.tfvars -var-file=env.tfvars -var="my_ip_cidr=$(MY_IP)" -auto-approve

##################################################
# ORCHESTRATION TARGETS (All Layers)
##################################################

.PHONY: init-all plan-all deploy-all destroy-all

# Initialize all layers
init-all: infra-init storage-init iam-init eks-init
	@echo "=> All Layers Initialized Successfully!"

# Plan all layers in order (continues on failure so you see all results)
plan-all:
	@echo "=> Planning Layer 1: Infra"
	-cd $(INFRA_DIR) && terraform init -input=false > /dev/null && terraform plan -var-file=../common.tfvars -var-file=env.tfvars
	@echo "=> Planning Layer 2: Storage"
	-cd $(STORAGE_DIR) && terraform init -input=false > /dev/null && terraform plan -var-file=../common.tfvars -var-file=env.tfvars
	@echo "=> Planning Layer 3: IAM"
	-cd $(IAM_DIR) && terraform init -input=false > /dev/null && terraform plan -var-file=../common.tfvars -var-file=env.tfvars
	@echo "=> Planning Layer 4: EKS"
	-cd $(EKS_DIR) && terraform init -input=false > /dev/null && terraform plan -var-file=../common.tfvars -var-file=env.tfvars -var="my_ip_cidr=$(MY_IP)"
	@echo "=> All Layers Planned (check above for errors)"

# Deploy layers in order: Infra -> Storage -> IAM -> EKS (includes ALB Controller)
deploy-all: infra-apply storage-apply iam-apply eks-apply
	@echo "=> Full Layered Stack Deployed Successfully!"

# Destroy in reverse order: Apps -> EKS -> IAM -> Storage -> Infra
destroy-all: destroy-apps
	@echo "=> DESTROYING ALL LAYERS (Reverse Order)"
	@echo "=> Layer 4: EKS Cluster"
	cd $(EKS_DIR) && terraform destroy -auto-approve -var-file=../common.tfvars -var-file=env.tfvars -var="my_ip_cidr=$(MY_IP)" || true
	@echo "=> Layer 3: IAM Roles & Policies"
	cd $(IAM_DIR) && terraform destroy -auto-approve -var-file=../common.tfvars -var-file=env.tfvars || true
	@echo "=> Layer 2: Storage (RDS, EFS, ECR, S3)"
	cd $(STORAGE_DIR) && terraform destroy -auto-approve -var-file=../common.tfvars -var-file=env.tfvars || true
	@echo "=> Layer 1: Infra (VPC)"
	cd $(INFRA_DIR) && terraform destroy -auto-approve -var-file=../common.tfvars -var-file=env.tfvars || true
	@echo "=> All Layers Destroyed!"

##################################################
# K8S APPLICATIONS (JENKINS, RUNNERS)
##################################################

K8S_JENKINS_DIR := k8s/aws/jenkins
K8S_RUNNERS_DIR := k8s/aws/eng-prod-runners

eks-auth:
	@echo "=> Authenticating with [$(ENV)] EKS Cluster"
	aws eks update-kubeconfig --region $(AWS_REGION) --name $(ENV)-projectx-cluster

jenkins-deploy: eks-auth
	@echo "=> Deploying Jenkins to [$(ENV)]"
	$(MAKE) -C k8s/aws/jenkins helm-deploy

runners-deploy: eks-auth
	@echo "=> Deploying Runners to [$(ENV)]"
	$(MAKE) -C k8s/aws/runners helm-deploy

status: eks-auth
	@echo "=> Cluster Status for [$(ENV)]"
	kubectl get pods -A

##################################################
# PLATFORM SERVICES (MONITORING, LOGGING)
##################################################

K8S_PROMETHEUS_DIR := k8s/aws/prometheus
K8S_GRAFANA_DIR    := k8s/aws/grafana

prometheus-deploy: eks-auth
	@echo "=> Deploying Prometheus to [$(ENV)]"
	$(MAKE) -C $(K8S_PROMETHEUS_DIR) helm-deploy

grafana-deploy: eks-auth
	@echo "=> Deploying Grafana to [$(ENV)]"
	$(MAKE) -C $(K8S_GRAFANA_DIR) helm-deploy

platform-deploy: prometheus-deploy grafana-deploy
	@echo "=> All Platform Services Deployed!"


##################################################
# App & Platform Destroy Targets
##################################################
.PHONY: destroy-apps destroy-jenkins destroy-runners destroy-prometheus destroy-grafana

destroy-jenkins: eks-auth
	@echo "=> Removing Jenkins"
	-helm uninstall jenkins --namespace jenkins
	-kubectl delete ingress jenkins -n jenkins
	-kubectl delete namespace jenkins

destroy-runners: eks-auth
	@echo "=> Removing Runners"
	-helm uninstall runners --namespace runners
	-kubectl delete namespace runners

destroy-prometheus: eks-auth
	@echo "=> Removing Prometheus"
	-helm uninstall prometheus --namespace monitoring
	-kubectl delete namespace monitoring

destroy-grafana: eks-auth
	@echo "=> Removing Grafana"
	-helm uninstall grafana --namespace monitoring

destroy-apps: eks-auth
	@echo "=> Removing all K8S apps and platform services"
	-$(MAKE) destroy-jenkins
	-$(MAKE) destroy-grafana
	-$(MAKE) destroy-prometheus
	-$(MAKE) destroy-runners
	@echo "=> Waiting for ALB cleanup..."
	sleep 30

##################################################
# Individual Destroy Targets
##################################################
.PHONY: destroy-infra destroy-storage destroy-iam destroy-eks

destroy-infra:
	@echo "=> Destroying Infra Layer (VPC)"
	cd $(INFRA_DIR) && terraform destroy -var-file=../common.tfvars -var-file=env.tfvars -auto-approve

destroy-storage:
	@echo "=> Destroying Storage Layer (RDS, EFS, ECR)"
	cd $(STORAGE_DIR) && terraform destroy -var-file=../common.tfvars -var-file=env.tfvars -auto-approve

destroy-iam:
	@echo "=> Destroying IAM Layer"
	cd $(IAM_DIR) && terraform destroy -var-file=../common.tfvars -var-file=env.tfvars -auto-approve

destroy-eks:
	@echo "=> Destroying EKS Layer"
	cd $(EKS_DIR) && terraform destroy -var-file=../common.tfvars -var-file=env.tfvars -var="my_ip_cidr=$(MY_IP)" -auto-approve

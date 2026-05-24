Step 1: The Foundation (The "Workbench")
  Before doing anything in the cloud, you need your tools.
   * Goal: Create a Dockerfile and Makefile that provide a
     consistent environment for Terraform and Packer.
   * Success Criteria: You can run make docker-dev and get a
     shell with terraform --version and packer --version
     working.

  Step 2: The Network (The "Land")
  You need a place for your servers to live.
   * Goal: Use Terraform to create a VPC, Public/Private
     Subnets, and an Internet Gateway.
   * Success Criteria: You have a VPC ID and Subnet IDs ready
     in AWS.

  Step 3: The Data Layer (The "Memory")
  The dashboards and build metrics need a database.
   * Goal: Use Terraform to create an RDS MySQL instance.
   * Success Criteria: You have a database endpoint and can
     connect to it from your workbench.

  Step 4: The Orchestrator (The "Factory Floor")
  This is where the apps and workers will run.
   * Goal: Use Terraform to create an EKS Cluster.
   * Success Criteria: kubectl get nodes shows a running
     Kubernetes cluster.

  Step 5: Platform Services (The "Utilities")
  Equip the cluster with the necessary tools.
   * Goal: Use Helm to install Vault (Secrets), Grafana
     (Monitoring), and Fluent-bit (Logs).
   * Success Criteria: You can log in to the Grafana
     dashboard.

  Step 6: CI/CD Engine (The "Manager")
  Set up the heart of the system.
   * Goal: Deploy Jenkins (on EKS) and configure the GitHub
     Action Runners.
   * Success Criteria: Jenkins is running and can talk to
     GitHub.

  Step 7: Worker Images (The "Muscle")
  Prepare the heavyweight build machines.
   * Goal: Use Packer to build the first "Worker AMI" with all
     your compilers.
   * Success Criteria: Jenkins can spin up an EC2 instance
     using your new AMI to run a build.

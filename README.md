This repository is a comprehensive Infrastructure-as-Code
  (IaC) and Platform-as-a-Service (PaaS) hub. It orchestrates
  a modern, layered CI/CD environment using the "Standard
  Workbench" pattern. It is designed to be secure, scalable,
  and entirely self-service.

  🏗 System Architecture: The Layered Model

  To ensure security, minimize blast radius, and allow
  independent scaling, the platform is divided into Six
  Strategic Layers:

  📡 Layer 1: Network & Identity (The Foundation)
   * VPC & Subnets: Multi-AZ private architecture with triple
     NAT-Gateway redundancy for maximum uptime.
   * Hardened Security: VPC Gateway Endpoints (S3) and
     Interface Endpoints (ECR/STS/SSM) ensure that sensitive
     build traffic never leaves the private AWS backbone.
   * Identity Governance: Cross-account IAM roles with
     strictly enforced Permission Boundaries and
     Least-Privilege access.

  💾 Layer 2: Persistence & Registries (The Storage)
   * Managed SQL (RDS): High-availability MySQL clusters for
     CI/CD state and productivity dashboard metrics.
   * Distributed Storage (EFS): Multi-AZ shared file system
     providing persistent JENKINS_HOME storage, enabling
     seamless master failover.
   * Container Registry (ECR): Secure, private image storage
     with automated vulnerability scanning and lifecycle
     policies.

  ☸️ Layer 3: Compute & Orchestration (The Engine)
   * EKS Cluster: Managed Kubernetes control plane with IRSA
     (IAM Roles for Service Accounts) for pod-level security.
   * Hybrid Node Groups: A cost-optimized blend of On-Demand
     instances (for stateful master services) and Spot
     Instances (for auto-scaling CI/CD workers), reducing
     compute costs by up to 70%.
   * Scaling Runners: Ephemeral Kubernetes worker pods that
     provide fresh, isolated environments for every build.

  📊 Layer 4: Analytics & Observability (The Intelligence)
   * Data Lake (S3): Centralized aggregation of build logs,
     VPC flow logs, and audit trails.
   * Metadata Crawler (Glue): Automated discovery and
     cataloging of unstructured data.
   * Serverless Query (Athena): Running complex SQL analytics
     across historical build data to identify flakiness and
     bottlenecks without managing a data warehouse.

  ⚡ Layer 5: Event-Driven Automation (The Ops)
   * Notification Bus (SNS): A centralized pub/sub engine for
     platform alerts, build failures, and security events.
   * Serverless Workers (Lambda): Python-based automation for
     nightly cleanup of orphaned resources, automated
     patching, and real-time Slack/Teams notifications.

  🌐 Layer 6: Distribution & Routing (The Edge)
   * Global CDN (CloudFront): Low-latency delivery of release
     artifacts and dashboard UIs to worldwide teams.
   * Enterprise DNS (Route 53): Hybrid DNS management
     providing private service discovery (.internal) and
     public entry points.

  ---

  📁 Repository Structure

    1 ├── Dockerfile          # Hermetic Tool Workbench
      (Terraform, Packer, Helm, AWS-CLI)
    2 ├── Makefile            # Enterprise Remote Control
      (Orchestrates all 6 layers)
    3 ├── requirements.txt    # Python dependencies for
      automation and analytics
    4 ├── setup.py            # Package definition for
      internal CLI tools
    5 ├── deploy/
    6 │   └── aws/
    7 │       └── dev/        # Environment: Development
      (Mirrored for Prod)
    8 │           ├── infra/       # L1: VPC, Security Groups,
      IAM, Endpoints
    9 │           ├── storage/     # L2: RDS, EFS, ECR
   10 │           ├── eks/         # L3: EKS Cluster & Node
      Groups
   11 │           ├── analytics/   # L4: Athena, Glue, S3 Data
      Lake
   12 │           ├── automation/  # L5: Lambda, SNS
   13 │           └── distribution/# L6: Route 53, CloudFront
   14 ├── k8s/                # Platform Applications (Helm &
      Manifests)
   15 │   └── aws/
   16 │       ├── jenkins/      # Jenkins Master (EFS-backed)
   17 │       ├── runners/      # Scaling Runner Pods
      (Spot-optimized)
   18 │       └── monitoring/   # Grafana, Prometheus,
      Fluent-bit
   19 └── src/                # Internal Automation Brain
      (Python)
   20     └── build_infra/      # Custom CLI tools (vops,
      repo-manager)

  ---

  🛠 Operational Workflow

  ProjectX utilizes a Docker-Wrapped Workflow to ensure
  consistency across developer laptops and CI/CD agents.

  1. The Workbench (Initialization)
  Every command must be executed within the workbench:

   1 make docker-build    # Build the tool environment
   2 make docker-dev      # Enter the interactive shell

  2. Infrastructure Deployment Sequence
  Infrastructure must be deployed in the following order to
  respect dependencies:

   1 make infra-apply        # L1: Networking
   2 make storage-apply      # L2: Data & Persistence
   3 make eks-apply          # L3: Compute
   4 make jenkins-deploy     # L3.5: Applications
   5 make analytics-apply    # L4: Analytics
   6 make automation-apply   # L5: Automation
   7 make distribution-apply # L6: Edge Delivery

  ---

  💡 Engineering Principles

   * Pipeline-as-Code: No manual job creation. We use
     auto-discovery and Shared Libraries to empower
     application teams while maintaining central control.
   * Immutable Infrastructure: We do not patch servers. We
     bake new AMIs with Packer and rotate node groups.
   * Zero Standing Access: We move toward OIDC and JIT
     (Just-in-Time) access, eliminating long-lived secret
     keys.
   * Observability First: If it isn't monitored, it isn't in
     production. All components must integrate with the
     central Grafana/Athena stack.

  ---
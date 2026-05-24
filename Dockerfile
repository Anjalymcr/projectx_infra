# 1. BASE OPERATING SYSTEM
FROM ubuntu:22.04
LABEL maintainer="infra-team@yourcompany.com"

# Prevent interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# 2. SYSTEM DEPENDENCIES
# openssh-client provides ssh-keygen and ssh
RUN apt-get update -y && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    jq \
    make \
    unzip \
    python3-pip \
    python3-dev \
    gcc \
    g++ \
    openssh-client \
    mysql-client \
    && rm -rf /var/lib/apt/lists/*

# 3. INFRASTRUCTURE TOOLS
ARG TARGETARCH
ARG TERRAFORM_VERSION=1.5.2
ARG KUBECTL_VERSION=v1.27.5
ARG HELM_VERSION=v3.12.3

# Install Terraform
RUN curl -O "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${TARGETARCH}.zip" \
    && unzip "terraform_${TERRAFORM_VERSION}_linux_${TARGETARCH}.zip" \
    && mv terraform /usr/bin/ && rm terra*

# Install Kubectl
RUN curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${TARGETARCH}/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && rm kubectl

# Install Helm
RUN curl -LO "https://get.helm.sh/helm-${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" \
    && tar -zxvf "helm-${HELM_VERSION}-linux-${TARGETARCH}.tar.gz" \
    && install -o root -g root -m 0755 "linux-${TARGETARCH}/helm" /usr/local/bin/helm \
    && rm -rf "linux-${TARGETARCH}" "helm-${HELM_VERSION}-linux-${TARGETARCH}.tar.gz"

# Install AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf awscliv2.zip aws/

# 4. USER SETUP & SSH CONFIG
RUN groupadd -g 1000 ubuntu \
    && useradd -mr -u 1000 -g ubuntu ubuntu \
    && mkdir -p /home/ubuntu/.ssh \
    && chown ubuntu:ubuntu /home/ubuntu/.ssh \
    && chmod 700 /home/ubuntu/.ssh \
    && ssh-keyscan -t rsa github.com >> /home/ubuntu/known_hosts \
    && mv /home/ubuntu/known_hosts /etc/ssh/ssh_known_hosts

USER ubuntu

# 5. WORKSPACE CONFIGURATION
WORKDIR /src
COPY --chown=ubuntu:ubuntu requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# Final Path setup
ENV PATH="/home/ubuntu/.local/bin:${PATH}"
ENV PYTHONPATH="/src/src"

# Default command
ENTRYPOINT ["/bin/bash"]

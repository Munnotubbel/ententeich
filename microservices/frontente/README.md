Certainly. Here's the updated documentation incorporating your requested changes:

# Ententeich Microservices Project Documentation

## Project Overview

The Ententeich Microservices Project is a comprehensive local Kubernetes environment designed for software development, testing, CI/CD pipeline implementation, and Kubernetes tool exploration in a homelab setting. This project utilizes Kind (Kubernetes in Docker) for cluster management, GitLab for version control and CI/CD, and incorporates various microservices.

**IMPORTANT DISCLAIMER:** This project is intended for development purposes in a homelab environment only. It lacks proper security measures and should not be used in production or exposed to the public internet.

## Key Components

### Infrastructure

1. **Kind Kubernetes Cluster**
   - Version: v0.20.0
   - Configuration: Single-node cluster (control plane acts as worker node)
   - Ingress Controller: NGINX (pre-installed)

2. **GitLab Container Registry**
   - Address: gitlab.(hostname)
   - Purpose: Storage and management of Docker images for microservices

3. **GitLab**
   - Deployment: Via Helm Chart in Kind cluster
   - Version: 17.4.2 (GitLab), Helm Chart version 8.4.2
   - Components: GitLab Core, GitLab Shell, Gitaly, Registry, NGINX Ingress Controller, Redis, PostgreSQL
   - URL: http://gitlab.(host-system name)

### Microservices

1. Backend Service ("Backente")
2. Frontend Service ("Frontente")
3. CI/CD Configuration Repository

### Tools

- Uptime Kuma for monitoring
- Terraform/OpenTofu for Infrastructure as Code
- Ansible for configuration management
- Kustomize for Kubernetes manifest management

## Deployment Process

1. Initiation: Execute `setup.sh` script in the `scripts` folder
2. Software Installation: Ansible playbook installs necessary software on the host machine
3. Container Setup: Kind is configured in a Docker container
4. GitLab Deployment: Terraform/OpenTofu deploys GitLab, GitLab Runner, and Uptime Kuma into the cluster
5. Repository Setup: Ansible pushes test code to GitLab repositories and creates development and staging branches
6. CI/CD Execution: GitLab pipelines run for each environment, deploying applications to Kubernetes

## Project Structure

- `/ansible`: Ansible playbooks and configurations
- `/microservices`: Contains backend, frontend, and CI/CD configuration
- `/opentofu`: Terraform/OpenTofu configurations for GitLab and Kubernetes resources
- `/scripts`: Setup and utility scripts

## Networking

- GitLab UI: http://gitlab.(host-system name)
- Uptime Kuma: http://kuma.(host-system name)
- Frontend:
  - Development: http://frontente.dev
  - Staging: http://frontente.stg
  - Production: http://frontente.prod

## Security Considerations

- This setup does not use TLS encryption due to complications with self-signed certificates in a development environment.
- All traffic is unencrypted, making it unsuitable for sensitive data or production use.
- The GitLab Container Registry is unsecured and should only be used within the local network.

## Development Environments

Three distinct environments are configured:
1. Development (dev)
2. Staging (stg)
3. Production (prod)

## CI/CD Configuration

The CI/CD repository contains pipeline configurations and templates for deploying the frontend and backend example services. Kustomize is utilized for environment-specific application configurations.

## Monitoring

K9s is installed for cluster monitoring and can be accessed via the `k9s` command in the terminal.

## Project Reset and Redeployment

In case of deployment issues or if the environment becomes corrupted, the entire project can be redeployed using the `scripts/re-roll.sh` script. Please note:

- This process will result in the loss of all stored data.
- Before redeployment, you must remove the old fingerprint from the `.ssh/known_hosts` file to prevent issues when pushing code to GitLab.

## Troubleshooting

If you encounter issues with GitLab deployment:
1. Navigate to the `opentofu/gitlab_setup` directory.
2. Run `tofu destroy` followed by `tofu apply`.

For problems with other Kubernetes-hosted services:
1. Go to the `opentofu/configure_ressources` directory.
2. Execute `tofu destroy` and then `tofu apply`.

Remember to run `setup.sh` again from scratch if it fails.


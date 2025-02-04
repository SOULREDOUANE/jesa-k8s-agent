## Project Prerequisites

- **Azure DevOps Platform Access**
- **Azure DevOps PAT Key** to run self-hosted agents.
- **Kubernetes (K8s) Cluster Access**
  - Create a **ServiceAccount** to allow Microsoft-hosted agents to create jobs in the K8s cluster.
  - Create a **Role** to specify RBAC policies.
  - Create a **RoleBinding** and link it to the Role and the ServiceAccount created.
- **Azure Container Registry (ACR)** (PAT, registry URL) to push and pull images.
  - Recommended: Create a separate registry for better isolation and management.


## How to Use This Repo

1. **Build the Agent Image**  
   - This image will contain the self-hosted agent and the necessary dependencies to run the PHP project properly.

2. **Create Kubernetes Manifest Files**  
   - Define the required Kubernetes manifests to create a K8s job that runs the self-hosted agent.  
   - Configure the necessary RBAC policies.

3. **Build the PHP Project Docker Image**  
   - Create a Docker image to containerize the PHP project.

4. **Set Up Azure Pipelines and Services**  
   - Configure the Azure pipeline, services, agents, and necessary project variables.

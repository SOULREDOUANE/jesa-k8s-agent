## Project Prerequisites

- **Azure DevOps Platform Access**
- **Azure DevOps PAT Key** to run self-hosted agents.
- **Kubernetes (K8s) Cluster Access**
  - Create a **ServiceAccount** to allow Microsoft-hosted agents to create jobs in the K8s cluster.
  - Create a **Role** to specify RBAC policies.
  - Create a **RoleBinding** and link it to the Role and the ServiceAccount created.
- **Azure Container Registry (ACR)** : you weould need PAT Key, registry URL to push and pull images.
  - Recommended: Create a separate registry for better isolation and management.
- **SonarQube** : You would need a SonarQube Access token for Code analysis
  


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

### 1. Build the Agent Image  

- Use the `docker:dind` base image, an official lightweight Alpine-based image with a smaller attack surface.
- Create a `scripts/install_project_requirement.sh` shell script that installs:
  - All dependencies and libraries required by Azure Agent, PHP, and Azure Agent.
  - Java version 21.05.
  - PHP version 8.3
  - Composer latest version
- Use the `scripts/start.sh` Bash script provided by Microsoft to run the self-hosted agent in a Linux environment.  
  - Modified to force Azure to use Alpine's Node.js.
- Create a Docker user named `agent` to run the Azure script, as Azure does not allow root users to run the agents.
- Create a `scripts/wrapper.sh` shell script to:
  - Start the Docker service inside the container.
  - Run the `start.sh` script.
  - Ensure the user has permission to use the Docker service.
- Optimize the Docker image size to **532 MB**.

### 2. Create Kubernetes Manifest Files
- Create a namespace named `azp-agent-job` for the agent
  ```
    kubectl create ns azp-agent-job
  ```
- Create a secret  that contains the azure devops  PAT key
  ```
    kubectl create secret generic azp-token \
    --from-literal=token= sfsfsf \
    -n jesa-med-namespace
  ```
- Create a configmap  that will contains other inputs required by the azure agent to be executed successfully ( azure devops organization name and pool name)
  ```
    kubectl create configmap azure-pipeline-agent-config \
  --namespace=jesa-med-namespace \
  --from-literal=AZP_URL=https://dev.azure.com/soulredouane40 \
  --from-literal=AZP_POOL=Default \
  --from-literal=AZP_AGENT_NAME=dockeragent-soul-agent
  ```
- Create a  k8s job that will run the pipline
    `Note` : This will be executed by the azure pipeline
  ```
    kubectl apply -f agentjob
  ```

### 3. Build the PHP Project Docker Image

  Here is a simple  docker image i've created  to dockerize the php project 
  ```Dockerfile
    FROM php:8.2-apache as final
    RUN docker-php-ext-install pdo pdo_mysql
    RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
    COPY vendor/ /var/www/html/vendor
    COPY ./src  /var/www/html 
    USER www-data
  ```
  `NOTE` :  This image will be added to the repo that contains the php app resource code 


### 4. Set Up Azure Pipelines and Services

Here is the full pipeline manefist file 
  ```yaml
    trigger:
      - main
    resources:
      repositories:
        - repository: k8s_agent_repo          # identifier to use in checkout
          type: github
          endpoint: 'github-repo'
          name: SOULREDOUANE/jesa-k8s-agent  # your repo name
          ref: main 
    variables:
      tag: '$(Build.BuildId)'
      repositoryName: 'jesaregistry/jesa-php'
      phpVersion: '8.2.27'
      k8sNamespace: 'jesa-med-namespace'
      jobName: 'azp-agent-job'
    
    stages:
    - stage: Setup_Custom_Agent
      jobs:
      - job: CreateK8sAgent
        # pool:
        #   vmImage: 'ubuntu-latest'  # Start with Microsoft-hosted agent
        pool:
          name: 'default'
          demands:
            - agent.name -equals jesa-agent
        steps:
        - checkout: k8s_agent_repo
        - task: KubectlInstaller@0
          inputs:
            kubectlVersion: 'latest'
    
        - task: Kubernetes@1
          inputs:
            connectionType: 'Kubernetes Service Connection'
            kubernetesServiceEndpoint: 'k8s-cluster'
            command: 'apply'
            useConfigurationFile: true
            configuration: '$(System.DefaultWorkingDirectory)/k8s_manifests/agent-job.yml'
    
        # Wait for agent to be ready
        - bash: |
            MAX_RETRIES=45
            RETRY_INTERVAL=10
            for ((i=1; i<=MAX_RETRIES; i++)); do
              RUNNING=$(kubectl get job $(jobName) -n $(k8sNamespace) -o jsonpath='{.status.active}')
              if [ "$RUNNING" == "1" ]; then
                echo "Agent is running!"
                exit 0
              fi
              echo "Waiting for agent to be ready... Attempt $i/$MAX_RETRIES"
              sleep $RETRY_INTERVAL
            done
            echo "Warning: Agent readiness check timed out, but continuing anyway..."
            exit 0  # Exit with success even if timeout
          displayName: 'Wait for K8s agent to be ready'
    
    - stage: Build_And_Test
      dependsOn: Setup_Custom_Agent
      jobs:
      - job: BuildTest
        pool:
          name: 'default'
          demands:
            - agent.name -equals dockeragent-soul-agent
        steps:
        - script: |
            sudo update-alternatives --set php /usr/bin/php$(phpVersion)
            sudo update-alternatives --set phar /usr/bin/phar$(phpVersion)
            sudo update-alternatives --set phpdbg /usr/bin/phpdbg$(phpVersion)
            sudo update-alternatives --set php-cgi /usr/bin/php-cgi$(phpVersion)
            sudo update-alternatives --set phar.phar /usr/bin/phar.phar$(phpVersion)
            php -version
          displayName: 'Use PHP version $(phpVersion)'
    
        - script: composer install --no-interaction --prefer-dist
          displayName: 'composer install'
    
        - task: PublishBuildArtifacts@1
          inputs:
            PathtoPublish: 'vendor'
            ArtifactName: 'vendor-artifact'
            publishLocation: 'Container'
    
        - script: |
            ./vendor/bin/phpunit tests/HelloWorldTest.php --log-junit test-results.xml
          displayName: 'Run PHPUnit Tests'
          continueOnError: true
    
        - task: PublishTestResults@2
          displayName: 'Publish Test Results'
          inputs:
            testResultsFiles: 'test-results.xml'
            testRunTitle: 'PHPUnit Test Results'
            testResultsFormat: 'JUnit'
    
        - task: Docker@2
          inputs:
            containerRegistry: acr-registry
            repository: $(repositoryName)
            command: 'buildAndPush'
            Dockerfile: '**/Dockerfile'
            arguments: '--build-arg VENDOR_ARTIFACT=vendor-artifact'
            tags: |
              $(tag)
    
        - script: |
            docker run -d --name test-container -p 8080:80 jesaregistry.azurecr.io/$(repositoryName):$(tag)
            sleep 10
            curl --fail http://localhost:8080/database.php || (echo "Health check failed!" && exit 1)
            docker stop test-container && docker rm test-container
          displayName: 'Run Container and Perform Health Check'
    
    - stage: Cleanup
      condition: always()
      dependsOn: Build_And_Test
      jobs:
      - job: CleanupResources
        pool:
          name: 'default'
          demands:
          - agent.name -equals jesa-agent
        steps:
        - task: Kubernetes@1
          inputs:
            connectionType: 'Kubernetes Service Connection'
            kubernetesServiceEndpoint: 'k8s-cluster'
            command: 'delete'
            arguments: 'job $(jobName) -n $(k8sNamespace)'
  ```








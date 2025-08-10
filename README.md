# Practical_SRE
- Infrastructure and Environment :
    - I set up a Kubernetes environment using Minikube, which serves as an ideal platform for local development.
    - It provides a flexible space for application testing, troubleshooting, and experimentation.
    * User interface service:
     - The user interface for login and registration using HTML and JavaScript.
     - This interface integrates with the API to handle image uploads, register new users, validate login credentials, and display profiles of users.
 
    * API service:
     - The Application Programming Interface (API) is built using Python to handle data coming from users.
     - The backend logic processes this data and communicates with other services, applying the Gateway Pattern to manage requests and responses efficiently.

    * Authentication Service:
     - The Authentication service is an internal component that verifies user credentials, such as usernames and passwords.
     - It does not handle direct external requests; instead, it receives data from the main API service.
     - Built with Python, it processes and validates login information to ensure secure access.

    * Image service: 
     -  Serves as a centralized storage zone for user images, providing access and retrieval capabilities.
     - Built with Go to ensure performance and scalability.

    * Docker Containerization:
     - Docker is a containerization technology that allows you to package applications and their dependencies into isolated units called containers. 
     - I used Docker to build container images, which are then deployed, orchestrated, and managed by Kubernetes.
       - My Docker image :
         * 'api-service'
         * 'auth-service'
         * 'image-servic'
         * 'webportal-service'
         * 'registry images:' -> used to store the Docker images that are built internally.

    * Kubernetes Orchestration:
     - It is a container orchestration platform designed to manage and scale large numbers of these containers across a cluster of machines.
     - I used Kubernetes to run containers as Deployments, which control Pods and allow scaling up or down as needed.
     - I implemented dynamic autoscaling (HPA) to automatically add new pods to the cluster when resources are highly utilized.
     - I configured Kubernetes Services to route traffic to the Pods, using ClusterIP for internal communication between them.
     - I implemented NetworkPolicies to control network traffic between Pods, allowing only authorized communication and reducing unnecessary connections to enhance security.
     - I configured livenessProbes and readinessProbes to monitor Pod health and traffic readiness, ensuring that Pods are restarted in case of application failures or are marked as unavailable until they are ready to serve traffic.
     - I created a Pod Disruption Budget (PDB) to ensure that a minimum number of pods are kept running to maintain service availability during planned events or maintenance on the Kubernetes cluster nodes.
     - I used Kubernetes Secrets to securely store passwords and other sensitive data, passing them to the pods through the deployment configuration.
     - I implemented a ConfigMap to store non-sensitive configuration data, such as environment variables or application settings, and pass them to the pods for use by the application.
     - I configured Persistent Volume (PV) and Persistent Volume Claim (PVC) objects to allocate and manage persistent storage for applications and databases.
     - Ingress-controller:
       * It is a component in Kubernetes that allows routing HTTP/HTTPS traffic to your services.
       * I configured it to route traffic to service endpoints and secured it using self-signed TLS certificates.
     - Issuer With cert-manager:
       * Issuer -> It's a Kubernetes object for releasing the certificates
       * cert-manager -> is a Kubernetes controller responsible for managing your TLS certificates, including self-signed ones, automatically within the cluster.
         - I configure the issuer to release the certification, then reference the Issuer in the certificates object to create the TLS secret.
     - Openssl with secret TLS
       openssl -> is a tool that allows you to create TLS self-signed certificates locally.
       - I used the OpenSSL command to generate the Key(Private Key).
       - Then request to certification self-signed (CSR), then generate the certification 
       - Allocated the Certification with Key to Kubernetes secret tls.
    **Note**
      There are three ways to generate certificates in Kubernetes: 
      1- Manuel:
        - Using OpenSSL to generate certificates and manually creating the TLS secret
      2- With Issuer and cert-manager:
         - Creating Kubernetes objects (Issuer and Certificate) managed by cert-manager.(Implementation)
      3- Automated via Ingress Annotations
         - Creating an Issuer and referencing it in the Ingress annotations (cert-manager.io/issuer) so cert-manager automatically generates the certificate.

    * Helm charts package Kubernetes:
       - Helm -> is the package manager for Kubernetes, allowing you to define, install, and manage Kubernetes applications using preconfigured charts.
       - install helm charts
       - I used Helm to install the prometheus-community chart, which is a very useful, comprehensive monitoring solution package that bundles all the necessary templates and manifests for:
           * 'Prometheus'
           * 'AlertManager'
           * 'Grafana'

    * Prometheus, AlertManager, and Grafana:
       - Prometheus-> is a monitoring tool that scrapes metrics and stores them in its time-series database (TSDB).
       - Used Prometheus to scrape metrics from the services and persist the collected data. The metrics can be viewed in Prometheus under the Targets page.
         * Configured templates to define which services Prometheus should scrape.
       - AlertManager -> is a component that works alongside Prometheus. Its job is to group, route, and silence the alerts generated by Prometheus before sending them to notification endpoints like email or Slack.
       - I configured alerting rules to define which services should trigger alerts.
       -  I configured the receiver and routing in AlertManager to specify where and how the alerts should be sent.
       - Grafana -> is a data visualization tool that helps you create and configure dashboards to monitor your service metrics.
       - I configured a data source in Grafana to connect it with Prometheus, which allows it to query and visualize the stored metrics.
       - I configured visualization dashboards for services with key metrics such as:
         * 'Status Pods'
         * 'Histogram Bucket'
         * 'HTTP Request Count'
         * 'CPU Usage'
         * 'Memory Usage'
        **Note**
          Some services require an external exporter configured alongside the Pod to collect metrics. These exporters must be defined in Prometheus scrape configurations for monitoring.
---
- Steps of failure simulation and recovery verification.
    - Database Failure with API Service:
      * Pre-Failure State Monitoring:
       - I began by using the 'watch' command-line tool with 'kubectl describe' to monitor the Postgres database Deployment in the app-services namespace using
         'watch -n1 kubectl describe deployment <name-of-deployment> -n <namespace>'.

       - Concurrently, you observed the Pods with 'kubectl get' Postgres and API services status.
         'kubectl get pod -n <name-of-pod> -n <namespace> -l <lable-of-pod-inside-ymal> -w'.
          * -w --> is watch for changes.

      - Then, I used 'kubctl logs -f' to print the logs for a container in a pod resource streamly. 
         'kubctl logs -f <name-of-pod> -n <namespace>'.
      - Grafana dashboards and AlertManager showed a normal operational state (the database dashboard was "Up" and no active alerts existed). A new user was successfully registered via the frontend (webportal.local), confirming that all services were functioning correctly. 

    - Simulating the Failure:
      -  To simulate a database failure, you scaled down the Postgres Deployment to zero replicas using 'kubectl scale deployment'.
          'kubectl scale deployment <name-of-deployment> --replicas=<number-scale> -n <namespac>'.
          * This action terminated the database Pod, causing the API service to lose its connection to the database.
    - Verifying Recovery:
       * Failure Detection: 
          - AlertManager detected the failure, initially showing a Pending.
         Alert Pending:
           1- 'PostgresExporterHighScrapeLatency'
           2- 'APIServiceDown'
       * Frontend failed:
          - Attempts to log in through the frontend failed with a "Failed to communicate with Auth service" error.
          - The Grafana dashboard for the API service also showed a "Down" status.

       * Service Restoration: 
          - Restored the service by scaling the database replicas back to one using 'kubectl scale deployment'.
              'kubectl scale deployment <name-of-deployment> --replicas=<number-scale> -n <namespac>'.

  - Simulating a high utilization in Requests to the Image Service.
    - Pre-Failure State Monitoring:
       * started by monitoring the image-service Deployment in the app-services namespace using 
          'watch -n1 kubectl describe deployment <name-of-deployment> -n <namespace>'
       * Concurrently, you observed the HPA with 'kubectl get hpa' Image-service utilize pod.
           'kubectl get hap <name-of-pod> -n <namespece>'.
          - The service initially had 2 replicas. The Grafana dashboards showed low CPU and memory usage for the service.
    - Simulating the Failure:
       * I used the 'hey' tool to generate and send a large number of requests 
           'hey -n 100000 -c 100 https://images.local/uploads/<image-name>.png' 
       * Due to the high utilization in CPU usage exceeding the threshold defined in the Horizontal Pod Autoscaler (HPA), Kubernetes automatically scaled up the replicas for the image-service.
       * The deployment's replica count increased from 2 to 10, then to 18, before stabilizing at 10 Pods.
       * The Grafana dashboard clearly showed a sharp increase in CPU usage, Memory usage,http requests, followed by a decrease as the new Pods were added.
    - Verifying Recovery:
       - Service Restoration:
          * After the load test ended, Kubernetes automatically scaled down the Pods gradually based on the HPA settings.
          * Returning the replica count to the original number (2 Pods).
          * The Grafana dashboard returned to its normal state, indicating that the service had recovered and stabilized. 

**Database Failure with API Service:**[View Video](https://bit.ly/3UlgOTS)
**Simulating a high utilization in Requests to the Image Service**[View Video](https://bit.ly/4fuLQlW)

---
- Setup Environment
   1. Prerequisites: 
      * Docker
      * Minikube: to use a Kubernetes cluster (for a local development environment) or a cloud provider.
      * kubectl
      * Helm
      * Load Testing Tool
---

   2. Steps:
      **Docker Installation and Configuration**
        3. Install Docker: Run the following command to install Docker on the local machine:
           curl -fsSL https://get.docker.com -o get-docker.sh
            sudo sh get-docker.sh
        4. Configure Docker daemon for local Registry:
           * If you are planning to use a local Docker registry on your machine
             . Edit the Docker daemon. json file, which exists on path '/etc/docker/deamon.json'.
             . If the file does not exist, create one.
             . Add the following configuration and replace with your local IP. 
            {
                 "insecure-registries": ["your-registry-host-(IP):5000"]
            }
             .Restart the Docker Engine
              'sudo systemctl restart docker'

            *Note*
             - If you use Docker Desktop, you can configure the code JSON format on it.
                 1. Go to the settings icon in the right corner, click, then will pop up page
                 2. Then navigate to the 'Docker Engine' will see there is an empty box. Enter the command in the box.
                 3. Click 'Apply & restart'

       5.  **Run Dokcer Registry**
             . Docker image Registry it's a private registry to store your repository images.
             . Following the command to run the container registry
               'docker run -d -p 5000:5000 --restart always --name registry registry:3'
             . --restart always: is the policy to reload the container even if there are issues with the registry container, or restart your machine? 
       6. **Build Docker Image and Push** 
            - Once the Docker daemon is configured, you can build and push to your local registry.

               * API_service:
                 'cd API_Service/'
               - Docker Build api_service
                 'docker build -f api-service -t your-registry-host(ip):5000/api-service:v1 .'
               - Push image api_service:
                 'docker push your-registry-host(ip):5000/api-service:v1'

               * Auth_service:
                  'cd Auth_service/'
               - Docker Build auth-service:
                  'docker build -f auth-service -t your-registry-host(ip):5000/auth-service:v1 .'
               - Push image auth-service:
                  'docker push your-registry-host(ip):5000/auth-service:v1'

               * Image_Service:
                  'cd Image_Service/'
               - Docker Build image-service:
                  'docker build -f image-service -t your-registry-host(ip):5000/image-service:v1 .'
               - Push image-service:
                  'docker push your-registry-host(ip):5000/image-service:v1'

               * Frontend_service:
                  'cd Frontend_service/'
               - Docker Build Frontend-service:
                  'docker build -f -f frontend-service -t your-registry-host(ip):5000/webportal-service:v1 .'
               - Push image webportal-service:
                   'docker push your-registry-host(ip):5000/webportal-service:v1'

      **Install Minikube and Configuration** 
        7. Install and configure the Environment local machine
           - Once to install Docker and configure it to install minikube to run as a container on Docker.
            'curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64'
             'sudo install minikube-linux-amd64 /usr/local/bin/minikube && rm minikube-linux-amd64'
             'minikube start --cpus=2 --memory=4096 --cni=calico --insecure-registry="your-registry-host(ip):5000"
            . Start Minikube: --cpu=2, you specify 'CPU' usage on your machine host. (I recommended allocating, if you do not specify will take the resource of the machine). 
            . Start Minikube: --memory=4096, you specify 'Memory' usage on your machine host. (I recommend allocating; if you do not specify will take resources of the machine).
            . Start Minikube: --cni=calico, you must specify a Container Network Interface (CNI) that supports Network Policies, such as Calico, Cilium, or Weave Net.
            . Start Minikube: --insecure-registry, you must specify the registry container to the minikube to allow you to pull images from the registry.

      **kubbctl runs objects Kubernetes cluster**
        8. Runs Deployment on Kubernetes cluster
         - Run 'namespace' to allocate each object for the namespace
            'kubectl create namespace apps-services'
            'kubectl create namespace frontend-service'
         - Run
             'kubectl create secret docker-registry my-registry-creds --docker-server=your-registry-host(ip):5000 --docker-username=<username> --docker-password=<Password>  --docker-email=<email>  -n app-services'
             'kubectl create secret docker-registry my-registry-creds --docker-server=your-registry-host(ip):5000 --docker-username=<username> --docker-password=<Password>  --docker-email=<email>  -n freontend-services'
         * I divided the files to easily apply the deployments
            * Issure Certification:
               - I put the 'self-signed-issuer.yml' in the global file because most apps are following the namespace apps-services
               'kubectl -f Apps_deployment/selfsigned-issuer.yml'
            * Postgresql-Group:
               - Create an empty file to store the data of the database.
                   'mkdir -p Apps_deployment/mountDatabase'
               - I started with 'Database', most apps depend on the Database, Postgres, ConfigMap, and Secret. 
                   'kubectl -f Apps_deployment/Postgresql-Group/'
            * Api_Group: 
               'kubectl apply -f Apps_deployment/Api-Group/'
            * Authentication-Group:
               'kubectl apply -f Apps_deployment/Authntaction-Group/
            * Image-Group:
               'kubectl apply -f Apps_deployment/Image-Group/'
            * WebPortal-Group:
                'kubectl -f Apps_deployment/WebPortal-Group/'
             - I already put Issure with the Group of WebPortal because I have one app under the namespace 'frontend-service'
         - Network-Policy:
           **Informations:**
             - Before starting to apply Network, there are two concepts: 'ingress', 'egress'
                * Ingress in network policy -> (That means when you receive your friend) and (which door will receive your friend)--> that means (Ports).
                * Egress in  network policy -> (That means when your friend goes) and (which door will reception you)--> that means (Ports).
          9. Run NetworkPolicy
              - I divided the file of group policy, and there are two YAML files it's outside the divide.
            * Policies Deny all :
               - It's important to put on your infrastructure from concept 'default security' to prevent all pods from communicating with each other.
               - After that, you can allow by specifying ports for each application
               * Network Policy Deny:
                  'kubectl -f Policy-Group/deny-apps-services-all.yml'
                  'kubectl -f Policy-Group/deny-webportal-service-all.yml'
              * Network-Policy Api:
                  'kubectl -f Policy-Group/Policy-api-fromAndTo/'
              * Network-Policy Auth:
                  'kubectl -f Policy-Group/Policy-auth-fromAndTo/'
              * Network-Policy Image:
                  'kubectl -f Policy-Group/Policy-image-fromAndTo'
              * Network-Policy webportal:
                  'kubectl -f Policy-Group/Policy-webportal-fromAndTo/'
              * Network-Policy Postgres-SQL:
                  'kubectl -f Policy-Group/Policy-postgresql-fromAndTo/'


     **Instaltion Helm Chart & Prometheus Community Kubernetes Helm Charts**
        10. Helm Charts:
            - Helm charts -> it's a collection of resources including configMaps, secrets, deployments & services, and anything required for deploying the Applications on Kubernetes.
               * Helm install
                  'curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3'
                  'chmod 700 get_helm.sh'
                  './get_helm.sh'










---
**File Structure**
.
├── API_Service
│   ├── api-service
│   ├── config.py
│   ├── main.py
│   ├── models.py
│   └── requirements.txt
├── Apps_deployment
│   ├── Api-Group
│   │   ├── api-deployment.yml
│   │   ├── api-hpa.yml
│   │   ├── api-ingress.yml
│   │   ├── api-pdb.yml
│   │   └── api-service.yml
│   ├── Authntaction-Group
│   │   ├── apps-secret.yml
│   │   ├── auth-deployment.yml
│   │   ├── auth-hpa.yaml
│   │   ├── auth-ingress.yml
│   │   ├── auth-pdb.yml
│   │   └── auth-service.yml
│   ├── debug-pod-apps-services.yaml
│   ├──  debug-pod-frotend.yml
│   ├── Image-Group
│   │   ├── image-deployment.yml
│   │   ├── image-hpa.yml
│   │   ├── image-ingress.yml
│   │   ├── image-pdb.yml
│   │   └── image-service.yml
│   ├── mountDatabase
│   ├── namecpace.yml
│   ├── Policy-Group
│   │   ├── deny-apps-services-all.yml
│   │   ├── deny-webportal-service-all.yml
│   │   ├── Policy-api-fromAndTo
│   │   │   ├── allow-api-egress-to-auth.yml
│   │   │   ├── allow-api-egress-to-postgresql.yml
│   │   │   ├── allow-api-ingress-from-auth.yml
│   │   │   ├── allow-api-ingress-from-image.yml
│   │   │   └── allow-api-ingress-from-webportal.yml
│   │   ├── Policy-auth-fromAndTo
│   │   │   ├── allow-auth-egress-to-postgresql.yml
│   │   │   └── allow-auth-ingress-from-api.yml
│   │   ├── Policy-image-fromAndTo
│   │   │   └── allow-image-ingress-from-api.yml
│   │   ├── Policy-postgresql-fromAndTo
│   │   │   ├── allow-postgresql-ingress-from-api.yml
│   │   │   ├── allow-postgresql-ingress-from-auth.yml
│   │   │   └── deny-postgresql-egress-to-all.yml
│   │   └── Policy-webportal-fromAndTo
│   │       └── allow-webportal-egress-to-api.yml
│   ├── Postgresql-Group
│   │   ├── postgres-config.yml
│   │   ├── postgres-deployment.yml
│   │   ├── postgres-exporter-deployment.yml
│   │   ├── postgres-exporter-service.yml
│   │   ├── postgres-pvc.yml
│   │   ├── postgres-pv.yml
│   │   ├── postgres-secret.yml
│   │   └── postgres-service.yml
│   ├── Prometheus-Configuration
│   │   ├── alertmanager.yml
│   │   ├── app-alerts-rules.yml
│   │   ├── apps-monitors.yml
│   │   └── webhook-certificate.yml
│   ├── selfsigned-issuer.yml
│   └── WebPortal-Group
│       ├── webportal-certificate.yml
│       ├── webportal-config.yml
│       ├── webportal-deployment.yml
│       ├── webportal-ingress.yml
│       ├── webportal-issuer.yml
│       └── webportal-service.yml
├── Auth_service
│   ├── auth-service
│   ├── index.js
│   ├── package.json
│   └── package-lock.json
├── Frontend_service
│   ├── default.conf
│   ├── frontend-service
│   └── index.html
├── grafana_dashBoard
│   ├── Application API-1754752132896.json
│   ├── Application Authentication-1754752149731.json
│   ├── Application Image-1754752169119.json
│   ├── Application WebPortal-1754752183088.json
│   ├── Over All system-1754752225403.json
│   └── PostgreSQL Database-1754752206458.json
├── Image_Service
│   ├── go.mod
│   ├── go.sum
│   ├── image-service
│   └── main.go
├── README.md
└── Reports of Project
    ├── HPA_Result.jpg
    └── ResultOfImageService.jpg

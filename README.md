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

---

### 4. Authentication Service
- The Authentication service is an internal component that verifies user credentials, such as usernames and passwords.
- It does not handle direct external requests; instead, it receives data from the main API service.
- Built with **`Python`**, it processes and validates login information to ensure secure access.

---

### 5. Image Service
- Serves as a centralized storage zone for user images, providing access and retrieval capabilities.
- Built with **`Go`** to ensure performance and scalability.

---

### 6. Docker Containerization
- **`Docker`** is a containerization technology that allows to package applications and their dependencies into isolated units called containers.
- I used Docker to build container images, which are then deployed, orchestrated, and managed by **`Kubernetes`**.

#### My Docker Images
- `api-service`
- `auth-service`
- `image-service`
- `webportal-service`
- **`Registry images`**: used to store the Docker images that are built internally.

---

### Kubernetes Orchestration

Kubernetes is a container orchestration platform designed to manage and scale large numbers of containers across a cluster of machines.

**Implementation Steps:**

1. **Deployed Containers as Deployments**
   - Managed **Pods** and enabled scaling up or down as needed.

2. **Configured Horizontal Pod Autoscaler (HPA)**
   - Enabled dynamic autoscaling to automatically add new Pods when resources are highly utilized.

3. **Set Up Kubernetes Services**
   - Configured **ClusterIP** services for internal communication between Pods.

4. **Applied NetworkPolicies**
   - Restricted network traffic to only authorized Pods, enhancing security and reducing unnecessary connections.

5. **Configured Health Probes**
   - Implemented **livenessProbes** to restart unhealthy Pods.
   - Implemented **readinessProbes** to ensure Pods receive traffic only when ready.

6. **Created Pod Disruption Budget (PDB)**
   - Ensured a minimum number of Pods remain available during maintenance or node upgrades.

7. **Managed Sensitive Data with Secrets**
   - Stored passwords and other sensitive data in **Kubernetes Secrets**, securely passed to Pods.

8. **Managed Non-Sensitive Configuration**
   - Used **ConfigMaps** to store environment variables or application settings.

9. **Provisioned Persistent Storage**
   - Configured **Persistent Volumes (PV)** and **Persistent Volume Claims (PVC)** for applications and databases.

---

### Ingress Controller
- Routes **HTTP/HTTPS** traffic to services.
- Configured routing to service endpoints and secured it using self-signed **TLS certificates**.

---

### Issuer with cert-manager
- **Issuer** → Kubernetes object used to release certificates.
- **cert-manager** → Kubernetes controller managing TLS certificates, including self-signed ones, automatically.
- Configured the **Issuer** and referenced it in the **Certificate** object to create the **TLS secret**.

---

### OpenSSL with Secret TLS
- **OpenSSL** → Tool to generate TLS self-signed certificates locally.
- Steps:
  1. Generated **Private Key**.
  2. Created a **Certificate Signing Request (CSR)** and generated the certificate.
  3. Allocated the certificate with the key to Kubernetes **secret tls**.

> [!NOTE]
> There are three ways to generate certificates in Kubernetes:
> 1. **Manual** 🛠️
>    - Use **OpenSSL** to generate certificates and manually create the TLS secret.
> 2. **With Issuer and cert-manager** 📜
>    - Create Kubernetes objects (**Issuer** and **Certificate**) managed automatically by **cert-manager**.
>    - *(Implementation method used in this project)*
> 3. **Automated via Ingress Annotations** 🚀
>    - Create an **Issuer** and reference it in the Ingress annotations (`cert-manager.io/issuer`).
>    - cert-manager automatically generates and manages the certificate.

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
                 "insecure-registries": ["the-registry-host-(IP):5000"]
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
               - Docker Build api_service:
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

      **install Minikube and Configuration** 
        7. Install and Configuration Environment local meachine
           - Once to install Docker and configure install mninikube to run as container on docker.
            'curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64'
             'sudo install minikube-linux-amd64 /usr/local/bin/minikube && rm minikube-linux-amd64'
             'minikube start --cpus=2 --memory=4096 --cni=calico --insecure-registry="your-registry-host(ip):5000'
            . Start Minikube: --cpu=2, you specify 'CPU' usge on your mechine host.(I recomended to allocate if you does not specfiy will take resource of mechine). 
            . Start Minikube: --memory=4096, you specify 'Memory' usge on your mechine host.(I recomended to allocate if you does not specfiy will take resource of mechine).
            . Start Minikube: --cni=calico, you must specify a Container Network Interface (CNI) that supports Network Policies, such as Calico, Cilium, or Weave Net.
            . Start Minikube: --insecure-registry, you must specify registry container to the minikube to allow you pull images from registry.

      **kubbctl runs objects kuberentes culster**
        8. Runs Deployment on kuberenetes culster
         - Run 'namespace' to allocate each objects for the namespace
            'kubectl create namespace apps-services'
            'kubectl create namespace frontend-service'
         - Run following, To define your registry in Kubernetes, it's recommended to use a Secret for securely storing credentials, instead of including them directly in your configuration files. This approach enhances security and makes your configurations more manageable. 
             'kubectl create secret docker-registry my-registry-creds --docker-server=your-registry-host(ip):5000 --docker-username=<username> --docker-password=<Password>  --docker-email=<email>  -n app-services'
             'kubectl create secret docker-registry my-registry-creds --docker-server=your-registry-host(ip):5000 --docker-username=<username> --docker-password=<Password>  --docker-email=<email>  -n freontend-services'
         * I devided the files to easy apply the deployments
            * Issure Certification:
               - I put the 'self-signed-issuer.yml' in the global file because most apps are following the namespace apps-services
               'kubectl -f Apps_deployment/selfsigned-issuer.yml'
            * Postgresql-Group:
               - Create empty file to store data of database.
                   'mkdir -p Apps_deployment/mountDatabase'
               - I sterted with 'Databse' most apps is depends on the Database postgres , ConfigMap , Secret. 
                   'kubectl -f Apps_deployment/Postgresql-Group/'
            * Api_Group: 
               'kubectl apply -f Apps_deployment/Api-Group/'
            * Authntaction-Group:
               'kubectl apply -f Apps_deployment/Authntaction-Group/
            * Image-Group:
               'kubectl apply -f Apps_deployment/Image-Group/'
            * WebPortal-Group:
                'kubectl -f Apps_deployment/WebPortal-Group/'
             - I already put Issure with the Group of WebPortal because I have one app under the namespace 'frontend-service'
         - Network-Policy:
           **Informations:**
             - Before to start apply Networkpolicy there are two concepts 'ingress' , 'egress'
                * Ingress in network policy -> (That meaning when reception your friend) and (which door will reception your friend)--> that mean(Ports).
                * Egress in  network policy -> (That meaning when goes your friend) and (which door will reception you)--> that mean(Ports).
          9. Run NetworkPolicy
              - I devided the file of grop policy and there are two yaml file it's outside the devided.
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
              * Network-Policy Pstgres-sql:
                  'kubectl -f Policy-Group/Policy-postgresql-fromAndTo/'


     **Instaltion Helm Chart & Prometheus Community Kubernetes Helm Charts**
        10. Helm Charts:
            - helm charts -> it's collections of resource incloud configMaps , secets , deplyment & services any thing that rquire for deployment the Applications on Kuberenets.
               * Helm install
                  'curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3'
                  'chmod 700 get_helm.sh'
                  './get_helm.sh'

        12. Prometheus:
            - Install Prometheus-community:
               A. Add rep prometheus-community to helm & updated helm.
                   'helm repo add prometheus-community https://prometheus-community.github.io/helm-charts'
                   'helm repo update'
               C. Install prometheus-stack with create namespace.
                   'helm install prometheus-stack prometheus-community/kube-prometheus-stack -n monitoring --create-namespace'

                * Configuration Prometheus-community:
                    - To configure Prometheus to scrape metrics from your applications, apply your ServiceMonitor resources. These resources define which services Prometheus should monitor.
                       * ServiceMonitor(api, auth, image, webportal, postgres):
                          - Link between Prometheus must configure 'serviceMonitor' which is specify to Prometheus.
                             'kubectl apply -f Apps_deployment/prometheus-Configruation/apps-monitors.yml'

                       * PrometheusRule:
                          - Apply your PrometheusRule to set up alerting rules. These rules are used by Prometheus to generate alerts, which are then sent to Alertmanager.. 
                             'kubectl apply -f Apps_deployment/prometheus-Configruation/app-alerts-rules.yml'

                       * Alertmanager:
                          - Configure Alertmanager to route alerts to Slack. This is done by creating an `alertmanager.yml` file with your Slack webhook URL and applying it as a Kubernetes Secret:
                              1. use any editor 'nano', 'vi' to  set file *alertmanager.yml* this part.
                                 ' slack_configs:
                                  '- channel: '#Apps-Alerts'
                                   api_url: 'https://hooks.slack.com/'
                              *Note*
                                  * Create your alertmanager.yml file with the Slack webhook URL.
                                  - You must have accout on *slack* .
                                  - Get the url *Incoming Webhooks*
                                  - api_url: 'https://hooks.slack.com/'
                          - Create the Secret from the configuration file.
                             'kubectl create secret generic alertmanager-config --from-file=Apps_deployment/prometheus-Configruation/alertmanager.yml -n monitoring --dry-run=client -o yaml | kubectl apply -f -'
                          - Update the Helm release to use the new Secret.
                             'helm upgrade prometheus-stack prometheus-community/kube-prometheus-stack \
                              --namespace monitoring \
                              --set alertmanager.config.configmapName=alertmanager-config \
                              --set alertmanager.config.templateSecretName=alertmanager-config'
                           * Create ingress for Alertmanager to allow you to access over 'HTTPs' page insted of using 'port-forward'.
                               'kubectl apply -f alertManager-ingress.yml'

         # 13. Grafana:
               - Once to setup & configuretion Prometheus and Alertmanager
                  * Create ingress for Grafana to allow you to access over 'HTTPs' page insted of using 'port-forward'.
                      'kubectl apply -f grafana-ingress.yaml'
                       'https://grafana.local'
                  1- There are two way to insert to 'visualization dashbord':
                      A. Manual:
                         1. Go to on the left bar 'Dashboards'.
                         2. After open page Dashboards click the button 'New'.
                         3. Then list drop choose 'import'.
                         4. Finaly, import the files json dashbord.
                         5. File has dashbord direcory 'Grafana_DashBoard'.
                      B. Automated import dashbord to Grafana
                         * Upgrading 'kube-prometheus-stack' chart to using the custom 'grafana-values.yml' file.
                         1. Create configMap from dashbord file containe all dashbord files from dirctory 
                           'kubectl create configmap my-grafana-dashboards --from-file=grafana_dashBoard/ -n monitoring'
                         2. Add lable and Annotation these lable and Annotation is what the Grafana sidecar looks for to provision the dashboards.
                           'kubectl label configmap my-grafana-dashboards grafana_dashboard="1" -n monitoring'
                           'kubectl annotate configmap my-grafana-dashboards grafana_folder="Application Services" -n monitoring'
                         3.Upgrade 'kube-prometheus-stack' to use the values file that enables the sidecar to detect these dashboards.
                           'helm upgrade prometheus-stack prometheus-community/kube-prometheus-stack -n monitoring -f grafana-values.yml'
                         4. Finaly, this manner insted to import each dashbord manual.
---
- Lessons learned
   



x





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
│   ├── Authentication-Group
│   │   ├── apps-secret.yml
│   │   ├── auth-deployment.yml
│   │   ├── auth-hpa.yaml
│   │   ├── auth-ingress.yml
│   │   ├── auth-pdb.yml
│   │   └── auth-service.yml
│   ├── DashBord_Grafana
│   │   └── grafana-values.yml
│   ├── debug-pod-apps-services.yaml
│   ├──  debug-pod-frotend.yml
│   ├── Image-Group
│   │   ├── image-deployment.yml
│   │   ├── image-hpa.yml
│   │   ├── image-ingress.yml
│   │   ├── image-pdb.yml
│   │   └── image-service.yml
│   ├── mountDatabase
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
│   ├── prometheus-Configruation
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
├── deploy_Apps_K8s.sh
├── Frontend_service
│   ├── default.conf
│   ├── frontend-service
│   └── index.html
├── Grafana_DashBoard
│   ├── Application-API-1754752132896.json
│   ├── Application-Authentication-1754752149731.json
│   ├── Application-Image-1754752169119.json
│   ├── Application-WebPortal-1754752183088.json
│   ├── Over-All-system-1754752225403.json
│   └── PostgreSQL-Database-1754752206458.json
├── Image_Service
│   ├── go.mod
│   ├── go.sum
│   ├── image-service
│   └── main.go
├── README.md
└── Reports of Project
    ├── HPA_Result.jpg
    └── ResultOfImageService.jpg

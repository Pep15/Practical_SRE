# Built and Deployed the Environment

---

### 1. Infrastructure and Environment
- I set up a Kubernetes environment using **`Minikube`**, which serves as an ideal platform for local development.
- It provides a flexible space for application testing, troubleshooting, and experimentation.

---

### 2. User Interface Service
- The user interface for login and registration using **`HTML`** and **`JavaScript`**.
- This interface integrates with the API to handle image uploads, register new users, validate login credentials, and display profiles of users.

---

### 3. API Service
- The Application Programming Interface (**`API`**) is built using **`Python`** to handle data coming from users.
- The backend logic processes this data and communicates with other services, applying the **`Gateway Pattern`** to manage requests and responses efficiently.

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
- **`Docker`** is a containerization technology that allows you to package applications and their dependencies into isolated units called containers.
- I used Docker to build container images, which are then deployed, orchestrated, and managed by **`Kubernetes`**.

#### My Docker Images
- `api-service`
- `auth-service`
- `image-servic`
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
1. **Manual** 🛠️  
   - Use **OpenSSL** to generate certificates and manually create the TLS secret.

2. **With Issuer and cert-manager** 📜  
   - Create Kubernetes objects (**Issuer** and **Certificate**) managed automatically by **cert-manager**.  
   - *(Implementation method used in this project)*

3. **Automated via Ingress Annotations** 🚀  
   - Create an **Issuer** and reference it in the Ingress annotations (`cert-manager.io/issuer`).  
   - cert-manager automatically generates and manages the certificate.

---

### Helm Charts for Kubernetes
- **Helm** → Package manager for Kubernetes, allowing definition, installation, and management of applications using preconfigured charts.
- Installed Helm charts.
- Used Helm to deploy the **prometheus-community** chart, which bundles:
  - `Prometheus`
  - `AlertManager`
  - `Grafana`

---

### Prometheus, AlertManager, and Grafana
- **Prometheus** → Monitoring tool that scrapes metrics and stores them in a time-series database (**TSDB**).  
  - Configured Prometheus to scrape metrics from services and persist the data.  
  - Templates defined which services Prometheus should scrape.

- **AlertManager** → Groups, routes, and silences alerts from Prometheus before sending them to endpoints like email or Slack.  
  - Configured alerting rules and routing/receivers.

- **Grafana** → Data visualization tool for creating dashboards to monitor service metrics.  
  - Configured Prometheus as a data source.  
  - Created dashboards for key metrics:
    - `Status Pods`
    - `Histogram Bucket`
    - `HTTP Request Count`
    - `CPU Usage`
    - `Memory Usage`

> [!NOTE]
> Some services require an **external exporter** alongside the Pod to collect metrics.  
> These exporters must be included in **Prometheus scrape configurations** to ensure proper monitoring.

----
## Steps of failure simulation and recovery verification.

### Database Failure with API Service:
[View Database Failure with API Service Video](https://bit.ly/3UlgOTS)

* **Pre-Failure State Monitoring:**
    * I began by using the **'watch'** command-line tool with **'kubectl describe'** to monitor the Postgres database Deployment in the app-services namespace using:
        ```bash
        watch -n1 kubectl describe deployment <name-of-deployment> -n <namespace>
        ```
    * Concurrently, I observed the Pods with **'kubectl get'** Postgres and API services status.
        ```bash
        kubectl get pod -n <namespace> -l <label-of-pod-inside-yaml> -w
        ```
        * `-w --> is watch for changes.`
    * Then, I used **'kubectl logs -f'** to print the logs for a container in a pod resource streamly.
        ```bash
        kubectl logs -f <name-of-pod> -n <namespace>
        ```
    * Grafana dashboards and AlertManager showed a normal operational state (the database dashboard was **"Up"** and no active alerts existed). A new user was successfully registered via the frontend (webportal.local), confirming that all services were functioning correctly.

* **Simulating the Failure:**
    * To simulate a database failure, you scaled down the Postgres Deployment to zero replicas using **'kubectl scale deployment'**.
        ```bash
        kubectl scale deployment <name-of-deployment> --replicas=<number-scale> -n <namespace>
        ```
    * This action terminated the database Pod, causing the API service to lose its connection to the database.

* **Verifying Recovery:**
    * **Failure Detection:**
        * AlertManager detected the failure, initially showing a **Pending**.
        * Alert **Pending**:
            1.  `PostgresExporterHighScrapeLatency`
            2.  `APIServiceDown`
    * **Frontend failed:**
        * Attempts to log in through the frontend failed with a **"Failed to communicate with Auth service"** error.
        * The Grafana dashboard for the API service also showed a **"Down"** status.
    * **Service Restoration:**
        * Restored the service by scaling the database replicas back to one using **'kubectl scale deployment'**.
            ```bash
            kubectl scale deployment <name-of-deployment> --replicas=<number-scale> -n <namespace>
            ```

---

### Simulating a high utilization in Requests to the Image Service.

[View Simulating a high utilization in Requests to the Image Service Video](https://bit.ly/4fuLQlW)
* **Pre-Failure State Monitoring:**
    * started by monitoring the image-service Deployment in the app-services namespace using:
        ```bash
        watch -n1 kubectl describe deployment <name-of-deployment> -n <namespace>
        ```
    * Concurrently, I observed the HPA with **'kubectl get hpa'** Image-service utilize pod.
        ```bash
        kubectl get hpa <name-of-pod> -n <namespace>
        ```
    * The service initially had 2 replicas. The Grafana dashboards showed low CPU and memory usage for the service.

* **Simulating the Failure:**
    * I used the **'hey'** tool to generate and send a large number of requests:
        ```bash
        hey -n 100000 -c 100 [https://images.local/uploads/](https://images.local/uploads/)<image-name>.png
        ```
    * Due to the high utilization in CPU usage exceeding the threshold defined in the Horizontal Pod Autoscaler (HPA), Kubernetes automatically scaled up the replicas for the image-service.
    * The deployment's replica count increased from 2 to 10, then to 18, before stabilizing at 10 Pods.
    * The Grafana dashboard clearly showed a sharp increase in CPU usage, Memory usage,http requests, followed by a decrease as the new Pods were added.

* **Verifying Recovery:**
    * **Service Restoration:**
        * After the load test ended, Kubernetes automatically scaled down the Pods gradually based on the HPA settings.
        * Returning the replica count to the original number (2 Pods).
        * The Grafana dashboard returned to its normal state, indicating that the service had recovered and stabilized.
----
## Setup Environment

### Prerequisites:
* **Docker:** Manage applications using containers.
* **Minikube:** To use a Kubernetes cluster (for a local development environment) or a cloud provider.
* **kubectl:** Is the command-line tool for interacting with Kubernetes clusters.
* **Helm:** A package manager for Kubernetes.
* **Load Testing Tool:** using `hey`.

### Steps:
#### Docker Installation and Configuration
1.  **Install Docker:** Run the following command to install Docker on the local machine:
    ```bash
    curl -fsSL [https://get.docker.com](https://get.docker.com) -o get-docker.sh
    sudo sh get-docker.sh
    ```
2.  **Configure Docker daemon for local Registry:**
    * If you are planning to use a local Docker registry on your machine:
        * Edit the Docker `daemon.json` file, which exists on path `/etc/docker/deamon.json`.
        * If the file does not exist, create one.
        * Add the following configuration and replace with your local IP.
            ```json
            {
                 "insecure-registries": ["your-registry-host-(IP):5000"]
            }
            ```
        * Restart the Docker Engine:
            ```bash
            sudo systemctl restart docker
            ```


> [!INFORMATION]

> If you use Docker Desktop, you can configure the code JSON format on it.
1. Go to the settings icon in the right corner, click, then will pop up page.
2. Then navigate to the 'Docker Engine' will see there is an empty box. Enter the command in the box.
3. Click 'Apply & restart'.

   
3. **Run Docker Registry**
    * Docker image Registry it's a private registry to store your repository images.
    * Following the command to run the container registry:
        ```bash
        docker run -d -p 5000:5000 --restart always --name registry registry:2
        ```
        > **`--restart always`**: is the policy to reload the container even if there are issues with the registry container, or restart your machine.


4. **Build Docker Image and Push**
    * Once the Docker daemon is configured, you can build and push to your local registry.
    * **API_service:**
        ```bash
        cd API_Service/
        # Docker Build api_service:
        docker build -f api-service -t your-registry-host(ip):5000/api-service:v1 .
        # Push image api_service:
        docker push your-registry-host(ip):5000/api-service:v1
        ```
    * **Auth_service:**
        ```bash
        cd Auth_service/
        # Docker Build auth-service:
        docker build -f auth-service -t your-registry-host(ip):5000/auth-service:v1 .
        # Push image auth-service:
        docker push your-registry-host(ip):5000/auth-service:v1
        ```
    * **Image_Service:**
        ```bash
        cd Image_Service/
        # Docker Build image-service:
        docker build -f image-service -t your-registry-host(ip):5000/image-service:v1 .
        # Push image-service:
        docker push your-registry-host(ip):5000/image-service:v1
        ```
    * **Frontend_service:**
        ```bash
        cd Frontend_service/
        # Docker Build Frontend-service:
        docker build -f frontend-service -t your-registry-host(ip):5000/webportal-service:v1 .
        # Push image webportal-service:
        docker push your-registry-host(ip):5000/webportal-service:v1
        ```



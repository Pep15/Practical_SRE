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

> **Note:**  
  > There are three ways to generate certificates in Kubernetes:  
  > 1. **Manual**: Use OpenSSL and manually create the TLS secret.  
  > 2. **With Issuer and cert-manager**: Create Kubernetes objects (**Issuer** and **Certificate**) managed by cert-manager (Implementation).  
  > 3. **Automated via Ingress Annotations**: Create an **Issuer** and reference it in Ingress annotations (`cert-manager.io/issuer`) so cert-manager automatically generates the certificate.

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

> **Note:**  
> Some services require an external exporter alongside the Pod to collect metrics.  
> These exporters must be defined in Prometheus scrape configurations for monitoring.

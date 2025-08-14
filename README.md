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

### 7. Kubernetes Orchestration
- It is a container orchestration platform designed to manage and scale large numbers of containers across a cluster of machines.
- I used Kubernetes to run containers as **Deployments**, which control **Pods** and allow scaling up or down as needed.
- Implemented **dynamic autoscaling (HPA)** to automatically add new pods to the cluster when resources are highly utilized.
- Configured **Kubernetes Services** to route traffic to the Pods, using **ClusterIP** for internal communication between them.
- Implemented **NetworkPolicies** to control network traffic between Pods, allowing only authorized communication and reducing unnecessary connections to enhance security.
- Configured **livenessProbes** and **readinessProbes** to monitor Pod health and traffic readiness, ensuring that Pods are restarted in case of application failures or are marked as unavailable until ready.
- Created a **Pod Disruption Budget (PDB)** to ensure that a minimum number of pods are kept running to maintain service availability during planned events or maintenance.
- Used **Kubernetes Secrets** to securely store passwords and other sensitive data, passing them to the pods through the deployment configuration.
- Implemented a **ConfigMap** to store non-sensitive configuration data, such as environment variables or application settings, and pass them to the pods.
- Configured **Persistent Volume (PV)** and **Persistent Volume Claim (PVC)** objects to allocate and manage persistent storage for applications and databases.

#### Ingress Controller
- A component in Kubernetes that allows routing **HTTP/HTTPS** traffic to services.
- Configured it to route traffic to service endpoints and secured it using self-signed **TLS** certificates.

#### Issuer with cert-manager
- **Issuer** → A Kubernetes object for releasing certificates.  
- **cert-manager** → A Kubernetes controller responsible for managing TLS certificates, including self-signed ones, automatically within the cluster.  
- Configured the issuer to release the certificate, then referenced it in the certificate object to create the **TLS secret**.

#### OpenSSL with Secret TLS
- **OpenSSL** → A tool that allows you to create **TLS self-signed certificates** locally.
- Used the OpenSSL command to generate the **Private Key**.
- Created a **Certificate Signing Request (CSR)** and generated the certificate.
- Allocated the certificate with the key to a Kubernetes **secret tls**.

**Note**  
There are three ways to generate certificates in Kubernetes:
1. **Manual**  
   - Using OpenSSL to generate certificates and manually creating the TLS secret.  
2. **With Issuer and cert-manager** (Implementation)  
   - Creating Kubernetes objects (**Issuer** and **Certificate**) managed by cert-manager.  
3. **Automated via Ingress Annotations**  
   - Creating an **Issuer** and referencing it in the Ingress annotations (`cert-manager.io/issuer`) so cert-manager automatically generates the certificate.

---

### 8. Helm Charts for Kubernetes
- **Helm** → The package manager for Kubernetes, allowing you to define, install, and manage Kubernetes applications using preconfigured charts.
- Installed Helm charts.
- Used Helm to install the **prometheus-community chart**, which includes a complete monitoring solution with:
  - `Prometheus`
  - `AlertManager`
  - `Grafana`

---

### 9. Prometheus, AlertManager, and Grafana
- **Prometheus** → A monitoring tool that scrapes metrics and stores them in a time-series database (**TSDB**).
- Configured Prometheus to scrape metrics from services and persist the collected data.
- Created scrape configuration templates for specific services.

- **AlertManager** → Works alongside Prometheus to group, route, and silence alerts before sending them to notification endpoints (e.g., email, Slack).
- Configured alerting rules and routing/receivers.

- **Grafana** → A visualization tool for monitoring service metrics.
- Configured Prometheus as a Grafana data source.
- Created dashboards for:
  - `Status Pods`
  - `Histogram Bucket`
  - `HTTP Request Count`
  - `CPU Usage`
  - `Memory Usage`

**Note**  
Some services require an external **exporter** alongside the Pod to collect metrics. These exporters must be included in Prometheus scrape configurations.

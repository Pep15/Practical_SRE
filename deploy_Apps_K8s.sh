#!/bin/bash
set -e

IP_ADDRESS=$(hostname -I | awk '{print $1}')
REGISTRY_PORT="5000"
DAEMON_FILE="/etc/docker/daemon.json"
INSECURE_REGISTRIES_ENTRY="\"insecure-registries\": [\"${IP_ADDRESS}:${5000}\"]"
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
declare -A SERVICES_TO_BUILD=(
  ["API_Service"]="api-service"
  ["Auth_service"]="auth-service"
  ["Image_Service"]="image-service"
  ["Frontend_service"]="webportal-service"
)

Deployment_FILES=(
  "Apps_deployment/Api-Group/"
  "Apps_deployment/Authentication-Group/"
  "Apps_deployment/Image-Group/"
  "Apps_deployment/WebPortal-Group/"
  "Apps_deployment/Postgresql-Group/"
)
NETWORK_POLICY_FILES=(
  "Apps_deployment/Policy-Group/Policy-api-fromAndTo/"
  "Apps_deployment/Policy-Group/Policy-auth-fromAndTo/"
  "Apps_deployment/Policy-Group/Policy-image-fromAndTo/"
  "Apps_deployment/Policy-Group/Policy-webportal-fromAndTo/"
  "Apps_deployment/Policy-Group/Policy-postgresql-fromAndTo/"
)


if [ -z "$IP_ADDRESS" ]; then
  echo "Error: Could not determine host IP address."
  echo "Please enter it manually: "
  read -r IP_ADDRESS
  if [ -z "$IP_ADDRESS" ]; then
    echo "No IP address provided. Exiting."
    exit 1
  fi
fi

echo "Using IP address: $IP_ADDRESS"
echo "---"

# --- install Curl ---
sudo apt update
sudo apt install -y curl

# ---  Docker Installation and Configuration ---
echo "Starting Docker installation and configuration..."

# Installation (using an alternative method to avoid pipe errors)
install_docker() {
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
    sleep 30
}
install_helm(){
  curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
  chmod 700 get_helm.sh
  ./get_helm.sh
  rm get_helm.sh
}


if ! command -v docker &> /dev/null; then
    install_docker
else
    echo "Docker is already installed. Skipping installation."
fi

if  ! command -v helm &> /dev/null; then
     install_helm
else 
     echo "Helm is already installed. Skipping installation."
fi


echo "Running Docker Registry and building images..."
if ! docker ps -a --format '{{.Names}}' | grep -q 'registry'; then
    docker run -d -p 5000:5000 --restart always --name registry registry:3
else
    echo "Docker registry container is already running."
fi

echo "Configuring Docker daemon for insecure registry..."

if ! grep -q "insecure-registries" "$DAEMON_FILE" 2>/dev/null; then
    echo "Adding insecure-registries entry to $DAEMON_FILE"

    
    if [ ! -s "$DAEMON_FILE" ]; then
        echo "{\"insecure-registries\": [\"${IP_ADDRESS}:${REGISTRY_PORT}\"]}" | sudo tee "$DAEMON_FILE" >/dev/null
 
    elif grep -q '^{[[:space:]]*}$' "$DAEMON_FILE"; then
        sudo sed -i.bak "s|{}|{\"insecure-registries\": [\"${IP_ADDRESS}:${REGISTRY_PORT}\"]}|" "$DAEMON_FILE"
 
    else
        sudo sed -i.bak "s|}|,\"insecure-registries\": [\"${IP_ADDRESS}:${REGISTRY_PORT}\"]}|" "$DAEMON_FILE"
    fi

    echo "Restarting Docker service to apply changes..."
    sudo systemctl restart docker
else
    echo "insecure-registries entry already exists in $DAEMON_FILE. No changes made."
fi

# -- install Minikube ---
if ! command -v minikube &> /dev/null; then
  echo "Installing Minikube..."
  curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64
  sudo install minikube-linux-amd64 /usr/local/bin/minikube
  rm minikube-linux-amd64
else
  echo "Minikube is already installed. Skipping installation."
fi

if ! command -v kubectl &> /dev/null; then
  echo "Installing kubectl..."
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/
else
  echo "kubectl is already installed. Skipping installation."
fi

echo "Starting minikube..."
minikube start --driver=docker --cpus=2 --memory=4096 --ports=80:80 --ports=443:443 --cni=calico --insecure-registry="${IP_ADDRESS}:${REGISTRY_PORT}"
minikube addons enable ingress
minikube addons enable ingress-dns

# ---  Modify hosts file ---

echo "Updating /etc/hosts file..."

HOST_ENTRIES=$(cat <<EOF
${IP_ADDRESS} grafana.local
${IP_ADDRESS} alertmanager.local
${IP_ADDRESS} api.local
${IP_ADDRESS} auth.local
${IP_ADDRESS} images.local
${IP_ADDRESS} webportal.local
EOF
)


sudo sed -i.bak '/# BEGIN CUSTOM HOSTS/,/# END CUSTOM HOSTS/d' /etc/hosts

cat <<EOF | sudo tee -a /etc/hosts > /dev/null
# BEGIN CUSTOM HOSTS - Managed by SRE script
$HOST_ENTRIES
# END CUSTOM HOSTS
EOF

echo "Hosts file updated successfully."

#--- Run Dokcer Registry ---

for service_dir in "${!SERVICES_TO_BUILD[@]}"; do
  image_name="${SERVICES_TO_BUILD[$service_dir]}"
  service_path="$ROOT_DIR/$service_dir"
  image_tag="${IP_ADDRESS}:${REGISTRY_PORT}/${image_name}:v1"

  echo ""
  echo "Building service: $service_dir  →  Image: $image_tag"

  (
    if docker build -f "$service_path/$image_name" -t "$image_tag" "$service_path"; then
       docker push "$image_tag"
      echo "Successfully built and push image: $image_tag"
    else
      echo "Build failed for image: $image_tag"
    fi
  )
done

echo "All Docker images have been built and pushed successfully."


# --- Install cert-manager ---
echo "Installing cert-manager CRDs..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.crds.yaml
sleep 5

echo "Creating cert-manager namespace..."
kubectl create namespace cert-manager || true

echo "Installing cert-manager components..."
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

echo "Waiting for cert-manager pods to be ready..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/instance=cert-manager,app.kubernetes.io/component=controller -n cert-manager --timeout=300s
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/instance=cert-manager,app.kubernetes.io/component=webhook -n cert-manager --timeout=300s
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/instance=cert-manager,app.kubernetes.io/component=cainjector -n cert-manager --timeout=300s
echo "Cert-manager ready."

# --- Create namespaces ---
echo "Creating namespaces..."
kubectl create namespace app-services || true
kubectl create namespace frontend-service || true
kubectl create namespace monitoring || true

# --- Create docker registry secrets ---
echo "Creating Docker Registry secrets..."

read -p "Please enter username: " Username
echo "----------------"

read -p "Please enter password: " Password
echo "----------------"

read -p "Please enter email: " Email
echo "----------------"

# Create the secret for the 'app-services' namespace
echo "Creating secret 'my-registry-creds' in namespace 'app-services'..."
kubectl create secret docker-registry my-registry-creds \
  --docker-server=${IP_ADDRESS}:${REGISTRY_PORT} \
  --docker-username=$Username \
  --docker-password=$Password \
  --docker-email=$Email \
  --namespace=app-services || true

# Create the secret for the 'frontend-service' namespace
echo "Creating secret 'my-registry-creds' in namespace 'frontend-service'..."
kubectl create secret docker-registry my-registry-creds \
  --docker-server=${IP_ADDRESS}:${REGISTRY_PORT} \
  --docker-username=$Username \
  --docker-password=$Password \
  --docker-email=$Email \
  --namespace=frontend-service || true


# --- Apply Self-signed Issuer ---
echo "Applying self-signed issuer..."
kubectl apply -f "${ROOT_DIR}/Apps_deployment/selfsigned-issuer.yml"
sleep 5


#-- Apply Applications Deployment ---
find "$ROOT_DIR/Apps_deployment" \
-path "*Policy-Group*" -prune -o \
-path "*prometheus-Configruation*" -prune -o \
-path "*DashBord_Grafana*" -prune -o \
-name "debug-pod-*.yml" -prune -o \
-name "debug-pod-*.yaml" -prune -o \
-type f \( -name "*.yml" -o -name "*.yaml" \) -print | while read -r yaml_file; do
    echo "DEBUG: Processing and applying -> $yaml_file"
    
    TEMP_FILE=$(mktemp)
    sed "s|\${IP_ADDRESS}|${IP_ADDRESS}|g" "$yaml_file" > "$TEMP_FILE"
    
    kubectl apply -f "$TEMP_FILE"
    
    rm "$TEMP_FILE"
done
echo "Core deployments applied successfully."




echo "Deployment applied successfully."


# --- Apply Network policy ---
for policy_path in "${NETWORK_POLICY_FILES[@]}"; do
  # The -f flag handles both single files and directories.
  echo "Applying: $policy_path"
  kubectl apply -f "$ROOT_DIR/$policy_path"
done

echo "Network Policies applied successfully."


# --- Wait for pods readiness ---
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=Ready pod -l app=api-service -n app-services --timeout=300s
kubectl wait --for=condition=Ready pod -l app=auth-service -n app-services --timeout=300s
kubectl wait --for=condition=Ready pod -l app=image-service -n app-services --timeout=300s
kubectl wait --for=condition=Ready pod -l app=postgres -n app-services --timeout=300s
kubectl wait --for=condition=Ready pod -l app=webportal-service -n frontend-service --timeout=300s
echo "All pods are ready."



# --- Wait for certificates ---
echo "Waiting for certificates to be ready..."
sleep 60
kubectl wait --for=condition=Ready certificate api-tls-secret -n app-services --timeout=300s || true
kubectl wait --for=condition=Ready certificate auth-tls-secret -n app-services --timeout=300s || true
kubectl wait --for=condition=Ready certificate image-tls-secret -n app-services --timeout=300s || true
kubectl wait --for=condition=Ready certificate webportal-tls-secret -n frontend-service --timeout=300s || true

if ! kubectl get configmap -n monitoring -l grafana_dashboard=1; then
        # ---  Create ConfigMaps for Grafana Dashboards ---
    echo "Creating ConfigMaps for Grafana Dashboards..."
    kubectl create configmap my-grafana-dashboards --from-file="$ROOT_DIR/Grafana_DashBoard/" -n monitoring

    # ---  Add Labels and Annotations to the ConfigMap ---
    echo "Adding labels and annotations to the Grafana dashboards ConfigMap..."
    kubectl label configmap my-grafana-dashboards grafana_dashboard="1" -n monitoring
    kubectl annotate configmap my-grafana-dashboards grafana_folder="Application Services" -n monitoring
  else
      echo "my-grafana-dashboards already created..."
  fi
       

# ---  Configure Alertmanager with Slack Webhook ---
echo "Configuring Alertmanager with Slack webhook..."

if ! kubectl get secret -n monitoring  alertmanager-config &> /dev/null; then
          # Prompt the user for the Slack webhook URL
read -p "Please enter your Slack webhook URL: " SLACK_WEBHOOK_URL

# Create a temporary alertmanager.yml file with the user-provided URL
TEMP_ALERTMANAGER_FILE=$(mktemp)
cat <<EOF > "$TEMP_ALERTMANAGER_FILE"
global:
  resolve_timeout: 5m
route:
  receiver: 'slack-notifications'
  group_by: ['alertname', 'job']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 1h
  routes:
    - match:
        severity: critical
      receiver: 'slack-notifications'
receivers:
  - name: 'slack-notifications'
    slack_configs:
      - channel: '#Apps-Alerts'
        api_url: "${SLACK_WEBHOOK_URL}"
        send_resolved: true
        title: '{{ template "slack.default.title" . }}'
        text: '{{ template "slack.default.text" . }}'
templates:
  - '/etc/alertmanager/config/*.tmpl'
EOF
  # Create a Kubernetes Secret from the temporary alertmanager file
echo "Creating alertmanager secret in monitoring namespace..."
kubectl create secret generic alertmanager-config --from-file="$TEMP_ALERTMANAGER_FILE" -n monitoring --dry-run=client -o yaml | kubectl apply -f -
else
    echo "the alertmanger already exists: " ${TEMP_ALERTMANAGER_FILE}
fi
        
# ---  Install/Upgrade Helm Chart ---
echo "Installing/upgrading kube-prometheus-stack with custom values..."

# Use a values file to configure Helm
# This file is created dynamically to include the necessary configurations.
TEMP_VALUES_FILE=$(mktemp)
cat <<EOF > "$TEMP_VALUES_FILE"
grafana:
  sidecar:
    dashboards:
      enabled: true
      label: "grafana_dashboard"
      labelValue: "1"
      folderAnnotation: "grafana_folder"
      searchNamespace: ALL
      provider:
        foldersFromFilesStructure: true
      initWait: 60
  ingress:
    enabled: true
    hosts:
      - grafana.local
    annotations:
      nginx.ingress.kubernetes.io/rewrite-target: /
    tls:
      - hosts:
          - grafana.local
        secretName: grafana-tls-secret
alertmanager:
  config:
    configmapName: alertmanager-config
    templateSecretName: alertmanager-config
EOF

echo "Adding Prometheus community Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update


# Check if the release already exists before installing
if helm get release prometheus-stack -n monitoring &> /dev/null; then
  if ! helm upgrade prometheus-stack prometheus-community/kube-prometheus-stack -n monitoring -f "$TEMP_VALUES_FILE"; then
     helm upgrade --install prometheus-stack prometheus-community/kube-prometheus-stack \
      --namespace monitoring \
      --create-namespace \
      -f "$TEMP_VALUES_FILE"
  fi
else
  helm install prometheus-stack prometheus-community/kube-prometheus-stack -n monitoring -f "$TEMP_VALUES_FILE"
fi

#  Apply ServiceMonitor and PrometheusRule manifests ---
echo "Applying ServiceMonitor and PrometheusRule manifests..."
kubectl apply -f "$ROOT_DIR/Apps_deployment/prometheus-Configruation/apps-monitors.yml"
kubectl apply -f "$ROOT_DIR/Apps_deployment/prometheus-Configruation/app-alerts-rules.yml"




# Remove temporary files
if [ -f "$TEMP_ALERTMANAGER_FILE" ]; then
    echo "Removing Alertmanager temp file: $TEMP_ALERTMANAGER_FILE"
    rm "$TEMP_ALERTMANAGER_FILE"
fi

if [ -f "$TEMP_VALUES_FILE" ]; then
    echo "Removing Helm values temp file: $TEMP_VALUES_FILE"
    rm "$TEMP_VALUES_FILE"
fi

echo "Deployment script finished successfully!"
echo "----------------------------------------"
echo "You can now open your browser on this Ubuntu VM and go to:"
echo "  https://api.local"
echo "  https://auth.local"
echo "  https://images.local"
echo "  https://webportal.local"
echo "  https://alertmanager.local"
echo "  https://grafana.local"
echo "----------------------------------------"

Paasword=$(kubectl --namespace monitoring get secret prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode) &> /dev/null


echo "User of Grafana Page: admin"
echo "Password of Grafana Page:" ${Paasword}

echo "Remember to accept the self-signed certificate warning if prompted."

echo "✅ Full deployment script finished successfully."

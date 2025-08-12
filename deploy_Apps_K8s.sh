#!/bin/bash
set -e

IP_ADDRESS=$(hostname -I | awk '{print $1}')
REGISTRY_PORT="5000"
DAEMON_FILE="/etc/docker/daemon.json"
INSECURE_REGISTRIES_ENTRY="\"insecure-registries\": [\"${IP_ADDRESS}:${5000}\"]"
ROOT_DIR="$(dirname "$0")"
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
  "Policy-Group/deny-apps-services-all.yml"
  "Policy-Group/deny-webportal-service-all.yml"
  "Policy-Group/Policy-api-fromAndTo/"
  "Policy-Group/Policy-auth-fromAndTo/"
  "Policy-Group/Policy-image-fromAndTo"
  "Policy-Group/Policy-webportal-fromAndTo/"
  "Policy-Group/Policy-postgresql-fromAndTo/"
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

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo."
  exit 1
fi

# --- install Curl ---
sudo apt update
sudo apt install -y curl

# ---  Docker Installation and Configuration ---
echo "Starting Docker installation and configuration..."

# Installation (using an alternative method to avoid pipe errors)
install_docker() {
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sleep 30
}

if ! command -v docker &> /dev/null; then
    install_docker
else
    echo "Docker is already installed. Skipping installation."
fi

Avoid_Typing_Sudo(){
    usermod -aG docker ${USER}
    su - ${USER}
    sudo usermod -aG docker $(whoami)
}

echo "Configuring Docker daemon for insecure registry..."

# Ensure the daemon.json file exists and is a valid JSON object
if ! grep -q "insecure-registries" "$DAEMON_FILE"; then
    echo "Adding insecure-registries entry to $DAEMON_FILE"

    # Use a single sed command to insert the entry with the correct JSON syntax.
    # This handles both empty and non-empty files correctly.
    if grep -q "{}" "$DAEMON_FILE"; then
        sudo sed -i.bak "s/{}/{\"insecure-registries\": [\"${IP_ADDRESS}:${REGISTRY_PORT}\"]}/" "$DAEMON_FILE"
    else
        sudo sed -i.bak "s/}$/,\"insecure-registries\": [\"${IP_ADDRESS}:${REGISTRY_PORT}\"]}/" "$DAEMON_FILE"
    fi
    
    echo "Restarting Docker service to apply changes..."
    sudo systemctl restart docker
else
    echo "insecure-registries entry already exists in $DAEMON_FILE. No changes made."
fi

# -- install Minikube ---
if [ "$EUID" -eq 0 ]; then
  # Run installation steps only
  if ! command -v minikube &> /dev/null; then
    curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64
    sudo install minikube-linux-amd64 /usr/local/bin/minikube && rm minikube-linux-amd64
  else
    echo "Minikube is already installed. Skipping installation."
  fi
else
  # Run docker, minikube commands here (no sudo)
  minikube start --driver=docker --cpus=2 --memory=4096 --ports=80:80 --ports=443:443 --cni=calico --insecure-registry="${IP_ADDRESS}:${REGISTRY_PORT}"
  minikube addons enable ingress
  minikube addons enable ingress-dns
fi

# ---  Modify hosts file ---
echo "Updating /etc/hosts file..."

# Define the host entries to be added
HOST_ENTRIES=$(cat <<EOF
${IP_ADDRESS} grafana.local
${IP_ADDRESS} alertmanager.local
${IP_ADDRESS} api.local
${IP_ADDRESS} auth.local
${IP_ADDRESS} images.local
${IP_ADDRESS} webportal.local
EOF
)

if grep -q "# End of section" /etc/hosts; then
    sudo sed -i "/# End of section/i ${HOST_ENTRIES}" /etc/hosts
else
    echo "$HOST_ENTRIES" | sudo tee -a /etc/hosts > /dev/null
fi
echo "Environment setup script finished successfully."

#--- Run Dokcer Registry ---

cd "$ROOT_DIR"

for service_dir in "${!SERVICES_TO_BUILD[@]}"; do
  image_name="${SERVICES_TO_BUILD[$service_dir]}"
  image_tag="${IP_ADDRESS}:${REGISTRY_PORT}/${image_name}:v1"
  
  echo "Processing service: $image_name"
  
  # Navigate to the service's directory
  cd "$ROOT_DIR/$service_dir"
  
  # Build the Docker image with the correct image name and tag
  echo "Building Docker image: $image_tag"
   docker build -t "$image_tag" .
  
  # Push the image to the local registry
  echo "Pushing Docker image: $image_tag"
  docker push "$image_tag"
  
  echo "Successfully built and pushed $image_name."
  echo "----------------------------------------"

  # Return to the root directory for the next iteration
  cd "$ROOT_DIR"
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

# --- Create docker registry secrets ---
echo "Creating Docker Registry secrets..."

read -p "Please enter username: " Username
echo "----------------"

read -sp "Please enter password: " Password
echo "----------------"

read -p "Please enter email: " Email
echo "----------------"

# Create the secret for the 'app-services' namespace
echo "Creating secret 'my-registry-creds' in namespace 'app-services'..."
kubectl create secret docker-registry my-registry-creds \
  --docker-server=${IP_ADDRESS}:${$REGISTRY_PORT} \
  --docker-username=$Username \
  --docker-password=$Password \
  --docker-email=$Email \
  --namespace=app-services || true

# Create the secret for the 'frontend-service' namespace
echo "Creating secret 'my-registry-creds' in namespace 'frontend-service'..."
kubectl create secret docker-registry my-registry-creds \
  --docker-server=${IP_ADDRESS}:${$REGISTRY_PORT} \
  --docker-username=$Username \
  --docker-password=$Password \
  --docker-email=$Email \
  --namespace=frontend-service || true


# --- Apply Self-signed Issuer ---
echo "Applying self-signed issuer..."
kubectl apply -f "${ROOT_DIR}/selfsigned-issuer.yml"
sleep 5


#-- Apply Applications Deployment ---
for deploy_file in "${Deployment_FILES[@]}";do
  # The -f flag handles both single files and directoreies.
  echo "Deloying apps: $deploy_file"
  kubectl apply -f "$ROOT_DIR/$deploy_file"
done
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
kubectl wait --for=condition=Ready pod -l app=webportal -n frontend-service --timeout=300s
echo "All pods are ready."



# --- Wait for certificates ---
echo "Waiting for certificates to be ready..."
sleep 60
kubectl wait --for=condition=Ready certificate api-tls-secret -n app-services --timeout=300s || true
kubectl wait --for=condition=Ready certificate auth-tls-secret -n app-services --timeout=300s || true
kubectl wait --for=condition=Ready certificate image-tls-secret -n app-services --timeout=300s || true
kubectl wait --for=condition=Ready certificate postgres-tls-secret -n app-services --timeout=300s || true
kubectl wait --for=condition=Ready certificate webportal-tls-secret -n frontend-service --timeout=300s || true


# ---  Create ConfigMaps for Grafana Dashboards ---
echo "Creating ConfigMaps for Grafana Dashboards..."
kubectl create configmap my-grafana-dashboards --from-file="$ROOT_DIR/grafana_dashBoard/" -n monitoring

# --- Step 2: Add Labels and Annotations to the ConfigMap ---
echo "Adding labels and annotations to the Grafana dashboards ConfigMap..."
kubectl label configmap my-grafana-dashboards grafana_dashboard="1" -n monitoring
kubectl annotate configmap my-grafana-dashboards grafana_folder="Application Services" -n monitoring

# --- Step 3: Configure Alertmanager with Slack Webhook ---
echo "Configuring Alertmanager with Slack webhook..."

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

# --- Step 4: Apply ServiceMonitor and PrometheusRule manifests ---
echo "Applying ServiceMonitor and PrometheusRule manifests..."
kubectl apply -f "$ROOT_DIR/prometheus-Configruation/apps-monitors.yml"
kubectl apply -f "$ROOT_DIR/prometheus-Configruation/app-alerts-rules.yml"


# --- Step 5: Install/Upgrade Helm Chart ---
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

# Check if the release already exists before installing
if helm get release prometheus-stack -n monitoring &> /dev/null; then
  helm upgrade prometheus-stack prometheus-community/kube-prometheus-stack -n monitoring -f "$TEMP_VALUES_FILE"
else
  helm install prometheus-stack prometheus-community/kube-prometheus-stack -n monitoring -f "$TEMP_VALUES_FILE"
fi

# --- Final Step: Cleanup ---
# Remove temporary files
rm "$TEMP_ALERTMANAGER_FILE" "$TEMP_VALUES_FILE"


echo "Deployment script finished successfully!"
echo "----------------------------------------"
echo "You can now open your browser on this Ubuntu VM and go to:"
echo "  https://api.local"
echo "  https://auth.local"
echo "  https://images.local"
echo "  https://webportal.local"
echo "  https://alertmanager.local"
echo "  https://grafana.local"

echo "Remember to accept the self-signed certificate warning if prompted."

echo "--- Full deployment script finished successfully. ---"

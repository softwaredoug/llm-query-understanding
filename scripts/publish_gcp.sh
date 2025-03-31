#!/bin/bash


ZONE="us-central1"
NAMESPACE="softwaredoug-training"
export PLATFORM="linux/amd64"


# Check if GCP_PROJECT_ID set
if [ -z "$GCP_PROJECT_ID" ]; then
  echo "GCP_PROJECT_ID is not set"
  exit 1
fi


if [ -z "$K8S_CLUSTER_NAME" ]; then
  echo "K8S_CLUSTER_NAME is not set"
  echo "Create a GKE k8s cluster with default setting, public IPv4"
  exit 1
fi

# Enable GCP services
gcloud services enable containerregistry.googleapis.com container.googleapis.com


export PROJECT_NUMBER=$(gcloud projects describe $GCP_PROJECT_ID --format='value(projectNumber)')
export DEFAULT_SERVICE_ACCOUNT="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

docker buildx build --platform $PLATFORM -t "gcr.io/$GCP_PROJECT_ID/fastapi-gke:latest" .

echo "DOCKER PUSH"

docker push "gcr.io/$GCP_PROJECT_ID/fastapi-gke:latest"

# Get service account
export SERVICE_ACCOUNT=$(gcloud container clusters describe $K8S_CLUSTER_NAME --zone us-central1 \
    --format="value(nodeConfig.serviceAccount)")

# If the service account is the default compute engine service account, then
# use the email address of the default service account
if [ "$SERVICE_ACCOUNT" == "default" ]; then
    SERVICE_ACCOUNT="${DEFAULT_SERVICE_ACCOUNT}"
fi


echo "SERVICE_ACCOUNT: $SERVICE_ACCOUNT"

# Grant the service account the roles/storage.objectViewer role
gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
    --member="serviceAccount:$SERVICE_ACCOUNT" \
    --role="roles/storage.objectViewer"



gcloud container clusters get-credentials "$K8S_CLUSTER_NAME" --zone "$ZONE" --project "$GCP_PROJECT_ID"
ERROR_CODE=$?
if [ $ERROR_CODE -ne 0 ]; then
    echo "❌ Error: GKE cluster '$K8S_CLUSTER_NAME' not found in project '$GCP_PROJECT_ID' and zone 'us-central1-c'."
    echo "👉 Possible remediation steps:"
    echo "  1. Verify the cluster name is correct and exists:"
    echo "     gcloud container clusters list --project \"$GCP_PROJECT_ID\""
    echo ""
    echo "  2. Make sure the cluster is in the correct zone (or region):"
    echo "     Try --region us-central1 if it's a regional cluster."
    echo ""
    echo "  3. Confirm the project ID is valid:"
    echo "     gcloud projects list"
    echo ""
    echo "  4. Check you're authenticated with the right account:"
    echo "     gcloud auth list"
    echo "     gcloud config set account your-account@gmail.com"
    echo ""
    echo "🔧 Adjust your script or environment variables accordingly and try again."
    exit 1
fi


K8S_CONTEXT=$(gcloud container clusters list \
  --filter="name=$K8S_CLUSTER_NAME" \
  --format="value(name.scope())" | sed "s/.*/gke_${GCP_PROJECT_ID}_${ZONE}_${K8S_CLUSTER_NAME}/")

# Create namespace if doesn't exist
kubectl  --context="$K8S_CONTEXT" create namespace $NAMESPACE


# Delete pod
kubectl --context="$K8S_CONTEXT" delete pod --selector=app=llm-query-understand -n $NAMESPACE

# Delete ALL pods and services in the namespace
kubectl --context="$K8S_CONTEXT" delete deployment --all -n $NAMESPACE
kubectl --context="$K8S_CONTEXT" delete pods --all -n $NAMESPACE
kubectl --context="$K8S_CONTEXT" delete services --all -n $NAMESPACE



# Read k8s/deployment.yaml
K8S_DEPLOYMENT=$(<k8s/deployment.yaml)
# Replace YOUR_PROJECT_ID with actual GCP project ID
K8S_DEPLOYMENT=${K8S_DEPLOYMENT//YOUR_PROJECT_ID/$GCP_PROJECT_ID}
echo "$K8S_DEPLOYMENT" > k8s/.deployment.yaml


# Check if k8s/deployment.yml has YOUR_PROJECT_ID and if so error,
# as it should be replaced with the actual project ID
if grep -q "YOUR_PROJECT_ID" k8s/.deployment.yaml; then
  echo "❌ Error: k8s/deployment.yaml contains 'YOUR_PROJECT_ID'."
  echo "👉 Please replace 'YOUR_PROJECT_ID' with your actual GCP project ID: $GCP_PROJECT_ID"
  exit 1
fi

kubectl --context="$K8S_CONTEXT" apply -f k8s/.deployment.yaml
kubectl --context="$K8S_CONTEXT" apply -f k8s/service.yaml

echo "Waiting for external IP..."
EXTERNAL_IP=""
for i in {1..30}; do
  EXTERNAL_IP=$(kubectl get service llm-query-understand --output=jsonpath='{.status.loadBalancer.ingress[0].ip}')
  if [[ -n "$EXTERNAL_IP" ]]; then
    echo "Service is available at http://$EXTERNAL_IP"
    break
  fi
  echo "Waiting for external IP $EXTERNAL_IP... (${i}/30)"
  sleep 5
done

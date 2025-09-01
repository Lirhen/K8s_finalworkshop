#!/bin/bash
set -e

pkill -f "kubectl port-forward" || true

echo "=== Deleting old namespaces ==="
kubectl delete namespace wordpress monitoring --ignore-not-found
kubectl wait --for=delete namespace wordpress --timeout=180s || true
kubectl wait --for=delete namespace monitoring --timeout=180s || true

echo "=== Creating namespaces ==="
kubectl apply -f wordpress/namespace.yaml
kubectl create namespace monitoring || true

echo "=== Creating ecr secret ==="
kubectl create secret docker-registry ecr-secret \
  --docker-server=992382545251.dkr.ecr.us-east-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region us-east-1) \
  --namespace=wordpress


echo "=== Deploying WordPress ==="
kubectl apply -f wordpress/secret.yaml
kubectl apply -f wordpress/wordpress-pvc.yaml
kubectl apply -f wordpress/mysql-statefulset.yaml
kubectl apply -f wordpress/wordpress-deployment.yaml
kubectl apply -f wordpress/mysql-service.yaml
kubectl apply -f wordpress/wordpress-service.yaml
kubectl apply -f wordpress/wordpress-ingress.yaml

echo "=== Adding Helm repos for monitoring ==="
helm repo add grafana https://grafana.github.io/helm-charts || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo update

echo "=== Deploying Grafana and Prometheus via Helm ==="
helm upgrade --install grafana grafana/grafana -n monitoring -f monitoring/grafana_values.yaml
helm upgrade --install prometheus prometheus-community/prometheus -n monitoring -f monitoring/prometheus_values.yaml

echo "=== Waiting for pods to be ready ==="
kubectl wait --for=condition=ready pod -l app=wordpress -n wordpress --timeout=300s
kubectl wait --for=condition=ready pod --all -n monitoring --timeout=300s

echo "=== Port-forwarding services ==="
kubectl port-forward -n wordpress svc/wordpress-service 8080:80 --address=0.0.0.0 &
kubectl port-forward -n monitoring svc/grafana 3000:80 --address=0.0.0.0 &
kubectl port-forward -n monitoring svc/prometheus-server 9090:80 --address=0.0.0.0 &

echo "All resources applied successfully!"


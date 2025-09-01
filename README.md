# WordPress on Kubernetes - Usage Guide

A complete WordPress deployment on Kubernetes with MySQL database and monitoring stack (Prometheus + Grafana).

## Project Structure

```
K8s_finalworkshop/
├── README.md                    # This usage guide
├── create-ecr-secret.sh        # Automated deployment script
├── wordpress/                  # WordPress application manifests
│   ├── namespace.yaml
│   ├── secret.yaml
│   ├── wordpress-pvc.yaml
│   ├── mysql-statefulset.yaml
│   ├── wordpress-deployment.yaml
│   ├── mysql-service.yaml
│   ├── wordpress-service.yaml
│   └── wordpress-ingress.yaml
└── monitoring/                 # Monitoring stack configuration
    ├── grafana_values.yaml
    └── prometheus_values.yaml
```

## Prerequisites

### System Requirements
- AWS EC2 instance (Amazon Linux 2 recommended)
- Minikube installed and running
- kubectl configured
- Helm 3.x installed
- AWS CLI configured with ECR access

### Quick Prerequisites Setup
```bash
# Install Docker
sudo yum update -y
sudo yum install git docker -y
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ec2-user

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Start minikube
minikube start --driver=docker
```

## Usage Instructions

### Method 1: Automated Deployment (Recommended)

1. **Clone the repository:**
```bash
git clone <your-repo-url>
cd K8s_finalworkshop
```

2. **Make the script executable:**
```bash
chmod +x create-ecr-secret.sh
```

3. **Run the automated deployment:**
```bash
./create-ecr-secret.sh
```

The script will:
- Clean up existing resources
- Create namespaces
- Set up ECR authentication
- Deploy WordPress and MySQL
- Install monitoring stack
- Set up port forwarding automatically

### Method 2: Manual Deployment

1. **Setup ECR authentication:**
```bash
kubectl create namespace wordpress
kubectl create secret docker-registry ecr-secret \
  --docker-server=992382545251.dkr.ecr.us-east-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region us-east-1) \
  --namespace=wordpress
```

2. **Deploy WordPress stack:**
```bash
# Deploy in order
kubectl apply -f wordpress/namespace.yaml
kubectl apply -f wordpress/secret.yaml
kubectl apply -f wordpress/wordpress-pvc.yaml
kubectl apply -f wordpress/mysql-statefulset.yaml
kubectl apply -f wordpress/wordpress-deployment.yaml
kubectl apply -f wordpress/mysql-service.yaml
kubectl apply -f wordpress/wordpress-service.yaml
kubectl apply -f wordpress/wordpress-ingress.yaml
```

3. **Install monitoring:**
```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace monitoring
helm install grafana grafana/grafana -n monitoring -f monitoring/grafana_values.yaml
helm install prometheus prometheus-community/prometheus -n monitoring -f monitoring/prometheus_values.yaml
```

4. **Set up port forwarding:**
```bash
kubectl port-forward -n wordpress svc/wordpress-service 8080:80 --address=0.0.0.0 &
kubectl port-forward -n monitoring svc/grafana 3000:80 --address=0.0.0.0 &
kubectl port-forward -n monitoring svc/prometheus-server 9090:80 --address=0.0.0.0 &
```

## Accessing the Applications

### WordPress
- **URL:** `http://your-ec2-ip:8080`
- **Setup:** Follow the WordPress installation wizard
- **Database:** Pre-configured to connect to MySQL automatically

### Grafana Dashboard
- **URL:** `http://your-ec2-ip:3000`
- **Username:** `admin`
- **Password:** `admin`

### Prometheus
- **URL:** `http://your-ec2-ip:9090`
- **Use:** Query metrics and check targets

## Creating Grafana Dashboards

### Step 1: Access Grafana
1. Go to `http://your-ec2-ip:3000`
2. Login with `admin/admin`

### Step 2: Add Prometheus Data Source
1. Go to Configuration → Data Sources
2. Add Prometheus
3. URL: `http://prometheus-server:80`
4. Save & Test

### Step 3: Create Dashboard
1. Click "+" → Create Dashboard
2. Add Panel
3. Use these sample queries:

**WordPress Container Uptime:**
```promql
kube_pod_container_status_running{namespace="wordpress"}
```

**Memory Usage:**
```promql
container_memory_usage_bytes{namespace="wordpress"} / 1024 / 1024
```

**CPU Usage:**
```promql
rate(container_cpu_usage_seconds_total{namespace="wordpress"}[5m]) * 100
```

## Configuration Details

### WordPress Configuration
- **Replicas:** 2 (High Availability)
- **Image:** Custom WordPress from ECR
- **Database:** MySQL 5.7 in StatefulSet
- **Storage:** 2Gi persistent volume for MySQL data
- **Resources:** 256Mi-512Mi memory, 100m-500m CPU

### Database Credentials
All stored in Kubernetes Secret `mysql-secret`:
- Root Password: `password123`
- Database: `wordpress` 
- User: `wordpress`
- Password: `wordpress123`

### Monitoring Stack
- **Grafana:** Admin UI on port 3000
- **Prometheus:** Metrics collection on port 9090
- **Storage:** 1Gi for Grafana, 2Gi for Prometheus

## Troubleshooting

### Common Issues

**Pods not starting:**
```bash
kubectl get pods -n wordpress
kubectl describe pod <pod-name> -n wordpress
kubectl logs <pod-name> -n wordpress
```

**ECR authentication failed:**
```bash
# Recreate ECR secret
kubectl delete secret ecr-secret -n wordpress
kubectl create secret docker-registry ecr-secret \
  --docker-server=992382545251.dkr.ecr.us-east-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region us-east-1) \
  --namespace=wordpress
```

**Services not accessible:**
```bash
# Check if port-forward is running
ps aux | grep "kubectl port-forward"

# Restart port-forward if needed
pkill -f "kubectl port-forward"
kubectl port-forward -n wordpress svc/wordpress-service 8080:80 --address=0.0.0.0 &
```

**Database connection issues:**
```bash
# Check MySQL pod
kubectl logs mysql-0 -n wordpress

# Verify secret
kubectl get secret mysql-secret -n wordpress -o yaml
```

### Verification Commands
```bash
# Check all resources
kubectl get all -n wordpress
kubectl get all -n monitoring

# Check persistent volumes
kubectl get pvc -n wordpress

# Test connectivity
kubectl exec -it <wordpress-pod> -n wordpress -- curl mysql-service:3306
```

## Cleanup

### Remove Everything
```bash
# Delete namespaces (removes all resources)
kubectl delete namespace wordpress monitoring

# Stop port-forwards
pkill -f "kubectl port-forward"

# Remove Helm releases
helm uninstall grafana -n monitoring
helm uninstall prometheus -n monitoring
```

### Selective Cleanup
```bash
# Only WordPress
kubectl delete -f wordpress/

# Only monitoring
helm uninstall grafana prometheus -n monitoring
```

## Customization

### Changing WordPress Configuration
Edit `wordpress/wordpress-deployment.yaml`:
- Modify environment variables
- Adjust resource limits
- Change replica count

### Updating Database Credentials
1. Edit `wordpress/secret.yaml`
2. Base64 encode new passwords:
```bash
echo -n 'newpassword' | base64
```
3. Apply changes:
```bash
kubectl apply -f wordpress/secret.yaml
kubectl rollout restart deployment/wordpress -n wordpress
kubectl rollout restart statefulset/mysql -n wordpress
```

### Scaling WordPress
```bash
# Scale to 3 replicas
kubectl scale deployment wordpress --replicas=3 -n wordpress

# Or edit the YAML file and apply
```

## Architecture Overview

```
Internet → EC2 Instance → Minikube Cluster
                          ├── WordPress Namespace
                          │   ├── WordPress Deployment (2 replicas)
                          │   ├── MySQL StatefulSet (1 replica)
                          │   ├── Services (ClusterIP)
                          │   └── PVC (2Gi storage)
                          └── Monitoring Namespace
                              ├── Grafana (dashboards)
                              ├── Prometheus (metrics)
                              └── PVC (persistent storage)
```

## Security Notes

- Database credentials stored in Kubernetes Secrets
- ECR authentication via service account
- Network policies can be added for additional isolation
- Images should be scanned for vulnerabilities

## Performance Optimization

- Adjust resource requests/limits based on usage
- Consider Redis for WordPress object caching
- Use ReadWriteMany volumes for multi-replica file sharing
- Implement HPA (Horizontal Pod Autoscaler) for automatic scaling

---

**Project Type:** DevOps Workshop - Kubernetes Migration  
**Technology Stack:** Kubernetes, Helm, WordPress, MySQL, Prometheus, Grafana  
**Cloud Provider:** AWS (ECR for container registry)

# Leads — Production Infrastructure (EKS + Private DB)

This directory contains Terraform scripts to deploy the leads application on AWS using a **secure, production-grade architecture** modeled after the OAN infrastructure pattern.

## Architecture

```
VPC: 10.0.0.0/16 (us-west-2)
│
├── us-west-2a
│   ├── PUBLIC  10.0.1.0/24  ── Bastion Host (t2.micro), NAT Gateway
│   └── PRIVATE 10.0.2.0/24  ── EKS Worker Nodes (t3.medium) + DB EC2 (t3.xlarge, 10.0.2.10)
│
└── us-west-2b
    └── PUBLIC  10.0.3.0/24  ── Required by EKS (2 AZ minimum, no resources placed here)
```

### Traffic Flow (Phase 2 - Kong Gateway Integrated)

```
Internet → AWS NLB → NGINX Ingress (nginx) → Kong Proxy Service → Kong Ingress (kong) → leads-app pods
                                                                                            │
                                                                                            ├── PostgreSQL (10.0.2.10:5432, via Service Endpoints)
                                                                                            ├── Elasticsearch (10.0.2.10:9200, via Service Endpoints)
                                                                                            └── Redis (in-cluster pod, ClusterIP)
```

### Security Design

| Layer | Protection |
|---|---|
| **Database** | Private subnet — zero internet exposure. Only reachable from within VPC |
| **SSH** | Bastion Host is the only public SSH entry point |
| **App Traffic** | All external traffic enters through NLB → NGINX Ingress — no ports exposed on EC2 |
| **Admin Tools** | Accessed via SSH tunnel through Bastion (not publicly exposed) |

## Infrastructure Resources

| Resource | Type | Details |
|---|---|---|
| VPC | Network | `10.0.0.0/16`, DNS hostnames enabled |
| Subnets | Network | 2 public + 1 private (3 total) |
| NAT Gateway | Network | Outbound internet for private instances |
| Bastion Host | EC2 `t2.micro` | SSH jump box (public subnet) |
| Database EC2 | EC2 `t3.xlarge` | PostgreSQL 16 + Elasticsearch 8.13 (private subnet) |
| EKS Cluster | Kubernetes | `leads-cluster`, K8s v1.31 |
| EKS Node Group | EC2 `t3.medium` | 1 node (scales to 3) |
| NGINX Ingress | Helm | v4.10.1, provisions AWS NLB |
| Kong API Gateway | Helm | v2.38.0, DB-less Mode (ClusterIP behind NGINX) |
| Security Groups | Firewall | 4 SGs — Bastion, Private, EKS Cluster, EKS Node |

### Kubernetes Workloads

| Manifest | Resource | Purpose / Image |
|---|---|---|
| `02-redis.yaml` | Deployment + ClusterIP | `redis:7-alpine` |
| `03-db-external.yaml.tpl` | Headless Service + Endpoints | Securely routes to private DB EC2 (10.0.2.10) |
| `04-leads-app.yaml.tpl` | Deployment (2 replicas) + ClusterIP | ECR `leads-app` |
| `05-nginx-to-kong.yaml` | Ingress (nginx class) | Routes all external traffic from NGINX to Kong |
| `06-kong-to-app.yaml` | Ingress (kong class) + KongPlugin | Routes from Kong to App and applies rate limiting |

## Prerequisites

1. **Terraform** >= 1.0
2. **AWS CLI** configured with appropriate credentials
3. **kubectl** installed
4. **Helm** installed
5. **Existing AWS Key Pair** named `batman` in `us-west-2`
6. **Existing IAM Instance Profile** named `EC2-ECR-Read-Role`
7. **ECR Repository** with the leads application image

## Usage

### 1. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your actual credentials
```

### 2. Create Kubernetes Secrets

```bash
cp k8/00-secrets.yaml.example k8/00-secrets.yaml
# Edit k8/00-secrets.yaml with your actual credentials
```

### 3. Initialize & Apply

```bash
terraform init
terraform plan
terraform apply
```

### 4. Connect to the Cluster

After `terraform apply` completes, update your kubeconfig:

```bash
aws eks update-kubeconfig --name leads-cluster --region us-west-2
```

### 5. Get the Application URL

```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## Accessing Admin Tools & Databases

For security, admin tools and databases are completely isolated. Access them using SSH tunnels (through the Bastion) or Kubernetes port-forwarding:

### 🐘 1. PostgreSQL (via pgAdmin)
1. Open a terminal on your laptop and create the SSH tunnel:
   ```bash
   ssh -i <YOUR_KEY>.pem -L 5432:10.0.2.10:5432 ubuntu@<BASTION_PUBLIC_IP>
   ```
2. Leave this terminal open.
3. In **pgAdmin**, add a new server connection:
   * **Host:** `localhost`
   * **Port:** `5432`
   * **Username:** `postgres_user` (or the one defined in your `terraform.tfvars`)
   * **Password:** Your database password

### 🔍 2. Elasticsearch (via Elasticvue / Kibana)
1. Open a terminal on your laptop and create the SSH tunnel:
   ```bash
   ssh -i <YOUR_KEY>.pem -L 9200:10.0.2.10:9200 ubuntu@<BASTION_PUBLIC_IP>
   ```
2. Leave this terminal open.
3. Connect your browser extension (**Elasticvue** or local Kibana) to:
   * **URI:** `http://localhost:9200`

### 🔴 3. Redis (via RedisInsight / GUI)
Since Redis runs directly inside the EKS cluster, you use standard Kubernetes port-forwarding to connect your GUI or CLI tools:
1. Port-forward the Redis service to your local machine:
   ```bash
   kubectl port-forward svc/redis 6379:6379 -n default
   ```
2. Leave this terminal open.
3. Connect your Redis GUI (e.g., **RedisInsight** or `redis-cli`) to:
   * **Host:** `localhost`
   * **Port:** `6379`

---

## 🚀 Testing the API and Kong Rate Limiting

### Hitting the API
After the NLB DNS propagates, you can hit the API through NGINX and Kong on **HTTP Port 80** without appending any port numbers:
```bash
# Find your Public NLB Hostname:
kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```
Use this hostname in Postman or curl:
* **Search API:** `GET http://<NLB_HOSTNAME>/leads/v1/search`
* **Initiate Lead API:** `POST http://<NLB_HOSTNAME>/leads/v1/initiate`

### Verifying Kong's Rate Limiting
We applied a `rate-limiting` policy restricting requests to the `/leads/v1/initiate` endpoint to **5 requests per minute per IP address**.

1. Send a request in Postman or curl to `/leads/v1/initiate`.
2. Check the response **Headers**. You should see these headers injected by Kong:
   ```http
   X-RateLimit-Limit-Minute: 5
   X-RateLimit-Remaining-Minute: 4
   ```
3. Spam the request 5 more times quickly.
4. On the 6th attempt, Kong will block the request at the gateway level. You will receive an **HTTP 429 Too Many Requests** status with this body:
   ```json
   {
     "message": "API rate limit exceeded"
   }
   ```

---

## Cleanup

```bash
terraform destroy
```

> [!WARNING]
> This will destroy ALL infrastructure including the database volumes. Back up any data before running destroy.

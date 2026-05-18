# leads AWS Infrastructure Deployment

This directory contains Terraform scripts to deploy a secure, consolidated, three-tier AWS infrastructure for the leads application. 

It isolates the database and application services inside a **Private Subnet**, while routing public traffic securely through an **Nginx Reverse Proxy** and administrative shell access via a **Bastion Host** located in the **Public Subnet**.

---

## Architecture

*   **VPC**: A dedicated Virtual Private Cloud (`10.0.0.0/16` by default) with isolated public and private subnets.
*   **Public Subnet (`10.0.1.0/24`)**:
    *   **Nginx Reverse Proxy** (`t2.micro`): Attached to an Elastic IP. Serves as the single public gateway, directing API requests and admin UI traffic to the private backend.
    *   **Bastion Host** (`t2.micro`): Provides a secure entry point for administrators to access the private backend via SSH and port-forwarding.
    *   **NAT Gateway**: Allows services in the private subnet to securely pull external dependencies and ECR images without exposing themselves to the public internet.
*   **Private Subnet (`10.0.2.0/24`)**:
    *   **Main Consolidated Server** (`t3.xlarge`): A single instance with a static private IP (`10.0.2.10`) that runs all core application services and data stores via Docker.
*   **IAM Profile**: The main instance uses the `EC2-ECR-Read-Role` profile to authenticate with Amazon ECR and pull application Docker images securely.

### Service Stack

The private backend instance automatically runs the following containerized services:
*   **PostgreSQL 16**: Primary database.
*   **Redis 7**: Caching and session layer.
*   **Elasticsearch 8.13.0**: Search and indexing engine.
*   **leads Application**: Core Spring Boot application.
*   **pgAdmin**: Database management UI.
*   **Redis Commander**: Redis key/value management UI.
*   **Kibana**: Elasticsearch analytics dashboard.

---

## Prerequisites

1.  **Terraform**: Installed on your local machine.
2.  **AWS CLI**: Installed and configured with appropriate access credentials.
3.  **AWS Key Name**: Provide a name for the key pair to be generated (`key_name` variable).
4.  **Amazon ECR Repository**: A repository containing the built leads application Docker image.
5.  **IAM Role**: An IAM role named `EC2-ECR-Read-Role` must exist in your AWS account with ECR read permissions.

---

## Usage

1.  **Initialize Terraform** and fetch updates:
    ```bash
    terraform init -upgrade
    ```

2.  **Configure Variables**:
    *   Copy the example variables file:
        ```bash
        cp terraform.tfvars.example terraform.tfvars
        ```
    *   Open `terraform.tfvars` and fill in:
        *   `key_name`: The name to assign to your generated key pair.
        *   `docker_image`: The full ECR URI of your Leads application image.
        *   Database and Elasticsearch passwords.

3.  **Review the Deployment Plan**:
    ```bash
    terraform plan
    ```

4.  **Apply the Infrastructure**:
    ```bash
    terraform apply
    ```
    *Type `yes` when prompted to confirm.*

---

## Post-Deployment & Access Guide

After a successful deployment, Terraform will output the public IPs for Nginx and the Bastion host, as well as pre-built commands.

### 1. Hitting the Leads API
The application is hosted securely in the private subnet and exposed to the public internet solely through the Nginx reverse proxy on port 80:

*   **API Endpoint**: `http://<nginx_public_ip>/leads/`
*   **Example (cURL)**:
    ```bash
    curl http://<nginx_public_ip>/leads/v1/search
    ```

### 2. Accessing Administrative Tools (HTTP)
You can access web administration panels directly via Nginx subfolders (mapped securely on port 80). 

| Tool | Nginx Public URL | Default Credentials |
| :--- | :--- | :--- |
| **pgAdmin** | `http://<nginx_public_ip>/pgadmin/` | `admin@admin.com` / `admin` |
| **Redis Commander** | `http://<nginx_public_ip>/redis/` | No authentication |
| **Kibana** | `http://<nginx_public_ip>/kibana/` | No authentication |
| **Elasticsearch** | `http://<nginx_public_ip>/elasticsearch/` | Direct access for **Elasticvue** extension |

---

### 3. Secure Administration via SSH Tunneling (Recommended)
For production or highly restricted security, you can block the public Nginx routes for admin panels and use SSH port forwarding through the Bastion host instead. 

To open a secure tunnel, run the corresponding command in a terminal. Keep the terminal open while accessing the service locally.

#### A. Elasticvue / Elasticsearch
To connect the **Elasticvue** browser extension to your Elasticsearch instance securely:
```bash
ssh -i leads-key.pem -N -L 9200:10.0.2.10:9200 -J ubuntu@<bastion_public_ip> ubuntu@10.0.2.10
```
*Now open Elasticvue and connect to `http://localhost:9200`.*

#### B. pgAdmin
To access the database manager locally:
```bash
ssh -i leads-key.pem -N -L 5050:10.0.2.10:5050 -J ubuntu@<bastion_public_ip> ubuntu@10.0.2.10
```
*Open your browser and navigate to `http://localhost:5050`.*

#### C. Redis Commander
To manage Redis keys locally:
```bash
ssh -i leads-key.pem -N -L 8081:10.0.2.10:8081 -J ubuntu@<bastion_public_ip> ubuntu@10.0.2.10
```
*Open your browser and navigate to `http://localhost:8081`.*

#### D. Kibana
To view logs and search dashboards:
```bash
ssh -i leads-key.pem -N -L 5601:10.0.2.10:5601 -J ubuntu@<bastion_public_ip> ubuntu@10.0.2.10
```
*Open your browser and navigate to `http://localhost:5601`.*

---

## Direct Console SSH Access

To access the console of the Bastion host or the private backend server directly:

*   **Bastion Console**:
    ```bash
    ssh -i leads-key.pem ubuntu@<bastion_public_ip>
    ```
*   **Private Backend Console** (Proxied via Bastion):
    ```bash
    ssh -i leads-key.pem -J ubuntu@<bastion_public_ip> ubuntu@10.0.2.10
    ```

---

## Cleanup

To tear down the infrastructure and stop incurring AWS charges:
```bash
terraform destroy
```
*Type `yes` when prompted to confirm.*

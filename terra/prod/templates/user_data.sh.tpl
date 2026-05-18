#!/bin/bash
# ==================================
# Leads Database EC2 Bootstrap Script
# ==================================
# This script runs on the private DB EC2 instance.
# It installs Docker and starts:
#   1. PostgreSQL 16 (port 5432)
#   2. Elasticsearch 8.13 (port 9200)

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "========================================="
echo "Starting Leads DB setup..."
echo "========================================="

# ----------------------------------
# 1. Install Docker
# ----------------------------------
echo "[1/3] Installing Docker..."
apt-get update -y
apt-get install -y docker.io
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu

# ----------------------------------
# 2. PostgreSQL 16 (port 5432)
# ----------------------------------
echo "[2/3] Setting up PostgreSQL 16..."

echo "Pulling postgres:16 image (with retries)..."
n=0
until [ "$n" -ge 5 ]; do
  docker pull postgres:16 && break
  n=$((n+1))
  echo "  Pull failed. Retrying in 10 seconds... (attempt $n/5)"
  sleep 10
done

echo "Starting PostgreSQL container on port 5432..."
docker run -d \
  --name leads-postgres \
  --restart unless-stopped \
  -e POSTGRES_DB=${db_name} \
  -e POSTGRES_USER=${db_username} \
  -e POSTGRES_PASSWORD=${db_password} \
  -p 5432:5432 \
  -v pgdata:/var/lib/postgresql/data \
  postgres:16

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
for i in $(seq 1 30); do
  docker exec leads-postgres pg_isready -U ${db_username} -d ${db_name} && break
  echo "  Waiting... ($i/30)"
  sleep 2
done

# ----------------------------------
# 3. Elasticsearch 8.13 (port 9200)
# ----------------------------------
echo "[3/3] Setting up Elasticsearch 8.13..."

# Required kernel setting for Elasticsearch
sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" >> /etc/sysctl.conf

echo "Pulling elasticsearch:8.13.0 image (with retries)..."
n=0
until [ "$n" -ge 5 ]; do
  docker pull elasticsearch:8.13.0 && break
  n=$((n+1))
  echo "  Pull failed. Retrying in 10 seconds... (attempt $n/5)"
  sleep 10
done

echo "Starting Elasticsearch container on port 9200..."
docker run -d \
  --name leads-elasticsearch \
  --restart unless-stopped \
  -e "discovery.type=single-node" \
  -e "xpack.security.enabled=false" \
  -e "ES_JAVA_OPTS=-Xms1g -Xmx1g" \
  -p 9200:9200 \
  -p 9300:9300 \
  -v esdata:/usr/share/elasticsearch/data \
  elasticsearch:8.13.0

echo "========================================="
echo "Leads DB setup complete!"
echo "  PostgreSQL: port 5432"
echo "  Elasticsearch: port 9200"
echo "========================================="

#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "========================================="
echo "Starting Leads Nginx Proxy Setup"
echo "========================================="

# 1. Install Nginx
echo "Installing Nginx..."
sudo apt-get update -y
sudo apt-get install -y nginx

# 2. Configure Nginx Proxy
# All services are on the same backend IP, differentiated by port
echo "Configuring Nginx..."

cat > /etc/nginx/sites-available/default <<EOF
server {
    listen 80;
    server_name _;

    # Health Check
    location /health {
        return 200 "OK\n";
        add_header Content-Type text/plain;
    }

    # Leads Spring Boot App (Root API)
    location /leads/ {
        proxy_pass http://${backend_ip}:${app_port}/leads/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 120;
        proxy_send_timeout 120;
    }

    # pgAdmin
    location /pgadmin/ {
        proxy_pass http://${backend_ip}:${pgadmin_port}/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Redis Commander
    location /redis/ {
        proxy_pass http://${backend_ip}:${redis_commander_port}/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Kibana
    location /kibana/ {
        proxy_pass http://${backend_ip}:${kibana_port}/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# 3. Reload Nginx
echo "Starting Nginx..."
sudo systemctl restart nginx
sudo systemctl enable nginx

echo "========================================="
echo "Nginx Proxy Setup Complete"
echo "Backend IP: ${backend_ip}"
echo "========================================="

#!/bin/bash
set -euo pipefail

LOG_FILE="/var/log/cloud-init.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== Starting TechEazy DevOps deployment: $(date) ==="

# Get instance metadata
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
INSTANCE_INDEX="${instance_id_token}"

echo "Instance ID: $INSTANCE_ID"
echo "Instance Index: $INSTANCE_INDEX"

# Store instance index for auto-update script
echo "$INSTANCE_INDEX" > /opt/app/.instance_index

# Update PATH
export PATH=$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Update system
apt-get update -y
apt-get upgrade -y

# Install essential packages
apt-get install -y \
    curl wget git unzip software-properties-common apt-transport-https \
    ca-certificates gnupg lsb-release build-essential net-tools \
    awscli jq

# Install OpenJDK 21
apt-get install -y openjdk-21-jdk
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export PATH=$PATH:$JAVA_HOME/bin

if ! grep -q "JAVA_HOME" /etc/environment; then
    echo 'export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64' >> /etc/environment
    echo 'export PATH=$PATH:$JAVA_HOME/bin' >> /etc/environment
fi

# Install Nginx
apt-get install -y nginx

# Create application directories
mkdir -p /opt/app/current
mkdir -p /opt/app/backups
mkdir -p /opt/app/temp
mkdir -p /opt/app/scripts
mkdir -p /var/log/app

chown -R ubuntu:ubuntu /opt/app
chown -R ubuntu:ubuntu /var/log/app

# Download auto-update script from user data template
cat > /opt/app/scripts/auto-update.sh << 'AUTOUPDATE_SCRIPT'
${auto_update_script_content}
AUTOUPDATE_SCRIPT

# Substitute variables in auto-update script
sed -i "s/\$${s3_jar_bucket}/${s3_jar_bucket}/g" /opt/app/scripts/auto-update.sh
sed -i "s/\$${s3_logs_bucket}/${s3_logs_bucket}/g" /opt/app/scripts/auto-update.sh
sed -i "s/\$${jar_file_name}/${jar_file_name}/g" /opt/app/scripts/auto-update.sh

chmod +x /opt/app/scripts/auto-update.sh
chown ubuntu:ubuntu /opt/app/scripts/auto-update.sh

# Initial JAR download from S3
echo "Downloading initial JAR from S3..."
cd /opt/app/current

if aws s3 cp "s3://${s3_jar_bucket}/${jar_file_name}" "/opt/app/current/${jar_file_name}"; then
    echo "JAR downloaded successfully"
    chmod +x "/opt/app/current/${jar_file_name}"
    chown ubuntu:ubuntu "/opt/app/current/${jar_file_name}"
    
    # Set initial version
    INITIAL_ETAG=$(aws s3api head-object --bucket "${s3_jar_bucket}" --key "${jar_file_name}" --query 'ETag' --output text | tr -d '"')
    echo "$INITIAL_ETAG" > /opt/app/.current_version
else
    echo "WARNING: Could not download JAR from S3. Building from source as fallback..."
    
    # Fallback: Build from GitHub
    cd /opt/app
    git clone "${github_repo_url}" build
    cd build
    
    # Install Maven
    apt-get install -y maven
    
    # Build application
    sudo -u ubuntu -E JAVA_HOME=$JAVA_HOME mvn clean package -DskipTests
    
    # Copy JAR to current directory
    cp target/${jar_file_name} /opt/app/current/
    chmod +x /opt/app/current/${jar_file_name}
    chown ubuntu:ubuntu /opt/app/current/${jar_file_name}
    
    # Set version as "built-from-source"
    echo "built-from-source" > /opt/app/.current_version
fi

# Create systemd service for application
cat > /etc/systemd/system/app.service << EOF
[Unit]
Description=TechEazy DevOps Spring Boot Application
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/opt/app/current
Environment=JAVA_HOME=$JAVA_HOME
Environment=PATH=$JAVA_HOME/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=SPRING_PROFILES_ACTIVE=production
Environment=INSTANCE_ID=$INSTANCE_ID
Environment=INSTANCE_INDEX=$INSTANCE_INDEX
ExecStart=$JAVA_HOME/bin/java -Xms256m -Xmx512m -jar /opt/app/current/${jar_file_name}
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=techeazy-app

# Graceful shutdown
TimeoutStopSec=30
KillMode=mixed

[Install]
WantedBy=multi-user.target
EOF

# Create systemd timer for auto-update (every 5 minutes)
cat > /etc/systemd/system/app-auto-update.timer << EOF
[Unit]
Description=Auto-update timer for TechEazy application
Requires=app-auto-update.service

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min
Unit=app-auto-update.service

[Install]
WantedBy=timers.target
EOF

# Create systemd service for auto-update
cat > /etc/systemd/system/app-auto-update.service << EOF
[Unit]
Description=Auto-update service for TechEazy application
After=network.target

[Service]
Type=oneshot
User=root
ExecStart=/opt/app/scripts/auto-update.sh
StandardOutput=journal
StandardError=journal
SyslogIdentifier=app-auto-update

[Install]
WantedBy=multi-user.target
EOF

# Create shutdown script to upload logs before termination
cat > /opt/app/scripts/shutdown-upload-logs.sh << EOF
#!/bin/bash
# Upload logs to S3 on shutdown

S3_LOGS_BUCKET="${s3_logs_bucket}"
INSTANCE_INDEX="$INSTANCE_INDEX"
TIMESTAMP=\$(date +%Y%m%d_%H%M%S)
LOG_PREFIX="instance-\$INSTANCE_INDEX"

# Upload all logs
aws s3 cp /var/log/app/application.log \\
    "s3://\$S3_LOGS_BUCKET/\$LOG_PREFIX/shutdown-application-\$TIMESTAMP.log" \\
    --quiet 2>/dev/null || true

aws s3 cp /var/log/app/auto-update.log \\
    "s3://\$S3_LOGS_BUCKET/\$LOG_PREFIX/shutdown-autoupdate-\$TIMESTAMP.log" \\
    --quiet 2>/dev/null || true

aws s3 cp /var/log/cloud-init.log \\
    "s3://\$S3_LOGS_BUCKET/\$LOG_PREFIX/shutdown-cloudinit-\$TIMESTAMP.log" \\
    --quiet 2>/dev/null || true

echo "Logs uploaded to S3 on shutdown" | logger -t shutdown-upload
EOF

chmod +x /opt/app/scripts/shutdown-upload-logs.sh

# Create systemd service for shutdown log upload
cat > /etc/systemd/system/shutdown-upload-logs.service << EOF
[Unit]
Description=Upload logs to S3 on shutdown
DefaultDependencies=no
Before=shutdown.target reboot.target halt.target

[Service]
Type=oneshot
ExecStart=/opt/app/scripts/shutdown-upload-logs.sh
TimeoutStartSec=60

[Install]
WantedBy=halt.target reboot.target shutdown.target
EOF

# Configure Nginx as reverse proxy
cat > /etc/nginx/sites-available/app << EOF
server {
    listen 80;
    server_name _;

    # Add instance identifier header for load balancer verification
    add_header X-Instance-ID "$INSTANCE_ID" always;
    add_header X-Instance-Index "$INSTANCE_INDEX" always;

    location / {
        proxy_pass http://localhost:80;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Health check endpoint
    location /actuator/health {
        proxy_pass http://localhost:80/actuator/health;
        access_log off;
    }
}
EOF

ln -sf /etc/nginx/sites-available/app /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

nginx -t && systemctl restart nginx
systemctl enable nginx

# Enable and start all services
systemctl daemon-reload

# Start application
systemctl enable app
systemctl start app

# Enable auto-update timer
systemctl enable app-auto-update.timer
systemctl start app-auto-update.timer

# Enable shutdown log upload
systemctl enable shutdown-upload-logs.service

# Wait for application to start
echo "Waiting for application to start..."
sleep 15

# Check application status
systemctl status app --no-pager || true

# Verify health
if curl -f -s http://localhost:80/actuator/health > /dev/null; then
    echo "✅ Application health check passed"
else
    echo "⚠️  Application health check failed - may need more time to start"
fi

echo "=== Deployment completed successfully: $(date) ==="
echo "Instance Index: $INSTANCE_INDEX"
echo "Auto-update timer status:"
systemctl status app-auto-update.timer --no-pager || true

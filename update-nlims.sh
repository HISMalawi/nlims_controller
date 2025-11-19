#!/bin/bash

# SETTINGS : Set variables
NLIMS_CONTROLLER_DIR="/var/www/nlims_controller" 
EMR_API_DIR="/var/www/EMR-API" 
MLAB_API_DIR="/var/www/mlab_api" 
SERVER_IP=$(hostname -I | awk '{print $1}')
CHSU_IP="10.44.0.46" # CHSU server IP address
MYSQL_USERNAME="root" #  Replace with the actual mysql-username
MYSQL_PASSWORD="password" # replace with the actual mysql-password
MYSQL_PORT="3306" # the servers mysql-port
# Auto-generate secure passwords for IBLIS and EMR
IBLIS_PASSWORD=$(openssl rand -base64 30 | tr -dc 'a-zA-Z0-9' | head -c 20)
EMR_PASSWORD=$(openssl rand -base64 30 | tr -dc 'a-zA-Z0-9' | head -c 20)
# Default credentials for NLIMS
LOCAL_PASSWORD="lab@daemon"  # Replace with the actual local password
DEFAULT_MASTER_NLIMS_PASSWORD="knock_knock" # Replace with the actual default master NLIMS password
NLIMS_SIDEKIQ_SERVICE_FILE="$NLIMS_CONTROLLER_DIR/nlims-sidekiq.service" # sidekiq service 
 
# STEP1 : Perform checks
# Get MySQL port and database name from database.yml
echo "🔍 Checking MySQL version and credentials..."
if [ -f "$NLIMS_CONTROLLER_DIR/config/database.yml" ]; then
  MYSQL_USERNAME=$(ruby -ryaml -e "puts YAML::load_file('$NLIMS_CONTROLLER_DIR/config/database.yml',aliases: true)['development']['username']")
  MYSQL_PASSWORD=$(ruby -ryaml -e "puts YAML::load_file('$NLIMS_CONTROLLER_DIR/config/database.yml',aliases: true)['development']['password']")
  MYSQL_PORT=$(ruby -ryaml -e "puts YAML::load_file('$NLIMS_CONTROLLER_DIR/config/database.yml',aliases: true)['development']['port']")
  DB_NAME=$(ruby -ryaml -e "puts YAML::load_file('$NLIMS_CONTROLLER_DIR/config/database.yml',aliases: true)['development']['database']")
else
 echo "⚠️  Warning: database.yml not found in $NLIMS_CONTROLLER_DIR/config, using default MySQL credentials"
  MYSQL_USERNAME="root"
  MYSQL_PASSWORD="password"
  MYSQL_PORT="3306"
  DB_NAME="lims_db"
fi
mysql -u "$MYSQL_USERNAME" -p"$MYSQL_PASSWORD" -P"$MYSQL_PORT" -h "127.0.0.1" -e "SELECT version();" 2>/dev/null | grep -q "8.0" || { 
  echo "⚠️  Warning: MySQL 8 on port 3306 is required. You appear to be using a different version or port or credentials are incorrect."
  echo ""
  echo "🔄 Migration Steps:"
  echo "  1️⃣  Dump your data: mysqldump -u root -p -h 127.0.0.1 -P $MYSQL_PORT $DB_NAME > ${DB_NAME}_dump.sql"
  echo "  2️⃣  Import to MySQL 8: mysql -u root -p -h 127.0.0.1 -P 3306 $DB_NAME < ${DB_NAME}_dump.sql"
  echo "  3️⃣  Update $NLIMS_CONTROLLER_DIR/config/database.yml to use port: 3306 using vim or nano"
  echo "  4️⃣  Rerun this script."
  echo ""
  exit 1;
}
# Check Redis version (Simplified - assumes redis-server is running)
echo "🔍 Checking Redis version..."
redis-cli ping >/dev/null 2>&1 || { 
  echo "❌ Error: Redis is not running or not installed. Please install and start Redis 7+."
  echo "📚 Installation guide: https://redis.io/docs/latest/operate/oss_and_stack/install/archive/install-redis/install-redis-on-linux/"
  exit 1; 
}

echo "🔍 Checking network connectivity to CHSU... Pinging $CHSU_IP"
ping -c 3 $CHSU_IP >/dev/null 2>&1 || { echo "❌ Error: Could not ping CHSU ($CHSU_IP). Please check network connectivity."; exit 1; }

# print generated passwords
echo "🔐 Generated IBLIS password: $IBLIS_PASSWORD"
echo "🔐 Generated EMR password: $EMR_PASSWORD"

# STEP 2 : NLIMS Installation
cd "$NLIMS_CONTROLLER_DIR"

# git fetch --tags

# Minimum required version
REQUIRED_VERSION="v3.0.3"

# Get current tag (if checked out on a tag)
CURRENT_TAG=$(git describe --tags --exact-match 2>/dev/null)
# Get latest tag (semver-sorted)
LATEST_TAG=$(git tag --sort=-v:refname | head -n 1)
# Determine actual version to use
if [ -z "$CURRENT_TAG" ]; then
  echo "Not on a tag — using latest tag: $LATEST_TAG"
  CURRENT_TAG="$LATEST_TAG"
else
  echo "Currently on tag: $CURRENT_TAG"
  # Compare CURRENT_TAG with REQUIRED_VERSION
  if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$CURRENT_TAG" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    echo "Current tag ($CURRENT_TAG) is newer than or equal to $REQUIRED_VERSION"
  else
    echo "Current tag ($CURRENT_TAG) is older than $REQUIRED_VERSION — using latest tag: $LATEST_TAG"
    CURRENT_TAG="$LATEST_TAG"
  fi
fi

# Set NLIMS_VERSION to the resolved tag
NLIMS_VERSION="$CURRENT_TAG"
# NLIMS_VERSION="$REQUIRED_VERSION"
echo "NLIMS_VERSION set to: $NLIMS_VERSION"
echo "Checking out $NLIMS_VERSION"
git checkout "$NLIMS_VERSION" -f

rm Gemfile.lock

# STEP 3: Update metadata

./bin/update_metadata.sh development
./bin/add_cronjob.sh

# Configure Apps (Automated responses)
printf "$CHSU_IP\n3010\n127.0.0.1\n3002\nno\nyes\n$IBLIS_PASSWORD\n$LOCAL_PASSWORD\n$DEFAULT_MASTER_NLIMS_PASSWORD\n$LOCAL_PASSWORD\n$EMR_PASSWORD\nyes\n" | ./configure_apps.sh

# Step 4 : Update EMR-API Configuration
EMR_USERNAME=$(grep "emr" users_credentials.txt | awk -F'Username: ' '{print $2}' | awk -F', ' '{print $1}')
EMR_PASSWORD=$(grep "emr" users_credentials.txt | awk -F'Password: ' '{print $2}' | awk -F', ' '{print $1}')

if [[ -n "$EMR_USERNAME" && -n "$EMR_PASSWORD" ]]; then
  # Ensure lims_api: rest is uncommented - check for both "#lims_api:" and "# lims_api:" patterns
  if grep -q "^#\s*lims_api:" "$EMR_API_DIR/config/application.yml"; then
    # If commented, uncomment it (handles both "#lims_api" and "# lims_api")
    sed -i 's/^#\s*lims_api:/lims_api:/' "$EMR_API_DIR/config/application.yml"
  elif ! grep -q "^lims_api:" "$EMR_API_DIR/config/application.yml"; then
    # If not present, add it
    echo "lims_api: rest" >> "$EMR_API_DIR/config/application.yml"
  fi
  
  # Update username and password
  sed -i "s/^lims_username: .*$/lims_username: $EMR_USERNAME/" "$EMR_API_DIR/config/application.yml"
  sed -i "s/^lims_password: .*$/lims_password: $EMR_PASSWORD/" "$EMR_API_DIR/config/application.yml"
  
  echo "✅ EMR API configuration updated successfully"
else
  echo "❌ Error: Could not find EMR credentials in users_credentials.txt"
fi

# Step 5 : Update MLAB-API Configuration
MLAB_USERNAME=$(grep "iblis" users_credentials.txt | awk -F'Username: ' '{print $2}' | awk -F', ' '{print $1}')
MLAB_PASSWORD=$(grep "iblis" users_credentials.txt | awk -F'Password: ' '{print $2}' | awk -F', ' '{print $1}')

if [[ -n "$MLAB_USERNAME" && -n "$MLAB_PASSWORD" ]]; then
  awk -v u="$MLAB_USERNAME" -v p="$MLAB_PASSWORD" '
    BEGIN {inside=0}
    /^nlims_service:/ {inside=1} 
    /^[a-zA-Z_]+:/ && inside==1 && !/^nlims_service:/ {inside=0}
    inside && /username:/ {sub(/username: .*/, "username: " u)}
    inside && /password:/ {sub(/password: .*/, "password: " p)}
    {print}
  ' "$MLAB_API_DIR/config/application.yml" > "$MLAB_API_DIR/config/application.yml.tmp" \
  && mv "$MLAB_API_DIR/config/application.yml.tmp" "$MLAB_API_DIR/config/application.yml"
else
  echo "Error: Could not find IBLIS credentials in users_credentials.txt"
fi

CURRENT_USER=$(whoami)

# Step 6 : NLIMS Service Update
NLIMS_SERVICE_FILE="/etc/systemd/system/nlims-api.service"
ALT_NLIMS_SERVICE_FILE="/etc/systemd/system/nlims.service"

if [[ ! -f "$NLIMS_SERVICE_FILE" && -f "$ALT_NLIMS_SERVICE_FILE" ]]; then
  NLIMS_SERVICE_FILE="$ALT_NLIMS_SERVICE_FILE"
fi

# NLIMS_EXEC_START_PRE="ExecStartPre=/bin/bash -lc 'rm -f tmp/pids/server.pid && (fuser -k 3009/tcp || true)'"
# if ! grep -qF "ExecStartPre=" "$NLIMS_SERVICE_FILE"; then
#   sudo sed -i "/ExecStart=/i $NLIMS_EXEC_START_PRE" "$NLIMS_SERVICE_FILE"
#   sudo systemctl daemon-reload
# else
#   echo "ExecStartPre already exists. No changes made."
# fi

# # Extract service name from the file path
# echo "Restarting $NLIMS_SERVICE_FILE"
# SERVICE_NAME=$(basename "$NLIMS_SERVICE_FILE" .service)
# sudo systemctl restart "$SERVICE_NAME.service"
# sudo systemctl enable "$SERVICE_NAME.service"
# # Check if service is active and display status
# if systemctl is-active --quiet "$SERVICE_NAME.service"; then
#   echo "✅ $SERVICE_NAME service is running successfully"
# else
#   echo "❌ $SERVICE_NAME service failed to start. Check logs with: journalctl -u $SERVICE_NAME.service"
# fi

cat <<EOF | sudo tee "$NLIMS_SERVICE_FILE" > /dev/null
[Unit]
Description=nlims Puma Server
After=network.target

[Service]
Type=simple
User=$CURRENT_USER
WorkingDirectory=$NLIMS_CONTROLLER_DIR
Environment=RBENV_ROOT=/home/$CURRENT_USER/.rbenv
Environment=PATH=/home/$CURRENT_USER/.rbenv/shims:/home/$CURRENT_USER/.rbenv/bin:/usr/local/bin:/usr/bin:/bin
ExecStartPre=/bin/bash -lc 'rm -f tmp/pids/server.pid && rm -f tmp/nlims_account_creating_token.json && (fuser -k 3009/tcp || true)'
ExecStart=/bin/bash -lc 'cd $NLIMS_CONTROLLER_DIR && bundle exec puma -C config/puma.rb'
RestartSec=5
Restart=on-failure
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

# Extract service name from the file path
echo "Restarting $NLIMS_SERVICE_FILE"
SERVICE_NAME=$(basename "$NLIMS_SERVICE_FILE" .service)
sudo systemctl daemon-reload
sudo systemctl restart "$SERVICE_NAME.service"
sudo systemctl enable "$SERVICE_NAME.service"
# Check if service is active and display status
if systemctl is-active --quiet "$SERVICE_NAME.service"; then
  echo "✅ $SERVICE_NAME service is running successfully"
else
  echo "❌ $SERVICE_NAME service failed to start. Check logs with: journalctl -u $SERVICE_NAME.service"
fi

# Step 7 : NLIMS-Sidekiq Service Setup
# Update the user in the service file to match the current user
sed -i "s/User=emr-user/User=$CURRENT_USER/" "$NLIMS_SIDEKIQ_SERVICE_FILE"
sed -i "s|ExecStart=.*|ExecStart=/bin/bash -lc 'exec $(which bundle) exec sidekiq -e development'|" "$NLIMS_SIDEKIQ_SERVICE_FILE"

sudo cp "$NLIMS_SIDEKIQ_SERVICE_FILE" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable nlims-sidekiq.service
sudo systemctl start nlims-sidekiq.service

# Check if service is active and display status
if systemctl is-active --quiet "nlims-sidekiq.service"; then
  echo "✅ nlims-sidekiq service is running successfully"
else
  echo "❌ nlims-sidekiq service failed to start. Check logs with: journalctl -u nlims-sidekiq.service"
fi

 
 # Rake Task  
cd "$NLIMS_CONTROLLER_DIR"
nohup bundle exec rake master_nlims:register_order_source > log/register_order_source.log 2>&1 &
cd "$NLIMS_CONTROLLER_DIR"
nohup bundle exec rake tracking_number_loggers:load_data > log/tracking_number_loggers.log 2>&1 &

cd "$NLIMS_CONTROLLER_DIR"

# DONE WITH THE SCRIPT
echo "✅ NLIMS  completed successfully"

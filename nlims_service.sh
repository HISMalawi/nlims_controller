# Step 6 : Update NLIMS Service with Custom Configuration

NLIMS_SERVICE_FILE="/etc/systemd/system/nlims-api.service"
ALT_NLIMS_SERVICE_FILE="/etc/systemd/system/nlims.service"

if [[ ! -f "$NLIMS_SERVICE_FILE" && -f "$ALT_NLIMS_SERVICE_FILE" ]]; then
  NLIMS_SERVICE_FILE="$ALT_NLIMS_SERVICE_FILE"
fi

CURRENT_USER=$(whoami)
NLIMS_CONTROLLER_DIR="/var/www/nlims_controller"

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
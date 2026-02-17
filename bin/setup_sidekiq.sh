#!/bin/bash

#############################################################
# Sidekiq Setup and Deployment Script for NLIMS Controller
#############################################################

set -e  # Exit on error

RAILS_ROOT="/var/www/nlims_controller"
RAILS_ENV="production"
SERVICE_NAME="nlims-sidekiq"
SERVICE_FILE="config/nlims-sidekiq.service"
SYSTEMD_PATH="/etc/systemd/system/${SERVICE_NAME}.service"

echo "========================================="
echo "NLIMS Sidekiq Setup Script"
echo "========================================="
echo ""

# Function to print colored output
print_status() {
    echo -e "\e[1;32m[✓]\e[0m $1"
}

print_error() {
    echo -e "\e[1;31m[✗]\e[0m $1"
}

print_info() {
    echo -e "\e[1;34m[ℹ]\e[0m $1"
}

# Check if running as root for systemd setup
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        print_error "This script requires sudo/root privileges for systemd setup"
        exit 1
    fi
}

# Check Redis is running
check_redis() {
    print_info "Checking Redis connection..."
    if redis-cli ping > /dev/null 2>&1; then
        print_status "Redis is running"
    else
        print_error "Redis is not running. Please start Redis first:"
        echo "    sudo systemctl start redis"
        exit 1
    fi
}

# Check if application directory exists
check_app_directory() {
    print_info "Checking application directory..."
    if [ ! -d "$RAILS_ROOT" ]; then
        print_error "Application directory not found: $RAILS_ROOT"
        exit 1
    fi
    print_status "Application directory found"
}

# Stop old cronjobs
stop_old_cronjobs() {
    print_info "Creating backup of current crontab..."
    crontab -l > /tmp/nlims_crontab_backup_$(date +%Y%m%d_%H%M%S).txt 2>/dev/null || true
    print_status "Crontab backed up to /tmp/"
    
    print_info "You should manually review and remove old NLIMS cronjobs"
    print_info "Run: crontab -e"
}

# Install systemd service
install_systemd_service() {
    print_info "Installing systemd service..."
    
    cd "$RAILS_ROOT"
    
    if [ ! -f "$SERVICE_FILE" ]; then
        print_error "Service file not found: $SERVICE_FILE"
        exit 1
    fi
    
    # Copy service file
    cp "$SERVICE_FILE" "$SYSTEMD_PATH"
    print_status "Service file copied to $SYSTEMD_PATH"
    
    # Reload systemd
    systemctl daemon-reload
    print_status "Systemd daemon reloaded"
    
    # Enable service
    systemctl enable "$SERVICE_NAME"
    print_status "Service enabled to start on boot"
}

# Start Sidekiq service
start_sidekiq() {
    print_info "Starting Sidekiq service..."
    systemctl start "$SERVICE_NAME"
    sleep 2
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_status "Sidekiq service started successfully"
        systemctl status "$SERVICE_NAME" --no-pager
    else
        print_error "Failed to start Sidekiq service"
        print_error "Check logs: journalctl -u $SERVICE_NAME -n 50"
        exit 1
    fi
}

# Verify scheduled jobs
verify_jobs() {
    print_info "Verifying scheduled jobs..."
    cd "$RAILS_ROOT"
    
    sudo -u www-data bash -c "export PATH=\"\$HOME/.rbenv/bin:\$PATH\" && eval \"\$(rbenv init -)\" && cd $RAILS_ROOT && rbenv local 3.2.0 && RAILS_ENV=$RAILS_ENV bundle exec rails runner \"puts 'Scheduled jobs: ' + Sidekiq::Cron::Job.count.to_s\""
    
    print_status "Job verification complete"
}

# Show status
show_status() {
    echo ""
    echo "========================================="
    echo "Setup Complete!"
    echo "========================================="
    echo ""
    print_status "Sidekiq service is running"
    echo ""
    echo "Useful commands:"
    echo "  sudo systemctl status $SERVICE_NAME    # Check service status"
    echo "  sudo systemctl restart $SERVICE_NAME   # Restart service"
    echo "  sudo systemctl stop $SERVICE_NAME      # Stop service"
    echo "  sudo journalctl -u $SERVICE_NAME -f   # Follow logs"
    echo "  tail -f $RAILS_ROOT/log/sidekiq.log   # Application logs"
    echo ""
    echo "Web UI (if configured): http://your-server/sidekiq"
    echo ""
    echo "Next steps:"
    echo "  1. Review and remove old cronjobs: crontab -e"
    echo "  2. Monitor first job executions: tail -f $RAILS_ROOT/log/sidekiq.log"
    echo "  3. Access Sidekiq Web UI for monitoring"
    echo ""
}

# Main execution
main() {
    check_root
    check_app_directory
    check_redis
    stop_old_cronjobs
    install_systemd_service
    start_sidekiq
    verify_jobs
    show_status
}

# Run main function
main

#!/bin/bash

###############################################################################
# Quick Sidekiq Management Script for NLIMS Controller
###############################################################################

RAILS_ROOT="/var/www/nlims_controller"
SERVICE_NAME="nlims-sidekiq"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

show_header() {
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}NLIMS Sidekiq Management${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo ""
}

check_status() {
    echo -e "${YELLOW}Checking Sidekiq status...${NC}"
    systemctl status "$SERVICE_NAME" --no-pager
    echo ""
}

show_logs() {
    echo -e "${YELLOW}Showing Sidekiq logs (Ctrl+C to exit)...${NC}"
    tail -f "$RAILS_ROOT/log/sidekiq.log"
}

show_system_logs() {
    echo -e "${YELLOW}Showing system logs (Ctrl+C to exit)...${NC}"
    journalctl -u "$SERVICE_NAME" -f
}

restart_service() {
    echo -e "${YELLOW}Restarting Sidekiq service...${NC}"
    systemctl restart "$SERVICE_NAME"
    sleep 2
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo -e "${GREEN}✓ Service restarted successfully${NC}"
    else
        echo -e "${RED}✗ Failed to restart service${NC}"
        exit 1
    fi
}

stop_service() {
    echo -e "${YELLOW}Stopping Sidekiq service...${NC}"
    systemctl stop "$SERVICE_NAME"
    echo -e "${GREEN}✓ Service stopped${NC}"
}

start_service() {
    echo -e "${YELLOW}Starting Sidekiq service...${NC}"
    systemctl start "$SERVICE_NAME"
    sleep 2
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        echo -e "${GREEN}✓ Service started successfully${NC}"
    else
        echo -e "${RED}✗ Failed to start service${NC}"
        exit 1
    fi
}

check_redis() {
    echo -e "${YELLOW}Checking Redis connection...${NC}"
    if redis-cli ping > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Redis is running${NC}"
    else
        echo -e "${RED}✗ Redis is not running${NC}"
    fi
}

show_scheduled_jobs() {
    echo -e "${YELLOW}Fetching scheduled jobs...${NC}"
    cd "$RAILS_ROOT"
    sudo -u www-data bash -c "export PATH=\"\$HOME/.rbenv/bin:\$PATH\" && eval \"\$(rbenv init -)\" && cd $RAILS_ROOT && rbenv local 3.2.0 && RAILS_ENV=production bundle exec rails runner \"Sidekiq::Cron::Job.all.each { |j| puts format('%-50s %s', j.name, j.status) }\""
}

show_queue_status() {
    echo -e "${YELLOW}Fetching queue status...${NC}"
    cd "$RAILS_ROOT"
    sudo -u www-data bash -c "export PATH=\"\$HOME/.rbenv/bin:\$PATH\" && eval \"\$(rbenv init -)\" && cd $RAILS_ROOT && rbenv local 3.2.0 && RAILS_ENV=production bundle exec rails runner \"
        puts '\\nQueues:'
        ['critical', 'high_priority', 'default', 'low_priority'].each do |q|
          queue = Sidekiq::Queue.new(q)
          puts format('  %-15s %d jobs', q + ':', queue.size)
        end
        puts '\\nStats:'
        stats = Sidekiq::Stats.new
        puts format('  %-15s %d', 'Processed:', stats.processed)
        puts format('  %-15s %d', 'Failed:', stats.failed)
        puts format('  %-15s %d', 'Enqueued:', stats.enqueued)
        puts format('  %-15s %d', 'Retries:', stats.retry_size)
        puts format('  %-15s %d', 'Dead:', stats.dead_size)
    \""
}

clear_stuck_jobs() {
    echo -e "${RED}WARNING: This will clear ALL stuck/failed jobs!${NC}"
    read -p "Are you sure? (yes/no): " -r
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo -e "${YELLOW}Clearing stuck jobs...${NC}"
        cd "$RAILS_ROOT"
        sudo -u www-data bash -c "export PATH=\"\$HOME/.rbenv/bin:\$PATH\" && eval \"\$(rbenv init -)\" && cd $RAILS_ROOT && rbenv local 3.2.0 && RAILS_ENV=production bundle exec rails runner \"
            Sidekiq::RetrySet.new.clear
            Sidekiq::DeadSet.new.clear
            puts 'Cleared retry and dead sets'
        \""
        echo -e "${GREEN}✓ Stuck jobs cleared${NC}"
    else
        echo "Cancelled"
    fi
}

reload_schedule() {
    echo -e "${YELLOW}Reloading Sidekiq schedule...${NC}"
    cd "$RAILS_ROOT"
    sudo -u www-data bash -c "export PATH=\"\$HOME/.rbenv/bin:\$PATH\" && eval \"\$(rbenv init -)\" && cd $RAILS_ROOT && rbenv local 3.2.0 && RAILS_ENV=production bundle exec rails runner \"
        schedule = YAML.load_file('config/schedule.yml')
        Sidekiq::Cron::Job.load_from_hash(schedule)
        puts 'Schedule reloaded: ' + Sidekiq::Cron::Job.count.to_s + ' jobs'
    \""
    echo -e "${GREEN}✓ Schedule reloaded${NC}"
}

show_menu() {
    echo ""
    echo "Select an option:"
    echo "  1) Check status"
    echo "  2) Show application logs"
    echo "  3) Show system logs"
    echo "  4) Restart service"
    echo "  5) Stop service"
    echo "  6) Start service"
    echo "  7) Check Redis"
    echo "  8) Show scheduled jobs"
    echo "  9) Show queue status"
    echo " 10) Clear stuck jobs"
    echo " 11) Reload schedule"
    echo "  0) Exit"
    echo ""
    read -p "Enter choice [0-11]: " choice
}

main() {
    show_header
    
    while true; do
        show_menu
        case $choice in
            1) check_status ;;
            2) show_logs ;;
            3) show_system_logs ;;
            4) restart_service ;;
            5) stop_service ;;
            6) start_service ;;
            7) check_redis ;;
            8) show_scheduled_jobs ;;
            9) show_queue_status ;;
            10) clear_stuck_jobs ;;
            11) reload_schedule ;;
            0) echo "Exiting..."; exit 0 ;;
            *) echo -e "${RED}Invalid option${NC}" ;;
        esac
        
        if [[ $choice != 2 && $choice != 3 ]]; then
            echo ""
            read -p "Press Enter to continue..."
        fi
    done
}

# Check if running with sudo for systemctl commands
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run with sudo for full functionality${NC}"
    echo "Usage: sudo $0"
    exit 1
fi

main

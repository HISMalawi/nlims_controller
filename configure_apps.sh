#!/bin/bash

# Default IP and port for LOCAL NLIMS
LOCAL_NLIMS_IP="localhost"
LOCAL_NLIMS_PORT="3009"
# Function to generate a random string
generate_random_string() {
  echo $(cat /dev/urandom | tr -dc 'a-zA-Z' | fold -w 10 | head -n 1)
}

# Function to validate IP addresses
validate_ip() {
  local ip=$1
  local stat=1
  if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    OIFS=$IFS
    IFS='.'
    ip=($ip)
    IFS=$OIFS
    [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
    stat=$?
  fi
  return $stat
}

# Function to validate ports
validate_port() {
  local port=$1
  if [[ $port -ge 1 && $port -le 65535 ]]; then
    return 0
  else
    return 1
  fi
}

# Function to prompt for IP and port
prompt_ip_port() {
  local ip=""
  local port=""

  while true; do
    read -p "Enter the IP Address for $1: " ip
    validate_ip $ip && break
    echo "Invalid IP address. Please try again."
  done

  while true; do
    read -p "Enter the Port for $1: " port
    validate_port $port && break
    echo "Invalid port. Please enter a port between 1 and 65535."
  done

  eval $2="'$ip'"
  eval $3="'$port'"
}

# Function to display entered data and ask for confirmation
confirm_data() {
  echo "---------------------------------------" 
  echo "Please review the entered information:"
  echo "---------------------------------------"
  echo "Master NLIMS IP Address: $MASTER_IP"
  echo "Master NLIMS Port: $MASTER_PORT"
  echo "EMR IP Address: $EMR_IP"
  echo "EMR Backend Port: $EMR_PORT"
  if [[ "${MAHIS_AVAILABLE,,}" == "yes" || "${MAHIS_AVAILABLE,,}" == "y" ]]; then
    echo "MAHIS IP Address: $MAHIS_IP"
    echo "MAHIS Port: $MAHIS_PORT"
  fi
  echo "Local NLIMS Password: $LOCAL_NLIMS_PASSWORD"
  echo "Default Master NLIMS Password: $DEFAULT_MASTER_NLIMS_PASSWORD"
  echo "Master NLIMS Password: $MASTER_NLIMS_PASSWORD"
  echo "EMR Password: $EMR_PASSWORD"
  if [[ "${MAHIS_AVAILABLE,,}" == "yes" || "${MAHIS_AVAILABLE,,}" == "y" ]]; then
    echo "MAHIS Password: $MAHIS_PASSWORD"
  fi
  if [[ "${IBLIS_AVAILABLE,,}" == "yes" || "${IBLIS_AVAILABLE,,}" == "y" ]]; then
    echo "IBLIS Password: $IBLIS_PASSWORD"
  fi
  echo "---------------------------------------"
  read -p "Is this information correct? (yes/no): " CONFIRMATION
  if [[ "${CONFIRMATION,,}" == "yes" || "${CONFIRMATION,,}" == "y" ]]; then
    echo "Proceeding"
  else
    echo "Let's re-enter the information."
    main
  fi
}

# Main function that prompts user for input and confirms before running the script
main() {
    # Ask for master IP address and port
    prompt_ip_port "Master NLIMS" MASTER_IP MASTER_PORT

    # Ask for EMR IP address and port
    prompt_ip_port "EMR-Backend" EMR_IP EMR_PORT

    # Ask if MAHIS is available
    read -p "Is MAHIS available? (yes/no): " MAHIS_AVAILABLE
    if [[ "${MAHIS_AVAILABLE,,}" == "yes" || "${MAHIS_AVAILABLE,,}" == "y" ]]; then
      prompt_ip_port "MAHIS" MAHIS_IP MAHIS_PORT
    else
      MAHIS_IP=""
      MAHIS_PORT=""
    fi
    echo '---------------------------------------------------------------'
    # Ask if IBLIS is available
    read -p "Is IBLIS available? (yes/no): " IBLIS_AVAILABLE
    if [[ "${IBLIS_AVAILABLE,,}" == "yes" || "${IBLIS_AVAILABLE,,}" == "y" ]]; then
      read -p "Enter the password for IBLIS(Used by IBLIS to Send order to Local NLIMS): " IBLIS_PASSWORD
      echo
    else
      IBLIS_PASSWORD=""
    fi

    # Ask for passwords for each application
    read -p "Enter the password for LOCAL NLIMS(Used sending to send local NLIMS action to Master): " LOCAL_NLIMS_PASSWORD
    echo
    read -p "Enter the DEFAULT PASSWORD for MASTER NLIMS(Used for account creation): " DEFAULT_MASTER_NLIMS_PASSWORD
    echo
    read -p "Enter the password for MASTER NLIMS(Used by Master NLIMS for any other action e.g status update to Local NLIMS): " MASTER_NLIMS_PASSWORD
    echo
    read -p "Enter the password for EMR(Used to send Local NLIMS actions to EMR): " EMR_PASSWORD
    echo
    if [[ "${MAHIS_AVAILABLE,,}" == "yes" || "${MAHIS_AVAILABLE,,}" == "y" ]]; then
      read -p "Enter the password for MAHIS: " MAHIS_PASSWORD
      echo
    else
      MAHIS_PASSWORD=""
    fi

    # Generate a random string and prepend it to local_nlims_lab_daemon
    RANDOM_STRING=$(generate_random_string)
    NEW_LOCAL_NLIMS_USER="${RANDOM_STRING}_local_nlims${RANDOM_STRING}_lab_daemon"
    EMR_RANDOM_STRING=$(generate_random_string)
    NEW_EMR_LOCAL_NLIMS_USER="${EMR_RANDOM_STRING}_emr_local_nlims_lab_daemon"

    # Confirm the entered data
    confirm_data

    # Create config/settings.yml with the passwords
cat <<EOL > config/settings.yml
local_nlims:
 default: $DEFAULT_MASTER_NLIMS_PASSWORD
 main: $LOCAL_NLIMS_PASSWORD
master_nlims:
 default: $DEFAULT_MASTER_NLIMS_PASSWORD
 main: $MASTER_NLIMS_PASSWORD
emr: $EMR_PASSWORD
mahis: $MAHIS_PASSWORD
EOL

# Create a file to store usernames and passwords
cat <<EOL > users_credentials.txt
Username: $NEW_LOCAL_NLIMS_USER, Password: $LOCAL_NLIMS_PASSWORD
Username: master_nlims_lab_daemon, Password: $MASTER_NLIMS_PASSWORD
Username: $NEW_EMR_LOCAL_NLIMS_USER, Password: $EMR_PASSWORD
EOL
if [[ "${MAHIS_AVAILABLE,,}" == "yes" || "${MAHIS_AVAILABLE,,}" == "y" ]]; then
  echo "Username: mahis_nlims_lab_daemon, Password: $MAHIS_PASSWORD" >> users_credentials.txt
fi
if [[ "${IBLIS_AVAILABLE,,}" == "yes" || "${IBLIS_AVAILABLE,,}" == "y" ]]; then
  echo "Username: iblis_nlims_lab_daemon, Password: $IBLIS_PASSWORD" >> users_credentials.txt
fi

# Overwrite the bin/system_config.rb file with the new content
cat <<EOL > bin/system_config.rb
# frozen_string_literal: true

MASTER_IP_ADDRESS = '$MASTER_IP'

Config.find_or_create_by(config_type: 'nlims_host').update(configs: { local_nlims: true })
users = [
{
    username: '$NEW_LOCAL_NLIMS_USER',
    password: BCrypt::Password.create('$LOCAL_NLIMS_PASSWORD'),
    app_name: 'LOCAL NLIMS',
    partner: 'EGPAF',
    location: 'MALAWI',
    token: 'xxxx',
    token_expiry_time: '000000000',
    app_uuid: '008aa778-af95-42d5-ba54-2f5ddc4f9e78'
},
{
    username: 'master_nlims_lab_daemon',
    password: BCrypt::Password.create('$MASTER_NLIMS_PASSWORD'),
    app_name: 'MASTER NLIMS',
    partner: 'EGPAF',
    location: 'MALAWI',
    token: 'xxxx',
    token_expiry_time: '000000000',
    app_uuid: 'c1bcdaa3-a835-4481-84dc-92dace6bea59'
},
{
    username: '$NEW_EMR_LOCAL_NLIMS_USER',
    password: BCrypt::Password.create('$EMR_PASSWORD'),
    app_name: 'EMR',
    partner: 'EGPAF',
    location: 'MALAWI',
    token: 'xxxx',
    token_expiry_time: '000000000',
    app_uuid: 'a6a52ccb-8215-45d8-90dc-826ee12f4055'
}$([ "$MAHIS_AVAILABLE" = "yes" ] && echo ",
{
    username: 'mahis_nlims_lab_daemon',
    password: BCrypt::Password.create('$MAHIS_PASSWORD'),
    app_name: 'MAHIS',
    partner: 'DHD',
    location: 'MALAWI',
    token: 'xxxx',
    token_expiry_time: '000000000',
    app_uuid: '2d299a0b-327a-4be0-b44d-bd3385303224'
}")$([ "$IBLIS_AVAILABLE" = "yes" ] && echo ",
{
    username: 'iblis_nlims_lab_daemon',
    password: BCrypt::Password.create('$IBLIS_PASSWORD'),
    app_name: 'IBLIS',
    partner: 'EGPAF',
    location: 'MALAWI',
    token: 'xxxx',
    token_expiry_time: '000000000',
    app_uuid: '7d398a0b-327a-4be0-b44d-bd3385303224'
}")
]
users.each do |user|
puts "Creating user for #{user[:app_name]} app"
user_obj = User.find_by_username(user[:username])
user_obj ||= User.create!(user)
user_obj&.update(user)
end

if Config.local_nlims?
Config.find_or_create_by(config_type: 'master_nlims')
        .update(
        configs: {
            name: 'MASTER NLIMS',
            address: "http://$MASTER_IP",
            port: $MASTER_PORT,
            username: '$NEW_LOCAL_NLIMS_USER'
        }
        )
Config.find_or_create_by(config_type: 'emr')
        .update(
        configs: {
            name: 'EMR',
            address: 'http://$EMR_IP',
            port: $EMR_PORT,
            username: '$$NEW_EMR_LOCAL_NLIMS_USER'
        }
        )
$([ "$MAHIS_AVAILABLE" = "yes" ] && echo "
Config.find_or_create_by(config_type: 'mahis')
        .update(
        configs: {
            name: 'MAHIS',
            address: 'http://$MAHIS_IP',
            port: $MAHIS_PORT,
            username: 'mahis_nlims_lab_daemon'
        }
        )")
$([ "$IBLIS_AVAILABLE" = "yes" ] && echo "
Config.find_or_create_by(config_type: 'iblis')
        .update(
        configs: {
            name: 'IBLIS',
            address: 'http://localhost',
            port: 8005,
            username: 'iblis_nlims_lab_daemon'
        }
        )")
else
Config.find_or_create_by(config_type: 'local_nlims')
        .update(
        configs: {
            name: 'LOCAL NLIMS',
            address: 'http://$LOCAL_NLIMS_IP',
            port: $LOCAL_NLIMS_PORT,
            username: 'master_nlims_lab_daemon'
        }
        )
end
EOL

echo "Configuration complete! bin/system_config.rb has been updated."

# Run system_config.rb via bundle exec rails
echo "Running system_config.rb..."
bundle exec rails r bin/system_config.rb

echo "--------------------------------------------------------------------"
echo "Configuration Complete! Passwords can be found in the config/settings.yml"
echo "Usernames and passwords saved in users_credentials.txt."

echo "--------------------------------------------------------------------"
echo "Creating user in emr"
bundle exec rake emr:create_user

echo "--------------------------------------------------------------------"
echo "Creating user in master NLIMS"
bundle exec rake master_nlims:create_account
}

master_setup(){
cat <<EOL > bin/system_config.rb
# frozen_string_literal: true

Config.find_or_create_by(config_type: 'nlims_host').update(configs: { local_nlims: false })
Config.find_or_create_by(config_type: 'local_nlims')
        .update(
        configs: {
            name: 'LOCAL NLIMS',
            address: 'http://$LOCAL_NLIMS_IP',
            port: $LOCAL_NLIMS_PORT,
            username: 'master_nlims_lab_daemon'
        }
        )
EOL
read -p "Enter the password for MASTER NLIMS(Used by Master NLIMS for any other action e.g status update to Local NLIMS): " MASTER_NLIMS_PASSWORD
cat <<EOL > config/settings.yml
local_nlims:
 default:
 main:
master_nlims:
 default:
 main: $MASTER_NLIMS_PASSWORD
emr:
mahis:
EOL
echo "Configuration complete! bin/system_config.rb has been updated."
echo "Running system_config.rb..."
bundle exec rails r bin/system_config.rb
}

read -p "Is the setup for local site and not CHSU? (yes/no): " IS_LOCAL_NLIMS
if [[ "${IS_LOCAL_NLIMS,,}" == "yes" || "${IS_LOCAL_NLIMS,,}" == "y" ]]; then
 main
else
 master_setup
fi
# NLIMS SETUP

## Prerequisites

Before installing `NLIMS`, ensure that the following requirements are met:

- Ruby 3.2.0
- MySQL 8
- Rails 7
- redis 7+

## Configuration

1. Checkout to the ```main``` branch
   ```bash
   git checkout main
   ```
      OR 
   ```bash
   git checkout [tag]
   ```
2. Open the respective configuration files in the `config` folder: Copy the .example file to respective .yml file e.g  
   ```bash
   cp database.yml.example database.yml
   ```

   - `database.yml`: Configure your database settings.
   - `application.yml`: Edit application-specific configurations as required.

3. Update the configuration settings in these files to match your environment.

## Installation

1. Install project dependencies using Bundler. Run the following command in your project directory:

   ```bash
   bundle install --local
   ```
## First-Time Setup

If you are installing the app for the first time, follow these steps:

1. Create the database:

   ```bash
   rails db:create
   ```
2. Seed the database with initial data:

   ```bash
   ./bin/initialize_db.sh development
   ```
3. Update metadata:

   ```bash
   ./bin/update_metadata.sh development
   ```
## Updating NLIMS

If you already had NLIMS running before and want to update it, follow these steps:

1. Checkout to intended tag.
   ```bash
   git checkout [tag]
   ```
2. Run bundle install
   ```bash
   rm Gemfile.lock
   bundle install --local
   ```
3. Run update metadata:
   ```bash
   ./bin/update_metadata.sh
   ```

## Configuring the integration with other systems
1. Run the following command to configure the integration with other systems and follow the prompts(In production: use the production credentials for master as directed in the setup instruction):
   ```bash
      ./configure_apps.sh
   ```
2. Get the user credentials created in the user_credentials.txt file following the script run and and use them in subsequent steps

## Running the Application
To start the application:
```bash
rails s -p3000 -b 0.0.0.0
```
To start the sidekiq worker:
```bash
bundle exec sidekiq
```
OR
Copy the nlims-api.service file to /etc/systemd/system/. Note that the service file is configured to run the application on port 3009 and rbenv is used. And the service user is set to emr-user, rails enviroment to development and working directory is set to /var/www/nlims_controller which you can change to your desired location and user and environment(production or development).
```bash
sudo cp nlims-api.service /etc/systemd/system/
```
Then run the following command to start the application:
```bash
sudo systemctl start nlims-api
```
Enable the service to start on boot:
```bash
sudo systemctl enable nlims-api
```
Check the status of the service:
```bash
sudo systemctl status nlims-api
```

## Running sidekiq to handle background jobs such as syncing data between the ART application and the central CHSU NLIMS.
Copy the nlims-sidekiq.service file to /etc/systemd/system/. Note that the service user is set to emr-user, rails enviroment to development and working directory is set to /var/www/nlims_controller which you can change to your desired location and user and environment(production or development).
```bash
sudo cp nlims-sidekiq.service /etc/systemd/system/
```
Then run the following command to start the service:
```bash
sudo systemctl start nlims-sidekiq
```
Enable the service to start on boot:
```bash
sudo systemctl enable nlims-sidekiq
```
Check the status of the service:
```bash
sudo systemctl status nlims-sidekiq
```

NOTE: The above steps for running the application are for the ART server and the CHSU server. For the ART server, the application is run on port 3009 and for the CHSU server, the application is run on port 3010 which is configured in the service file. 

NOTE: The rails environment in which nlims-api is running should be the same envinronment in which the sidekiq worker is running. If development, sidekiq should also be development. If production, sidekiq should also be production. You can change the environments in the services file.

# Local NLIMS at Sites 

## Overview

Local NLIMS (National Laboratory Information Management System) is an integral part of the healthcare infrastructure in ART sites. It plays a crucial role in facilitating communication between the ART application and the central CHSU (Central Health Service Unit) NLIMS. This document provides an overview of how Local NLIMS operates and communicates with various components.

## Functionality

- **Running in ART Sites**: Local NLIMS is deployed and operates within ART sites, specifically on the ART server.

- **Communication with ART**: Every ART application at the site has an associated account with the Local NLIMS. This allows ART to push orders and pull statuses and results from the Local NLIMS.

- **Integration with CHSU NLIMS**: Local NLIMS further communicates with the central CHSU NLIMS. It pushes orders to the CHSU NLIMS and pulls statuses and results from it.

- **Data Relay to ART**: Once the Local NLIMS retrieves statuses and results from the CHSU NLIMS, it pushes this data to the ART application, ensuring seamless data transfer.

- **Access Control**: Local NLIMS enforces access control by requiring accounts to permit transactions between it and other systems. This access is configured via usernames and passwords.

## How ART Communicates with Local NLIMS 

ART communicates with the Local NLIMS through its backend, which is the API module. To configure this communication, follow these steps:

1. **Check `application.yml`**: Within the EMR API, locate the `application.yml` file.

2. **Configuration Settings**:
   - Ensure that `lims_api` is not commented out, as this allows the API to interact with the Local NLIMS.
   - Verify that `lims_port` specifies the correct port number on which the Local NLIMS is running.
   - Customize `lims_username` and `lims_password` with the appropriate credentials from the user_credentials.txt file created during the nlims setup.

3. With these configurations in place, BHT-EMR-API can now interact with the Local NLIMS. Additionally, a job within the EMR-API allows transactions to and from the Local NLIMS. This job should be scheduled in the crontab to execute at specified intervals. The job is found under `bin/lab/sync_worker.rb`.  
```bash
* * * * * /bin/bash -l -c 'cd /var/www/BHT-EMR-API && bin/rails runner -e development '\''bin/lab/sync_worker.rb'\'''
```
## How IBLIS Communicates with Local NLIMS 
1. **Check `application.yml`**: Within the MLAB API, locate the `application.yml` file.

2. **Configuration Settings**:
- Customize `username` and `password` of the nlims_service block with the appropriate credentials from the user_credentials.txt file created during the nlims setup.
- Ensure the base_url is pointing to the correct nlims.
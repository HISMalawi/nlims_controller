# NLIMS SETUP

## Prerequisites

Before installing `NLIMS`, ensure that the following requirements are met:

- Ruby 2.5.3
- MySQL 5.6
- Rails 5
- Couchdb 3.2.1

## Installing CouchDB
Install by following this guide: [Couchdb installation](https://github.com/HISMalawi/couchdb_installation/tree/main)

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
   - `couchdb.yml`: Configure your CouchDB settings.
   - `results_channel_socket.yml`: Configure your results channel socket settings.
   - `application.yml`: Edit application-specific configurations as required.
   - `emr_connection` : Configure connection to emr for updating results and statuses, [See this section](#master_nlims)
   - `master_nlims.yml`: Configure your CouchDB settings, [See this section](#master_nlims)

3. Update the configuration settings in these files to match your environment.

## Installation

1. Install project dependencies using Bundler. Run the following command in your project directory:

   ```bash
   bundle install
   ```
## First-Time Setup

If you are installing the app for the first time, follow these steps:

1. Create the database:

   ```bash
   rails db:create
   ```
2. Run database migrations:

   ```bash
   rails db:migrate
   ```
3. Seed the database with initial data:

   ```bash
   rails db:seed
   ```
## Updating NLIMS

If you already had NLIMS running before and want to update it, follow these steps:

1. Load the database dump.

3. Run update metadata:

   ```bash
   ./bin/update_metadata.sh
   ```
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

1. **Check `application.yml`**: Within the API, locate the `application.yml` file.

2. **Configuration Settings**:
   - Ensure that `lims_api` is not commented out, as this allows the API to interact with the Local NLIMS.
   - Verify that `lims_port` specifies the correct port number on which the Local NLIMS is running.
   - Set `lims_default_username` to "admini" for access during account creation.
   - Set `lims_default_password` to "knock_knock" for access during account creation.
   - Customize `lims_username` and `lims_password` with your desired credentials for accounts created on the Local NLIMS.

3. **Create an Account**: To create an account with the Local NLIMS at the facility, run the following command within the BHT-EMR-API application:
   ```bash
   rake nlims:create_user
   ```

4. With these configurations in place, BHT-EMR-API can now interact with the Local NLIMS. Additionally, a job within the EMR-API allows transactions to and from the Local NLIMS. This job should be scheduled in the crontab to execute at specified intervals. The job is found under `bin/lab/sync_worker.rb`.  
```bash
* * * * * /bin/bash -l -c 'cd /var/www/BHT-EMR-API && bin/rails runner -e development '\''bin/lab/sync_worker.rb'\'''
```

## How Local NLIMS Communicates with CHSU NLIMS {#master_nlims}

Local NLIMS communicates with the CHSU NLIMS and requires an account for proper setup. Follow these steps:

1. **Edit `master_nlims.yml`**:
   - Set the `protocol` to the IP address of the CHSU NLIMS (e.g., 10.44.0.46).
   - Set `port` to the port number on which the CHSU NLIMS is running (e.g., 3010).
   - Ensure that `default_username` and `default_password` are set to "admin" and "knock_knock," respectively, to permit account creation at CHSU NLIMS.
   - Customize `password` and `username` with your desired credentials for the account created at CHSU NLIMS.

2. **Create an Account with CHSU NLIMS**:
   Run the following command to create an account with the CHSU NLIMS:
   ```bash
   rake master_nlims:create_account
   ```

3. **Data Synchronization to CHSU NLIMS**:
   To push orders from the Local NLIMS to the CHSU NLIMS, a job named `master_nlims:sync_data` must be scheduled in the crontab. This job ensures that pending data is sent to the CHSU NLIMS.
   ```bash
   0 */2 * * *  /bin/bash -l -c 'cd /var/www/nlims_controller && rvm use 2.5.3 && RAILS_ENV=development bundle exec rake master_nlims:sync_data --silent >> log/pull_from_master_nlims.log 2>&1'
   ```

4. **Data Retrieval from CHSU NLIMS and Sharing**:
   Local NLIMS pulls statuses and results from the CHSU NLIMS and shares this data with the ART application. This is accomplished through the `master_nlims:sync_data` job. It can also send these statuses and results to the ART application proactively without waiting for a request.

5. **Account Configuration with ART**
   - Edit the `emr_connection.yml` file to specify the IP address and port number where the ART application (BHT-EMR-API) is running.
   - Customize `username` and `password` with your desired credentials, which will be used for the account created within the ART application.
   - Run the following command to create account with emr
   ```bash
      rake emr:create_user
   ```
By following these steps, Local NLIMS establishes effective communication with both the ART application and the CHSU NLIMS, facilitating efficient data exchange within the healthcare system.
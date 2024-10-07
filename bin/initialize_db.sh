#!/bin/bash

usage() {
  echo "Usage: $0 ENVIRONMENT"
  echo
  echo "ENVIRONMENT should be: development|test|production"
}

ENV=$1

if [ -z "$ENV" ]; then
  usage
  exit 255
fi

set -x # turns on stacktrace mode which gives useful debug information

export RAILS_ENV=$ENV
rails db:environment:set RAILS_ENV=$ENV

USERNAME=`ruby -ryaml -e "puts YAML::load_file('config/database.yml',aliases: true)['${ENV}']['username']"`
PASSWORD=`ruby -ryaml -e "puts YAML::load_file('config/database.yml',aliases: true)['${ENV}']['password']"`
DATABASE=`ruby -ryaml -e "puts YAML::load_file('config/database.yml',aliases: true)['${ENV}']['database']"`
HOST=`ruby -ryaml -e "puts YAML::load_file('config/database.yml',aliases: true)['${ENV}']['host']"`
PORT=`ruby -ryaml -e "puts YAML::load_file('config/database.yml',aliases: true)['${ENV}']['port']"`

# Folder containing the SQL files
SQL_FOLDER="db/sql/init_db"

# Loop through all files ending with ".sql" in the specified folder
for sql_file in "$SQL_FOLDER"/*.sql; do
# Check if the file exists and is readable
if [ -r "$sql_file" ]; then
    # Run the MySQL command to execute the SQL file
    mysql --host="$HOST" --port="$PORT" --user="$USERNAME" --password="$PASSWORD" "$DATABASE" < "$sql_file"
else
    echo "Error: $sql_file does not exist or is not readable."
fi
done

rails db:migrate
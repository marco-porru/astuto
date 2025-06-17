#!/bin/sh

# Exit immediately if a command exits with a non-zero status
set -e

# Remove a potentially pre-existing server.pid for Rails
rm -f $APP_ROOT/tmp/pids/server.pid

# Prepare database
echo "Preparing database..."

# Generate config/database.yml from ERB template if present
if [ -f "$APP_ROOT/config/database.yml.erb" ]; then
  echo "Generating config/database.yml from ERB template..."
  ruby -rerb -e "File.write('$APP_ROOT/config/database.yml', ERB.new(File.read('$APP_ROOT/config/database.yml.erb')).result)"
fi

# Wait for database, try to create if connection fails
db_ready=0
while [ $db_ready -eq 0 ]; do
  if bundle exec rake db:version > /dev/null 2>&1; then
    db_ready=1
  else
    echo "Database not ready or does not exist. Trying to create..."
    if bundle exec rake db:create > /dev/null 2>&1; then
      echo "Database created."
    else
      >&2 echo "Waiting for postgres to initialize..."
      sleep 1
    fi
  fi
done

# Update or create database
db_version=$(bundle exec rake db:version)
echo "$db_version"
if [ "$db_version" = "Current version: 0" ]; then
  bundle exec rake db:create
  bundle exec rake db:schema:load
  bundle exec rake db:migrate
  bundle exec rake db:seed
else
  bundle exec rake db:migrate
fi
echo "Database prepared."
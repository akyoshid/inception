#!/bin/bash
# ============================================================================
# WordPress Setup Script
# ============================================================================
set -e

# Read passwords from Docker Secrets if available, fallback to env vars
if [ -f "/run/secrets/db_password" ]; then
    export MYSQL_PASSWORD=$(cat /run/secrets/db_password)
fi

if [ -f "/run/secrets/wp_admin_password" ]; then
    export WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password)
fi

if [ -f "/run/secrets/wp_user_password" ]; then
    export WP_USER_PASSWORD=$(cat /run/secrets/wp_user_password)
fi

# Wait for MariaDB to be ready
# Why is waiting necessary?
# - depends_on only guarantees the startup order of containers
# - MariaDB initialization takes time
# - If WordPress is configured while it cannot connect, it will fail
echo "Waiting for MariaDB..."
until mysqladmin ping -h"mariadb" -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" --silent; do
    sleep 2
done
echo "MariaDB is ready!"

# Check if WordPress is already installed
# - Files remain due to persistent data
# - Prevent reinstallation & maintain database integrity
if [ -f "wp-config.php" ]; then
    echo "WordPress is already installed."
else
    echo "Installing WordPress..."
    
    # Download WordPress
    #  Just download the complete set of WordPress files
    #  (not installed yet; not configured either).
    wp core download --allow-root
    
    # Create wp-config.php
    wp config create \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${MYSQL_PASSWORD}" \
        --dbhost="mariadb" \
        --allow-root
    
    # Install WordPress
    #  Register the site title, administrator user,
    #   & other information in the database.
    wp core install \
        --url="https://${DOMAIN_NAME}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email \
        --allow-root
    
    # Create additional user
    wp user create \
        "${WP_USER}" \
        "${WP_USER_EMAIL}" \
        --role=editor \
        --user_pass="${WP_USER_PASSWORD}" \
        --allow-root
    
    # Set proper permissions
    # - To allow WordPress to create and edit files
    # - To install plugins
    # - To upload media
    # - To create cache files
    chown -R www-data:www-data /var/www/wordpress
    
    echo "WordPress installation complete!"
fi

# Clear sensitive variables
unset MYSQL_PASSWORD WP_ADMIN_PASSWORD WP_USER_PASSWORD

# Start PHP-FPM in foreground
echo "Starting PHP-FPM..."
exec php-fpm8.2 -F

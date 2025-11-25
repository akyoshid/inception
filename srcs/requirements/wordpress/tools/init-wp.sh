#!/bin/bash
# ============================================================================
# WordPress Setup Script
# ============================================================================
set -e

echo "========================================="
echo "WordPress Initialization Script"
echo "========================================="

# ============================================================================
# STEP 1: Read secrets from Docker Secrets
# ============================================================================
echo "[1/5] Loading secrets..."

if [ -f "/run/secrets/db_password" ]; then
    export MYSQL_PASSWORD=$(cat /run/secrets/db_password)
    echo "  ✓ Loaded: db_password"
else
    echo "ERROR: db_password secret not found" >&2
    exit 1
fi

if [ -f "/run/secrets/wp_admin_password" ]; then
    export WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password)
    echo "  ✓ Loaded: wp_admin_password"
else
    echo "ERROR: wp_admin_password secret not found" >&2
    exit 1
fi

if [ -f "/run/secrets/wp_user_password" ]; then
    export WP_USER_PASSWORD=$(cat /run/secrets/wp_user_password)
    echo "  ✓ Loaded: wp_user_password"
else
    echo "ERROR: wp_user_password secret not found" >&2
    exit 1
fi

echo "[1/5] ✓ All secrets loaded"

# ============================================================================
# STEP 2: Wait for MariaDB to be ready (fallback check)
# ============================================================================
# Note: docker-compose healthcheck handles this via depends_on condition,
#       but we keep a fallback check for safety and manual container runs
echo "[2/5] Verifying MariaDB connection..."

MAX_RETRIES=30
RETRY_COUNT=0

until mysqladmin ping -h"mariadb" -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" --silent 2>/dev/null; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo "ERROR: MariaDB connection failed after ${MAX_RETRIES} attempts" >&2
        exit 1
    fi
    echo "  Waiting for MariaDB... (${RETRY_COUNT}/${MAX_RETRIES})"
    sleep 2
done

echo "[2/5] ✓ MariaDB is ready"

# ============================================================================
# STEP 3: Check if WordPress is already installed
# ============================================================================
# - Files remain due to persistent data
# - Prevent reinstallation & maintain database integrity
echo "[3/5] Checking WordPress installation status..."

if [ -f "wp-config.php" ]; then
    echo "[3/5] ✓ WordPress already installed - Skipping installation"
else
    echo "[3/5] WordPress not found - Starting installation..."
    
    # ------------------------------------------------------------------
    # Download WordPress
    # ------------------------------------------------------------------
    echo "[4/5] Downloading WordPress core files..."
    wp core download --allow-root
    echo "[4/5] ✓ WordPress downloaded"
    
    # ------------------------------------------------------------------
    # Create wp-config.php
    # ------------------------------------------------------------------
    echo "  Creating wp-config.php..."
    wp config create \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${MYSQL_PASSWORD}" \
        --dbhost="mariadb" \
        --allow-root
    echo "  ✓ wp-config.php created"
    
    # ------------------------------------------------------------------
    # Install WordPress
    # ------------------------------------------------------------------
    # Register the site title, administrator user,
    # & other information in the database.
    echo "  Installing WordPress..."
    wp core install \
        --url="https://${DOMAIN_NAME}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email \
        --allow-root
    echo "  ✓ WordPress installed"
    
    # ------------------------------------------------------------------
    # Create additional user
    # ------------------------------------------------------------------
    echo "  Creating additional user..."
    wp user create \
        "${WP_USER}" \
        "${WP_USER_EMAIL}" \
        --role=editor \
        --user_pass="${WP_USER_PASSWORD}" \
        --allow-root
    echo "  ✓ User '${WP_USER}' created"
    
    echo "[4/5] ✓ WordPress installation complete"
fi

# ============================================================================
# STEP 4: Set proper permissions
# ============================================================================
# Run every time, not just on install
# This ensures permissions are correct even after volume mount
# - To allow WordPress to create and edit files
# - To install plugins
# - To upload media
# - To create cache files
echo "[5/5] Setting file permissions..."
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html
echo "[5/5] ✓ Permissions set"

# ============================================================================
# STEP 5: Clear sensitive variables and start PHP-FPM
# ============================================================================
unset MYSQL_PASSWORD WP_ADMIN_PASSWORD WP_USER_PASSWORD

echo "========================================="
echo "Starting PHP-FPM as PID 1..."
echo "========================================="

# Start PHP-FPM in foreground
exec php-fpm8.2 -F

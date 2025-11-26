#!/bin/bash
# ============================================================================
# Docker Secrets Generator for Inception Project
# ============================================================================
# This script generates Docker Secrets files
#
# Generated files:
# - secrets/db_root_password.txt     : MariaDB root password
# - secrets/db_password.txt          : Password for the WordPress DB user
# - secrets/wp_admin_password.txt    : WordPress admin password
# - secrets/wp_user_password.txt     : WordPress regular user password
# - secrets/ftp_password.txt         : FTP user password
#
# Usage:
#   1. Make this script executable
#      chmod +x generate-secrets.sh
#
#   2. Run it
#      ./generate-secrets.sh
#
#   3. Record the generated passwords (important!)
# ============================================================================

# ----------------------------------------------------------------------------
# Set up
# ----------------------------------------------------------------------------

# Path to the Secrets directory
# This script is intended to be run in the inception/ directory
SECRETS_DIR="secrets"

# Password length
PASSWORD_LENGTH=32

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

generate_password() {
    # openssl rand: generate cryptographically secure random numbers
    # -base64: Base64 encode (includes alphanumeric characters and symbols)

    # Calculate the number of raw bytes
    #  needed to get the required number of Base64 characters
    local bytes=$(( (PASSWORD_LENGTH * 3 + 3) / 4 ))
    # | tr -d '\n': remove the trailing newline
    #   Docker Secrets can cause problems if they contain newlines
    # | head -c ${PASSWORD_LENGTH}: take only the first N characters
    #   Base64 works in blocks of 4 characters,
    #    so the result may be slightly longer than the specified length
    openssl rand -base64 "${bytes}" | tr -d '\n' | head -c "${PASSWORD_LENGTH}"
}

# ----------------------------------------------------------------------------
# Step 1: Create the Secrets directory
# ----------------------------------------------------------------------------

echo -e "${BLUE}=========================================${RESET}"
echo -e "${BLUE}Docker Secrets Generator${RESET}"
echo -e "${BLUE}=========================================${RESET}"
echo ""

echo -e "${BLUE}[1/5] Creating secrets directory...${RESET}"

# Create only if the directory does not exist
if [ ! -d "${SECRETS_DIR}" ]; then
    mkdir "${SECRETS_DIR}"
    echo -e "${GREEN}✓ Directory created: ${SECRETS_DIR}${RESET}"
else
    echo -e "${YELLOW}⚠ Directory already exists: ${SECRETS_DIR}${RESET}"
fi

# Directory permission settings
#  700 = rwx------
#  Only the owner can read, write, and execute (other users cannot access)
chmod 700 "${SECRETS_DIR}"
echo -e "${GREEN}✓ Directory permissions set to 700${RESET}"
echo ""

# ----------------------------------------------------------------------------
# Step 2: Check existing files
# ----------------------------------------------------------------------------
echo -e "${BLUE}[2/5] Checking for existing secrets...${RESET}"

# Check whether an existing secrets file exists
if ls ${SECRETS_DIR}/*.txt 1> /dev/null 2>&1; then
    echo -e "${YELLOW}⚠ Existing secrets found:${RESET}"
    ls -la ${SECRETS_DIR}/*.txt
    echo ""
    echo -e "${RED}WARNING: This will overwrite existing secrets!${RESET}"
    echo -e "${YELLOW}Press Ctrl+C to cancel, or wait 5 seconds to continue...${RESET}"
    # Wait 5 seconds (give the user time to cancel)
    sleep 5
    echo ""
else
    echo -e "${GREEN}✓ No existing secrets found${RESET}"
    echo ""
fi

# ----------------------------------------------------------------------------
# Step 3: Generate MariaDB Secrets
# ----------------------------------------------------------------------------
echo -e "${BLUE}[3/5] Generating MariaDB secrets...${RESET}"

# Password for MariaDB root
DB_ROOT_PASSWORD=$(generate_password)

# Write to a file
# echo -n: do not output a trailing newline (important!)
# Newlines can cause issues with Docker Secrets in some cases
echo -n "${DB_ROOT_PASSWORD}" > "${SECRETS_DIR}/db_root_password.txt"

# File permission settings
# 600 = rw-------
# Only the owner can read and write (not executable; other users have no access)
chmod 600 "${SECRETS_DIR}/db_root_password.txt"

echo -e "${GREEN}✓ Created: db_root_password.txt${RESET}"
echo -e "  Password: ${DB_ROOT_PASSWORD}"
echo ""

# Password for WordPress user
DB_PASSWORD=$(generate_password)
echo -n "${DB_PASSWORD}" > "${SECRETS_DIR}/db_password.txt"
chmod 600 "${SECRETS_DIR}/db_password.txt"

echo -e "${GREEN}✓ Created: db_password.txt${RESET}"
echo -e "  Password: ${DB_PASSWORD}"
echo ""

# ----------------------------------------------------------------------------
# Step 4: Generate WordPress Secrets
# ----------------------------------------------------------------------------
echo -e "${BLUE}[4/5] Generating WordPress secrets...${RESET}"

# WordPress admin password
WP_ADMIN_PASSWORD=$(generate_password)
echo -n "${WP_ADMIN_PASSWORD}" > "${SECRETS_DIR}/wp_admin_password.txt"
chmod 600 "${SECRETS_DIR}/wp_admin_password.txt"
echo -e "${GREEN}✓ Created: wp_admin_password.txt${RESET}"
echo -e "  Password: ${WP_ADMIN_PASSWORD}"
echo ""

# WordPress regular user password
WP_USER_PASSWORD=$(generate_password)
echo -n "${WP_USER_PASSWORD}" > "${SECRETS_DIR}/wp_user_password.txt"
chmod 600 "${SECRETS_DIR}/wp_user_password.txt"
echo -e "${GREEN}✓ Created: wp_user_password.txt${RESET}"
echo -e "  Password: ${WP_USER_PASSWORD}"
echo ""

# ----------------------------------------------------------------------------
# Step 5: Generate FTP Secrets
# ----------------------------------------------------------------------------
echo -e "${BLUE}[5/6] Generating FTP secrets...${RESET}"

# FTP user password
FTP_PASSWORD=$(generate_password)
echo -n "${FTP_PASSWORD}" > "${SECRETS_DIR}/ftp_password.txt"
chmod 600 "${SECRETS_DIR}/ftp_password.txt"
echo -e "${GREEN}✓ Created: ftp_password.txt${RESET}"
echo -e "  Password: ${FTP_PASSWORD}"
echo ""

# ----------------------------------------------------------------------------
# Step 6: Completion
# ----------------------------------------------------------------------------
echo ""
echo -e "${GREEN}=========================================${RESET}"
echo -e "${GREEN}All secrets generated successfully!${RESET}"
echo -e "${GREEN}=========================================${RESET}"
echo ""

# ----------------------------------------------------------------------------
# Important Notes
# ----------------------------------------------------------------------------
echo -e "${YELLOW}IMPORTANT:${RESET}"
echo ""
echo -e "${RED}1. Save these passwords in a secure location!${RESET}"
echo -e "   - DB Root: ${DB_ROOT_PASSWORD}"
echo -e "   - DB User: ${DB_PASSWORD}"
echo -e "   - WP Admin: ${WP_ADMIN_PASSWORD}"
echo -e "   - WP User: ${WP_USER_PASSWORD}"
echo -e "   - FTP User: ${FTP_PASSWORD}"
echo ""
echo -e "${YELLOW}2. These files are ignored by Git (.gitignore)${RESET}"
echo -e "   Make sure secrets/ is in your .gitignore"
echo ""
echo -e "${YELLOW}3. File permissions are set to 600 (owner read/write only)${RESET}"
echo -e "   Do not change these permissions"
echo ""
echo -e "${YELLOW}4. To regenerate secrets, run this script again${RESET}"
echo -e "   Warning: This will invalidate existing database access"
echo ""

# ----------------------------------------------------------------------------
# Check .gitignore
# ----------------------------------------------------------------------------
if [ -f ".gitignore" ]; then
    # .gitignore に secrets が含まれているか確認
    if grep -q "secrets/" .gitignore; then
        echo -e "${GREEN}✓ .gitignore contains secrets exclusion${RESET}"
    else
        echo -e "${RED}⚠ WARNING: secrets/ not found in .gitignore!${RESET}"
        echo -e "${YELLOW}  Add this line to .gitignore:${RESET}"
        echo -e "  ${BLUE}secrets/${RESET}"
    fi
else
    echo -e "${RED}⚠ WARNING: .gitignore not found!${RESET}"
    echo -e "${YELLOW}  Create .gitignore and add:${RESET}"
    echo -e "  ${BLUE}secrets/${RESET}"
fi

echo ""
echo -e "${GREEN}Done!${RESET}"

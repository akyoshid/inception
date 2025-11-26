#!/bin/bash
set -e

echo "========================================="
echo "FTP Server Initialization Script"
echo "========================================="

# ============================================================================
# STEP 1: Read FTP password from Docker Secrets
# ============================================================================
echo "[1/3] Loading FTP credentials..."

FTP_USER="${FTP_USER:-ftpuser}"

if [ -f "/run/secrets/ftp_password" ]; then
    FTP_PASSWORD=$(cat /run/secrets/ftp_password)
    echo "  ✓ Loaded FTP password from secrets"
else
    echo "ERROR: FTP password secret not found" >&2
    exit 1
fi

# ============================================================================
# STEP 2: Create FTP user
# ============================================================================
echo "[2/3] Creating FTP user..."

# Create user if not exists
if ! id "${FTP_USER}" &>/dev/null; then
    useradd -m -d /var/www/html -s /bin/bash "${FTP_USER}"
    echo "  ✓ User '${FTP_USER}' created"
else
    echo "  ✓ User '${FTP_USER}' already exists"
fi

# Set password
echo "${FTP_USER}:${FTP_PASSWORD}" | chpasswd
echo "  ✓ Password set"

# Set ownership of WordPress directory
chown -R "${FTP_USER}:${FTP_USER}" /var/www/html
echo "  ✓ Directory ownership set"

# ============================================================================
# STEP 3: Start vsftpd
# ============================================================================
echo "[3/3] Starting vsftpd..."
echo "========================================="
echo "FTP Server is ready"
echo "  User: ${FTP_USER}"
echo "  Directory: /var/www/html"
echo "========================================="

# Clear password from environment
unset FTP_PASSWORD

# Create log file and redirect to stdout
touch /var/log/vsftpd.log
tail -f /var/log/vsftpd.log &

# Create secure_chroot_dir
# An empty directory required for security purposes
mkdir -p /var/run/vsftpd/empty

exec vsftpd /etc/vsftpd.conf

#!/usr/bin/env python3
"""
Service Monitor for Inception Project
Monitors the health of all infrastructure services.
"""

import subprocess
import socket
from flask import Flask, render_template
from datetime import datetime

app = Flask(__name__)

def check_mariadb():
    """
    Method: Use the mysqladmin ping command
    Success condition: Exit code is 0
    """
    try:
        result = subprocess.run(
            ["mysqladmin", "ping", "-h", "mariadb", "--silent"],
            capture_output=True,
            timeout=5
        )
        return result.returncode == 0
    except Exception:
        return False

def check_redis():
    """
    Method: Use the redis-cli ping command
    Success criterion: The output contains PONG
    """
    try:
        result = subprocess.run(
            ["redis-cli", "-h", "redis", "ping"],
            capture_output=True,
            timeout=5
        )
        return b"PONG" in result.stdout
    except Exception:
        return False

def check_nginx():
    """
    Method: Access via HTTPS using curl
    Success criteria: Exit code is 0
    Option:
      -s: Silent mode (do not show progress)
      -f: Treat HTTP errors as failures
      -k: Skip SSL certificate verification (for self-signed certificates)
      -o /dev/null: Discard output
    """
    try:
        result = subprocess.run(
            ["curl", "-sf", "-k", "https://nginx", "-o", "/dev/null"],
            capture_output=True,
            timeout=5
        )
        return result.returncode == 0
    except Exception:
        return False

def check_wordpress():
    """
    Method: Access wp-login.php via NGINX
    Success criteria: Exit code is 0
    """
    try:
        result = subprocess.run(
            ["curl", "-sf", "-k", "https://nginx/wp-login.php", "-o", "/dev/null"],
            capture_output=True,
            timeout=5
        )
        return result.returncode == 0
    except Exception:
        return False

def check_ftp():
    """
    Method: Attempt to connect to port 21 using a socket
    Success criteria:
        Connection succeeds and an FTP banner starting with 220 is received
    Note:
        Use a direct socket connection
        because checking FTP with curl is unstable due to authentication issues
    """
    try:
        # Create a socket
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(3)
        
        # Connect to the FTP server
        sock.connect(("ftp", 21))
        
        # Received FTP banner (example: "220 (vsFTPd 3.0.3)\r\n")
        banner = sock.recv(1024).decode()
        
        # Close the socket
        sock.close()
        
        # If the banner starts with "220", it's successful  
        # 220 = Service ready (standard FTP response code)
        return banner.startswith("220")
    except Exception:
        return False

def check_adminer():
    """
    Method: Access via HTTP with curl
    Success criteria: Exit code is 0
    """
    try:
        result = subprocess.run(
            ["curl", "-sf", "http://adminer:8080/adminer.php", "-o", "/dev/null"],
            capture_output=True,
            timeout=5
        )
        return result.returncode == 0
    except Exception:
        return False


def check_static_site():
    """
    Method: HTTP access with curl
    Success criteria: exit code is 0
    """
    try:
        result = subprocess.run(
            ["curl", "-sf", "http://static-site:8082", "-o", "/dev/null"],
            capture_output=True,
            timeout=5
        )
        return result.returncode == 0
    except Exception:
        return False

@app.route("/")
def index():
    # Check each service and store it in the dictionary
    services = {
        "MariaDB": check_mariadb(),
        "Redis": check_redis(),
        "NGINX": check_nginx(),
        "WordPress": check_wordpress(),
        "FTP": check_ftp(),
        "Adminer": check_adminer(),
        "Static Site": check_static_site(),
    }
    
    # Get the current time
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    # Render the template
    return render_template("index.html", services=services, timestamp=timestamp)

@app.route("/health")
def health():
    """Simple health check endpoint."""
    return "OK", 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8083)

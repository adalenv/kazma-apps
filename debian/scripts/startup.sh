#!/bin/bash
# =============================================================================
# KAZMA Desktop Container Startup Script
# =============================================================================
# This script initializes the desktop environment and starts services
# =============================================================================

set -e

echo "=========================================="
echo "KAZMA Desktop Container Starting"
echo "=========================================="

# -----------------------------------------------------------------------------
# Validate Environment
# -----------------------------------------------------------------------------
if [ -z "$DESKTOP_USER" ]; then
    echo "ERROR: DESKTOP_USER environment variable not set"
    exit 1
fi

# Support both DESKTOP_PASSWORD and DESKTOP_PASS for compatibility
DESKTOP_PASS="${DESKTOP_PASSWORD:-$DESKTOP_PASS}"

if [ -z "$DESKTOP_PASS" ]; then
    echo "ERROR: DESKTOP_PASSWORD environment variable not set"
    exit 1
fi

echo "Configuring user: $DESKTOP_USER"

# -----------------------------------------------------------------------------
# Configure User Password
# -----------------------------------------------------------------------------
# Write password directly to shadow file (works without CAP_CHOWN)
# Generate SHA-512 encrypted password
ENCRYPTED_PASS=$(openssl passwd -6 "$DESKTOP_PASS")

# Update shadow file directly
if [ -w /etc/shadow ]; then
    sed -i "s|^${DESKTOP_USER}:[^:]*:|${DESKTOP_USER}:${ENCRYPTED_PASS}:|" /etc/shadow
    echo "User password configured via shadow"
else
    # If shadow is not writable, try using a temp copy
    cp /etc/shadow /tmp/shadow.tmp
    sed -i "s|^${DESKTOP_USER}:[^:]*:|${DESKTOP_USER}:${ENCRYPTED_PASS}:|" /tmp/shadow.tmp
    cat /tmp/shadow.tmp > /etc/shadow 2>/dev/null || {
        echo "WARNING: Could not update password, using default"
    }
    rm -f /tmp/shadow.tmp
fi
echo "User configuration complete"

# -----------------------------------------------------------------------------
# Create Required Directories
# -----------------------------------------------------------------------------
mkdir -p /var/run/xrdp
mkdir -p /var/log/supervisor
mkdir -p /var/log/xrdp
chmod 755 /var/log/xrdp
mkdir -p /run/user/$(id -u $DESKTOP_USER)
chmod 700 /run/user/$(id -u $DESKTOP_USER)
chown $DESKTOP_USER:$DESKTOP_USER /run/user/$(id -u $DESKTOP_USER)

# -----------------------------------------------------------------------------
# Initialize User Home Directory (supports persistent storage)
# -----------------------------------------------------------------------------
USER_HOME="/home/$DESKTOP_USER"

# Check if user home directory exists (persistent volume may mount empty /home)
if [ ! -d "$USER_HOME" ]; then
    echo "Creating user home directory (persistent storage)..."
    mkdir -p "$USER_HOME"
fi

# Check if home directory is empty (persistent volume mounted but not initialized)
if [ -z "$(ls -A $USER_HOME 2>/dev/null)" ]; then
    echo "Initializing empty home directory (persistent storage)..."
    # Copy skeleton files
    cp -a /etc/skel/. "$USER_HOME/" 2>/dev/null || true
fi

# Create required directories
mkdir -p "$USER_HOME/.config/xfce4/xfconf/xfce-perchannel-xml" 2>/dev/null || true
mkdir -p "$USER_HOME/.cache" 2>/dev/null || true
mkdir -p "$USER_HOME/.local/share" 2>/dev/null || true
mkdir -p "$USER_HOME/Desktop" 2>/dev/null || true
mkdir -p "$USER_HOME/Documents" 2>/dev/null || true
mkdir -p "$USER_HOME/Downloads" 2>/dev/null || true

# Set proper ownership
chown -R $DESKTOP_USER:$DESKTOP_USER "$USER_HOME" 2>/dev/null || true

echo "User home directory initialized"

# -----------------------------------------------------------------------------
# Initialize /usr/local (for user-installed apps - persistent storage)
# -----------------------------------------------------------------------------
if [ -z "$(ls -A /usr/local 2>/dev/null)" ]; then
    echo "Initializing /usr/local for user-installed apps..."
    mkdir -p /usr/local/bin /usr/local/lib /usr/local/share /usr/local/include 2>/dev/null || true
fi

# -----------------------------------------------------------------------------
# Initialize /opt (for optional software - persistent storage)
# -----------------------------------------------------------------------------
if [ -z "$(ls -A /opt 2>/dev/null)" ]; then
    echo "Initializing /opt for optional software..."
    mkdir -p /opt 2>/dev/null || true
fi

# -----------------------------------------------------------------------------
# Generate Machine ID (required for D-Bus)
# -----------------------------------------------------------------------------
if [ ! -f /etc/machine-id ]; then
    dbus-uuidgen > /etc/machine-id
fi

# -----------------------------------------------------------------------------
# Clean Up Stale Files
# -----------------------------------------------------------------------------
rm -f /var/run/xrdp/*.pid 2>/dev/null || true
rm -f /var/run/xrdp-sesman.pid 2>/dev/null || true

# -----------------------------------------------------------------------------
# Start Services via Supervisor
# -----------------------------------------------------------------------------
echo "Starting XRDP services..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf


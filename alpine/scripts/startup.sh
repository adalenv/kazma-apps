#!/bin/bash
set -e

DESKTOP_USER="${DESKTOP_USER:-desktop}"
DESKTOP_PASSWORD="${DESKTOP_PASSWORD:-desktop}"
USER_HOME="/home/$DESKTOP_USER"

echo "=== Kazma Alpine Desktop Starting ==="

# -----------------------------------------------------------------------------
# Initialize Mounted Directories from Skeleton
# -----------------------------------------------------------------------------
# When bind mounts are used, directories may be empty. Initialize from skeleton.

# Initialize /home if empty (bind mount)
if [ -z "$(ls -A /home 2>/dev/null)" ]; then
    echo "Initializing /home from skeleton..."
    cp -a /kazma/skel/home/. /home/ 2>/dev/null || true
fi

# Initialize /usr/local if empty (bind mount)
if [ -z "$(ls -A /usr/local 2>/dev/null)" ]; then
    echo "Initializing /usr/local from skeleton..."
    cp -a /kazma/skel/usr/local/. /usr/local/ 2>/dev/null || true
fi

# Initialize /opt if empty (bind mount)
if [ -z "$(ls -A /opt 2>/dev/null)" ]; then
    echo "Initializing /opt from skeleton..."
    cp -a /kazma/skel/opt/. /opt/ 2>/dev/null || true
fi

# Set user password
echo "$DESKTOP_USER:$DESKTOP_PASSWORD" | chpasswd

# Ensure system directories exist
mkdir -p /var/run/xrdp /run/dbus /var/log

# -----------------------------------------------------------------------------
# Initialize User Home Directory (supports persistent storage)
# -----------------------------------------------------------------------------
# Check if user home directory exists (persistent volume may mount empty /home)
if [ ! -d "$USER_HOME" ]; then
    echo "Creating user home directory..."
    mkdir -p "$USER_HOME"
fi

# Check if home directory is empty (persistent volume mounted but not initialized)
if [ -z "$(ls -A $USER_HOME 2>/dev/null)" ]; then
    echo "Initializing empty home directory..."
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

# Start dbus
if [ ! -f /run/dbus/pid ]; then
    dbus-daemon --system --fork
fi

echo "Starting XRDP services..."
exec /usr/bin/supervisord -c /etc/supervisord.conf

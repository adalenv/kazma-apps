#!/bin/bash
set -e

DESKTOP_USER="${DESKTOP_USER:-desktop}"
DESKTOP_PASSWORD="${DESKTOP_PASSWORD:-desktop}"
USER_HOME="/home/$DESKTOP_USER"

echo "=== Kazma Development Desktop Starting ==="

# Set user password
echo "$DESKTOP_USER:$DESKTOP_PASSWORD" | chpasswd

# Ensure system directories exist
mkdir -p /var/run/xrdp /run/dbus /var/log/supervisor

# -----------------------------------------------------------------------------
# Initialize User Home Directory (supports persistent storage)
# -----------------------------------------------------------------------------
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
mkdir -p "$USER_HOME/Projects" 2>/dev/null || true

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

# Start dbus
if [ ! -f /run/dbus/pid ]; then
    dbus-daemon --system --fork
fi

echo "Starting XRDP services..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf


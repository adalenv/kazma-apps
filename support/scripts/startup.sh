#!/bin/bash
set -e

DESKTOP_USER="${DESKTOP_USER:-desktop}"
DESKTOP_PASSWORD="${DESKTOP_PASSWORD:-desktop}"
USER_HOME="/home/$DESKTOP_USER"

echo "=== Kazma Support Desktop Starting ==="

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

# -----------------------------------------------------------------------------
# Initialize app config directories for persistence
# These directories store app data that should persist between sessions
# -----------------------------------------------------------------------------

# Google Chrome config directory
mkdir -p "$USER_HOME/.config/google-chrome" 2>/dev/null || true

# AnyDesk config directory
mkdir -p "$USER_HOME/.anydesk" 2>/dev/null || true

# -----------------------------------------------------------------------------
# Copy desktop shortcuts if not present
# -----------------------------------------------------------------------------
if [ ! -f "$USER_HOME/Desktop/google-chrome.desktop" ]; then
    cp /etc/skel/Desktop/google-chrome.desktop "$USER_HOME/Desktop/" 2>/dev/null || true
fi
if [ ! -f "$USER_HOME/Desktop/anydesk.desktop" ]; then
    cp /etc/skel/Desktop/anydesk.desktop "$USER_HOME/Desktop/" 2>/dev/null || true
fi

# Make desktop shortcuts executable
chmod +x "$USER_HOME/Desktop/"*.desktop 2>/dev/null || true

# Set proper ownership
chown -R $DESKTOP_USER:$DESKTOP_USER "$USER_HOME" 2>/dev/null || true

echo "User home directory initialized with app configs"

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

# -----------------------------------------------------------------------------
# Start PulseAudio for audio support with XRDP modules
# -----------------------------------------------------------------------------
echo "Setting up PulseAudio with XRDP audio support..."
mkdir -p /run/user/1000/pulse
mkdir -p "$USER_HOME/.config/pulse"
chown -R $DESKTOP_USER:$DESKTOP_USER /run/user/1000 2>/dev/null || true
chown -R $DESKTOP_USER:$DESKTOP_USER "$USER_HOME/.config/pulse" 2>/dev/null || true

# Create autostart script to load XRDP audio modules when desktop starts
mkdir -p "$USER_HOME/.config/autostart"
cat > "$USER_HOME/.config/autostart/load-xrdp-audio.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Load XRDP Audio
Exec=/usr/local/bin/load-xrdp-audio.sh
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
EOF
chown $DESKTOP_USER:$DESKTOP_USER "$USER_HOME/.config/autostart/load-xrdp-audio.desktop"

# Create the audio loading script
cat > /usr/local/bin/load-xrdp-audio.sh << 'SCRIPT'
#!/bin/bash
# Wait for XRDP to be fully ready
sleep 3

# Find the display number
displaynum=${DISPLAY##*:}
displaynum=${displaynum%.*}

# Socket paths
XRDP_SOCKET_PATH=/var/run/xrdp/sockdir
SINK_SOCKET="xrdp_chansrv_audio_out_socket_$displaynum"
SOURCE_SOCKET="xrdp_chansrv_audio_in_socket_$displaynum"

# Check if sockets exist
if [ -S "$XRDP_SOCKET_PATH/$SINK_SOCKET" ]; then
    # Unload existing modules
    pactl unload-module module-xrdp-sink 2>/dev/null || true
    pactl unload-module module-xrdp-source 2>/dev/null || true
    
    # Load XRDP sink
    if pactl load-module module-xrdp-sink xrdp_socket_path=$XRDP_SOCKET_PATH xrdp_pulse_sink_socket=$SINK_SOCKET; then
        pacmd set-default-sink xrdp-sink 2>/dev/null || true
        echo "XRDP audio sink loaded"
    fi
    
    # Load XRDP source
    if pactl load-module module-xrdp-source xrdp_socket_path=$XRDP_SOCKET_PATH xrdp_pulse_source_socket=$SOURCE_SOCKET; then
        pacmd set-default-source xrdp-source 2>/dev/null || true
        echo "XRDP audio source loaded"
    fi
fi
SCRIPT
chmod +x /usr/local/bin/load-xrdp-audio.sh

# Start PulseAudio as the desktop user
su - $DESKTOP_USER -c "pulseaudio --start --exit-idle-time=-1 --daemonize" 2>/dev/null || true

echo "Starting XRDP services..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf


# =============================================================================
# KAZMA Desktop Container
# =============================================================================
# Debian 12 (Bookworm) with Xfce4 desktop environment and XRDP
# Designed for security, minimal footprint, and fast startup
# =============================================================================

FROM debian:12-slim

# Build arguments
ARG DEBIAN_FRONTEND=noninteractive
ARG DESKTOP_USER=desktop
ARG DESKTOP_UID=1000

# Labels for container identification
LABEL org.opencontainers.image.title="KAZMA Desktop"
LABEL org.opencontainers.image.description="Isolated Linux desktop with Xfce and XRDP"
LABEL org.opencontainers.image.vendor="KAZMA"
LABEL kazma.type="desktop"

# =============================================================================
# System Setup
# =============================================================================

# Install required packages in a single layer to minimize image size
RUN apt-get update && apt-get install -y --no-install-recommends \
    # X11 and display
    xorg \
    dbus-x11 \
    x11-xserver-utils \
    # Xfce desktop environment (minimal)
    xfce4 \
    xfce4-terminal \
    xfce4-settings \
    # XRDP for remote desktop
    xrdp \
    xorgxrdp \
    # Essential utilities
    sudo \
    wget \
    curl \
    ca-certificates \
    locales \
    openssl \
    # Fonts
    fonts-dejavu-core \
    fonts-liberation \
    # Icons and themes
    adwaita-icon-theme \
    tango-icon-theme \
    papirus-icon-theme \
    # Process management
    supervisor \
    # Network utilities (for health checks)
    netcat-openbsd \
    # Clean up
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    # Generate locales
    && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
    && locale-gen en_US.UTF-8

# Set locale
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# =============================================================================
# User Setup
# =============================================================================

# Create non-root user with sudo access (password set at runtime)
RUN useradd -m -s /bin/bash -u ${DESKTOP_UID} ${DESKTOP_USER} \
    && echo "${DESKTOP_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${DESKTOP_USER} \
    && chmod 0440 /etc/sudoers.d/${DESKTOP_USER}

# =============================================================================
# XRDP Configuration
# =============================================================================

# Configure XRDP - simple RDP mode (most compatible with Guacamole)
RUN sed -i 's/^port=3389/port=3389/' /etc/xrdp/xrdp.ini \
    # Security settings - use classic RDP encryption
    && sed -i 's/^security_layer=.*/security_layer=rdp/' /etc/xrdp/xrdp.ini \
    && sed -i 's/^crypt_level=.*/crypt_level=low/' /etc/xrdp/xrdp.ini \
    # Clear certificate settings (not needed for RDP mode)
    && sed -i 's|^certificate=.*|certificate=|' /etc/xrdp/xrdp.ini \
    && sed -i 's|^key_file=.*|key_file=|' /etc/xrdp/xrdp.ini \
    # Session settings
    && sed -i 's/^max_bpp=.*/max_bpp=24/' /etc/xrdp/xrdp.ini \
    && sed -i 's/^xserverbpp=.*/xserverbpp=24/' /etc/xrdp/xrdp.ini \
    # Performance tuning
    && sed -i 's/^#tcp_nodelay=true/tcp_nodelay=true/' /etc/xrdp/xrdp.ini \
    && sed -i 's/^#tcp_keepalive=true/tcp_keepalive=true/' /etc/xrdp/xrdp.ini \
    # Fix log file paths
    && sed -i 's|^LogFile=xrdp.log|LogFile=/var/log/xrdp/xrdp.log|' /etc/xrdp/xrdp.ini \
    && sed -i 's|^LogFile=xrdp-sesman.log|LogFile=/var/log/xrdp/xrdp-sesman.log|' /etc/xrdp/sesman.ini \
    && mkdir -p /var/log/xrdp \
    && chmod 777 /var/log/xrdp \
    # Generate RSA keys for XRDP
    && xrdp-keygen xrdp auto \
    && chmod 644 /etc/xrdp/rsakeys.ini \
    # Allow XRDP to start without systemd
    && mkdir -p /var/run/xrdp \
    && chmod 755 /var/run/xrdp

# =============================================================================
# Xfce Configuration
# =============================================================================

# Create Xfce session startup script
COPY config/startwm.sh /etc/xrdp/startwm.sh
RUN chmod +x /etc/xrdp/startwm.sh

# Set default Xfce settings with proper icon theme
RUN mkdir -p /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml \
    && echo '<?xml version="1.0" encoding="UTF-8"?>' > /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml \
    && echo '<channel name="xsettings" version="1.0">' >> /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml \
    && echo '  <property name="Net" type="empty">' >> /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml \
    && echo '    <property name="IconThemeName" type="string" value="Papirus"/>' >> /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml \
    && echo '    <property name="ThemeName" type="string" value="Adwaita"/>' >> /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml \
    && echo '  </property>' >> /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml \
    && echo '</channel>' >> /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml \
    # Update icon cache
    && gtk-update-icon-cache /usr/share/icons/Papirus 2>/dev/null || true \
    && gtk-update-icon-cache /usr/share/icons/Adwaita 2>/dev/null || true

# =============================================================================
# Supervisor Configuration
# =============================================================================

COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# =============================================================================
# Skeleton Backup for Bind Mounts
# =============================================================================

# Create backup of directories that will be mounted
# These are used to initialize empty bind mounts
RUN mkdir -p /kazma/skel \
    && cp -a /home /kazma/skel/ \
    && cp -a /usr/local /kazma/skel/ \
    && cp -a /opt /kazma/skel/

# =============================================================================
# Startup Scripts
# =============================================================================

# Startup script - placed in /kazma which won't be mounted over
COPY scripts/startup.sh /kazma/startup.sh
COPY scripts/configure-user.sh /kazma/configure-user.sh
RUN chmod +x /kazma/startup.sh /kazma/configure-user.sh

# =============================================================================
# Health Check
# =============================================================================

HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=3 \
    CMD nc -z localhost 3389 || exit 1

# =============================================================================
# Runtime Configuration
# =============================================================================

# Expose RDP port
EXPOSE 3389

# Environment variables (set at runtime)
ENV DESKTOP_USER=${DESKTOP_USER}
ENV DESKTOP_PASS=""

# Working directory
WORKDIR /home/${DESKTOP_USER}

# Entry point
ENTRYPOINT ["/kazma/startup.sh"]


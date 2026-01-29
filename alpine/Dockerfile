# =============================================================================
# Kazma Alpine Desktop - Lightweight
# =============================================================================
# Ultra-lightweight desktop based on Alpine Linux with XFCE
# ~200MB image size, fast startup
# =============================================================================

FROM alpine:3.19

LABEL maintainer="Kazma <admin@kazma.cloud>"
LABEL description="Lightweight Alpine Linux desktop with XFCE"

# Install XFCE, XRDP and essential packages
RUN apk add --no-cache \
    # X11 and display
    xvfb \
    x11vnc \
    dbus \
    dbus-x11 \
    # XFCE desktop
    xfce4 \
    xfce4-terminal \
    xfce4-screensaver \
    # Icons and themes
    adwaita-icon-theme \
    papirus-icon-theme \
    ttf-dejavu \
    # XRDP with Xvnc support
    xrdp \
    tigervnc \
    # Utilities
    bash \
    sudo \
    shadow \
    openssl \
    curl \
    wget \
    nano \
    htop \
    net-tools \
    # Supervisor
    supervisor \
    && rm -rf /var/cache/apk/*

# Create desktop user
RUN adduser -D -s /bin/bash -h /home/desktop desktop \
    && echo "desktop ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Configure XRDP - simple RDP mode (most compatible with Guacamole)
RUN sed -i 's/^security_layer=.*/security_layer=rdp/' /etc/xrdp/xrdp.ini \
    && sed -i 's/^crypt_level=.*/crypt_level=low/' /etc/xrdp/xrdp.ini \
    && sed -i 's/^certificate=.*/certificate=/' /etc/xrdp/xrdp.ini \
    && sed -i 's/^key_file=.*/key_file=/' /etc/xrdp/xrdp.ini \
    && sed -i 's/^#tcp_nodelay=.*/tcp_nodelay=true/' /etc/xrdp/xrdp.ini \
    && sed -i 's/^#tcp_keepalive=.*/tcp_keepalive=true/' /etc/xrdp/xrdp.ini \
    # Set Xvnc as the default session type
    && sed -i 's/^autorun=.*/autorun=Xvnc/' /etc/xrdp/xrdp.ini \
    # Configure sesman to use Xvnc
    && sed -i 's/^AllowRootLogin=.*/AllowRootLogin=false/' /etc/xrdp/sesman.ini \
    && sed -i 's/^MaxLoginRetry=.*/MaxLoginRetry=4/' /etc/xrdp/sesman.ini \
    # Configure Xvnc path in sesman
    && sed -i 's|^param=Xvnc|param=/usr/bin/Xvnc|' /etc/xrdp/sesman.ini

# Create startwm.sh
RUN mkdir -p /etc/xrdp \
    && echo '#!/bin/bash' > /etc/xrdp/startwm.sh \
    && echo 'export XDG_SESSION_TYPE=x11' >> /etc/xrdp/startwm.sh \
    && echo 'export XDG_CURRENT_DESKTOP=XFCE' >> /etc/xrdp/startwm.sh \
    && echo 'exec startxfce4' >> /etc/xrdp/startwm.sh \
    && chmod +x /etc/xrdp/startwm.sh

# Set default XFCE settings with proper icon theme
RUN mkdir -p /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml \
    && echo '<?xml version="1.0" encoding="UTF-8"?>' > /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml \
    && echo '<channel name="xsettings" version="1.0">' >> /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml \
    && echo '  <property name="Net" type="empty">' >> /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml \
    && echo '    <property name="IconThemeName" type="string" value="Papirus"/>' >> /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml \
    && echo '    <property name="ThemeName" type="string" value="Adwaita"/>' >> /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml \
    && echo '  </property>' >> /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml \
    && echo '</channel>' >> /etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml

# Supervisor config
RUN mkdir -p /etc/supervisor.d \
    && echo '[supervisord]' > /etc/supervisord.conf \
    && echo 'nodaemon=true' >> /etc/supervisord.conf \
    && echo 'logfile=/var/log/supervisord.log' >> /etc/supervisord.conf \
    && echo '' >> /etc/supervisord.conf \
    && echo '[program:xrdp-sesman]' >> /etc/supervisord.conf \
    && echo 'command=/usr/sbin/xrdp-sesman --nodaemon' >> /etc/supervisord.conf \
    && echo 'autorestart=true' >> /etc/supervisord.conf \
    && echo 'priority=100' >> /etc/supervisord.conf \
    && echo '' >> /etc/supervisord.conf \
    && echo '[program:xrdp]' >> /etc/supervisord.conf \
    && echo 'command=/usr/sbin/xrdp --nodaemon' >> /etc/supervisord.conf \
    && echo 'autorestart=true' >> /etc/supervisord.conf \
    && echo 'priority=200' >> /etc/supervisord.conf

# Create backup of directories that will be mounted
# These are used to initialize empty bind mounts
RUN mkdir -p /kazma/skel \
    && cp -a /home /kazma/skel/ \
    && cp -a /usr/local /kazma/skel/ \
    && cp -a /opt /kazma/skel/

# Startup script - placed in /kazma which won't be mounted over
COPY scripts/startup.sh /kazma/startup.sh
RUN chmod +x /kazma/startup.sh

# Create necessary directories
RUN mkdir -p /var/log /var/run/xrdp /run/dbus \
    && chown -R desktop:desktop /home/desktop

EXPOSE 3389

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD netstat -ln | grep -q ':3389' || exit 1

ENTRYPOINT ["/kazma/startup.sh"]


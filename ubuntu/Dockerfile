# =============================================================================
# Kazma Ubuntu Desktop
# =============================================================================
# Ubuntu 22.04 with XFCE desktop environment
# =============================================================================

FROM ubuntu:22.04

LABEL maintainer="Kazma <info@kazma.cloud>"
LABEL description="Ubuntu 22.04 desktop with XFCE"

ENV DEBIAN_FRONTEND=noninteractive

# Install XFCE, XRDP and essential packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    # X11 and display
    xorg \
    dbus-x11 \
    x11-xserver-utils \
    # XFCE desktop
    xfce4 \
    xfce4-terminal \
    xfce4-goodies \
    # XRDP
    xrdp \
    xorgxrdp \
    # Utilities
    sudo \
    curl \
    wget \
    nano \
    vim \
    htop \
    net-tools \
    iputils-ping \
    ca-certificates \
    locales \
    # Fonts
    fonts-dejavu \
    fonts-liberation \
    # Icons and themes
    adwaita-icon-theme \
    gnome-icon-theme \
    tango-icon-theme \
    papirus-icon-theme \
    # Audio (optional)
    pulseaudio \
    # Supervisor
    supervisor \
    # VPN and firewall support
    wireguard-tools \
    iproute2 \
    iptables \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set locale
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8

# Create desktop user
RUN useradd -m -s /bin/bash -G sudo desktop \
    && echo "desktop ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Configure XRDP - simple RDP mode (most compatible with Guacamole)
RUN sed -i 's/^port=3389/port=3389/' /etc/xrdp/xrdp.ini \
    && sed -i 's/^security_layer=.*/security_layer=rdp/' /etc/xrdp/xrdp.ini \
    && sed -i 's/^crypt_level=.*/crypt_level=low/' /etc/xrdp/xrdp.ini \
    && sed -i 's/^certificate=.*/certificate=/' /etc/xrdp/xrdp.ini \
    && sed -i 's/^key_file=.*/key_file=/' /etc/xrdp/xrdp.ini \
    && sed -i 's/^max_bpp=.*/max_bpp=24/' /etc/xrdp/xrdp.ini

# Configure sesman
RUN sed -i 's/^AllowRootLogin=.*/AllowRootLogin=false/' /etc/xrdp/sesman.ini \
    && sed -i 's/^MaxLoginRetry=.*/MaxLoginRetry=4/' /etc/xrdp/sesman.ini

# Create startwm.sh
RUN echo '#!/bin/bash' > /etc/xrdp/startwm.sh \
    && echo 'unset DBUS_SESSION_BUS_ADDRESS' >> /etc/xrdp/startwm.sh \
    && echo 'unset XDG_RUNTIME_DIR' >> /etc/xrdp/startwm.sh \
    && echo 'export XDG_SESSION_TYPE=x11' >> /etc/xrdp/startwm.sh \
    && echo 'export XDG_CURRENT_DESKTOP=XFCE' >> /etc/xrdp/startwm.sh \
    && echo 'exec startxfce4' >> /etc/xrdp/startwm.sh \
    && chmod +x /etc/xrdp/startwm.sh

# Supervisor config
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Create backup of directories that will be mounted
# These are used to initialize empty bind mounts
RUN mkdir -p /kazma/skel \
    && cp -a /home /kazma/skel/ \
    && cp -a /usr/local /kazma/skel/ \
    && cp -a /opt /kazma/skel/

# Startup scripts - placed in /kazma which won't be mounted over
COPY scripts/startup.sh /kazma/startup.sh
COPY scripts/proxy-setup.sh /kazma/proxy-setup.sh
RUN chmod +x /kazma/startup.sh /kazma/proxy-setup.sh

# Set up default XFCE settings with proper icon theme
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

# Create necessary directories and fix permissions
RUN mkdir -p /var/run/xrdp /run/dbus \
    && chmod 755 /var/run/xrdp \
    # Fix XRDP log file permissions (Ubuntu creates them with restrictive perms)
    && rm -f /var/log/xrdp.log /var/log/xrdp-sesman.log \
    && touch /var/log/xrdp.log /var/log/xrdp-sesman.log \
    && chmod 666 /var/log/xrdp.log /var/log/xrdp-sesman.log \
    # Fix rsakeys.ini permissions
    && chmod 644 /etc/xrdp/rsakeys.ini \
    && chown -R desktop:desktop /home/desktop

EXPOSE 3389

HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD netstat -ln | grep -q ':3389' || exit 1

ENTRYPOINT ["/kazma/startup.sh"]


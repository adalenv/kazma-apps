# =============================================================================
# Kazma Support Desktop
# =============================================================================
# Ubuntu 22.04 with XFCE, Google Chrome, and AnyDesk
# Optimized for remote support with persistent app data
# =============================================================================

FROM ubuntu:22.04

LABEL maintainer="Kazma <admin@kazma.local>"
LABEL description="Ubuntu 22.04 desktop with Chrome and AnyDesk for remote support"

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
    gnupg \
    software-properties-common \
    apt-transport-https \
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
    # Dependencies for Chrome/AnyDesk
    libxss1 \
    libappindicator3-1 \
    libindicator3-7 \
    libasound2 \
    libatk-bridge2.0-0 \
    libgtk-3-0 \
    libgbm1 \
    libnss3 \
    libxkbcommon0 \
    xdg-utils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# Install Google Chrome
# =============================================================================
RUN wget -q -O /tmp/google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt-get update \
    && apt-get install -y /tmp/google-chrome.deb \
    && rm /tmp/google-chrome.deb \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# Install AnyDesk
# =============================================================================
RUN wget -qO - https://keys.anydesk.com/repos/DEB-GPG-KEY | gpg --dearmor -o /usr/share/keyrings/anydesk-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/anydesk-archive-keyring.gpg] http://deb.anydesk.com/ all main" > /etc/apt/sources.list.d/anydesk-stable.list \
    && apt-get update \
    && apt-get install -y anydesk \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set locale
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8

# Create desktop user
RUN useradd -m -s /bin/bash -G sudo desktop \
    && echo "desktop ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# =============================================================================
# Build and install PulseAudio XRDP module for audio over RDP
# =============================================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential dpkg-dev libpulse-dev git autoconf automake libtool pkg-config m4 lsb-release \
    && cd /tmp \
    && git clone --depth 1 https://github.com/neutrinolabs/pulseaudio-module-xrdp.git \
    && cd pulseaudio-module-xrdp \
    && chmod +x scripts/*.sh \
    && scripts/install_pulseaudio_sources_apt.sh -d /tmp/pulseaudio.src \
    && ./bootstrap \
    && ./configure PULSE_DIR=/tmp/pulseaudio.src \
    && make \
    && make install \
    && cd / \
    && rm -rf /tmp/pulseaudio-module-xrdp /tmp/pulseaudio.src /tmp/pulseaudio*.dsc /tmp/pulseaudio*.tar.xz \
    && apt-get purge -y build-essential dpkg-dev libpulse-dev git autoconf automake libtool pkg-config m4 \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

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

# Startup script - placed in /kazma which won't be mounted over
COPY scripts/startup.sh /kazma/startup.sh
RUN chmod +x /kazma/startup.sh

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

# =============================================================================
# Create desktop shortcuts for apps
# =============================================================================
RUN mkdir -p /etc/skel/Desktop \
    # Chrome shortcut - with all necessary flags for container environment
    && echo '[Desktop Entry]' > /etc/skel/Desktop/google-chrome.desktop \
    && echo 'Version=1.0' >> /etc/skel/Desktop/google-chrome.desktop \
    && echo 'Name=Google Chrome' >> /etc/skel/Desktop/google-chrome.desktop \
    && echo 'Comment=Access the Internet' >> /etc/skel/Desktop/google-chrome.desktop \
    && echo 'Exec=/usr/bin/google-chrome-stable --no-sandbox --disable-gpu --disable-software-rasterizer --disable-dev-shm-usage %U' >> /etc/skel/Desktop/google-chrome.desktop \
    && echo 'StartupNotify=true' >> /etc/skel/Desktop/google-chrome.desktop \
    && echo 'Terminal=false' >> /etc/skel/Desktop/google-chrome.desktop \
    && echo 'Icon=google-chrome' >> /etc/skel/Desktop/google-chrome.desktop \
    && echo 'Type=Application' >> /etc/skel/Desktop/google-chrome.desktop \
    && echo 'Categories=Network;WebBrowser;' >> /etc/skel/Desktop/google-chrome.desktop \
    && chmod +x /etc/skel/Desktop/google-chrome.desktop \
    # AnyDesk shortcut
    && cp /usr/share/applications/anydesk.desktop /etc/skel/Desktop/ 2>/dev/null || true \
    && chmod +x /etc/skel/Desktop/anydesk.desktop 2>/dev/null || true

# Create necessary directories and fix permissions
RUN mkdir -p /var/run/xrdp /run/dbus /run/user/1000/pulse \
    && chmod 755 /var/run/xrdp \
    # Fix XRDP log file permissions
    && rm -f /var/log/xrdp.log /var/log/xrdp-sesman.log \
    && touch /var/log/xrdp.log /var/log/xrdp-sesman.log \
    && chmod 666 /var/log/xrdp.log /var/log/xrdp-sesman.log \
    # Fix rsakeys.ini permissions
    && chmod 644 /etc/xrdp/rsakeys.ini \
    # PulseAudio setup
    && chown -R desktop:desktop /run/user/1000 \
    && chown -R desktop:desktop /home/desktop

EXPOSE 3389

HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD netstat -ln | grep -q ':3389' || exit 1

ENTRYPOINT ["/kazma/startup.sh"]

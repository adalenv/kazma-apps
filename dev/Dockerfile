# =============================================================================
# Kazma Development Desktop
# =============================================================================
# Debian 12 with XFCE and development tools
# Includes: Node.js, Python, Git, VS Code, Docker CLI
# =============================================================================

FROM debian:12-slim

LABEL maintainer="Kazma <info@kazma.cloud>"
LABEL description="Development desktop with Node.js, Python, Git"

ENV DEBIAN_FRONTEND=noninteractive

# Install base packages
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
    # Core utilities
    sudo \
    curl \
    wget \
    nano \
    vim \
    htop \
    net-tools \
    iputils-ping \
    ca-certificates \
    gnupg \
    lsb-release \
    locales \
    # Development essentials
    git \
    build-essential \
    pkg-config \
    # Python
    python3 \
    python3-pip \
    python3-venv \
    # Fonts
    fonts-dejavu \
    fonts-liberation \
    # Supervisor
    supervisor \
    # VPN support
    wireguard-tools \
    iproute2 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 20 LTS
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g npm@latest \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Docker CLI (for docker-in-docker or socket mounting)
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y docker-ce-cli \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8

# Create desktop user with docker group
RUN useradd -m -s /bin/bash -G sudo desktop \
    && echo "desktop ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && groupadd -f docker \
    && usermod -aG docker desktop

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

# Create necessary directories
RUN mkdir -p /var/run/xrdp /run/dbus /var/log/supervisor \
    && chown -R desktop:desktop /home/desktop

# Set up default dev environment for user
USER desktop
WORKDIR /home/desktop
RUN mkdir -p projects .config \
    && git config --global init.defaultBranch main \
    && echo 'export PATH="$HOME/.local/bin:$PATH"' >> .bashrc
USER root

EXPOSE 3389

HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD netstat -ln | grep -q ':3389' || exit 1

ENTRYPOINT ["/kazma/startup.sh"]


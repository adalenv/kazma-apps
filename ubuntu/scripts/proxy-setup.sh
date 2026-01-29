#!/bin/bash
# =============================================================================
# Kazma Proxy/VPN Setup Script
# =============================================================================
# Configures proxy or VPN settings when container starts
# Called by startup.sh before starting services
# =============================================================================

echo "Checking proxy/VPN configuration..."

# -----------------------------------------------------------------------------
# WireGuard VPN Setup
# -----------------------------------------------------------------------------
if [ -f /etc/wireguard/wg0.conf ]; then
    echo "WireGuard configuration found, starting VPN..."
    
    # Ensure WireGuard module is available (may need host support)
    if command -v wg-quick &> /dev/null; then
        wg-quick up wg0 2>&1 || {
            echo "WARNING: Failed to start WireGuard. This may require host kernel support."
            echo "Make sure the host has WireGuard module loaded."
        }
        
        # Verify WireGuard is running
        if ip link show wg0 &> /dev/null; then
            echo "WireGuard VPN started successfully"
            wg show wg0
        else
            echo "WARNING: WireGuard interface not found after startup"
        fi
    else
        echo "WARNING: wg-quick not found, WireGuard not available"
    fi
fi

# -----------------------------------------------------------------------------
# SOCKS Proxy Setup
# -----------------------------------------------------------------------------
# SOCKS proxy is configured via environment variables set by the spawner:
# ALL_PROXY, HTTP_PROXY, HTTPS_PROXY, http_proxy, https_proxy, NO_PROXY

if [ -n "$ALL_PROXY" ] || [ -n "$KAZMA_PROXY" ]; then
    echo "SOCKS proxy configured"
    
    # Create system-wide proxy configuration for all users
    cat > /etc/profile.d/kazma-proxy.sh << 'PROXYEOF'
# Kazma Proxy Configuration
export ALL_PROXY="${ALL_PROXY}"
export HTTP_PROXY="${HTTP_PROXY}"
export HTTPS_PROXY="${HTTPS_PROXY}"
export http_proxy="${http_proxy:-$HTTP_PROXY}"
export https_proxy="${https_proxy:-$HTTPS_PROXY}"
export NO_PROXY="${NO_PROXY:-localhost,127.0.0.1}"
export no_proxy="${NO_PROXY}"
PROXYEOF
    
    # Make proxy settings available to current session
    chmod 644 /etc/profile.d/kazma-proxy.sh
    
    # Also set for apt if present (Debian/Ubuntu)
    if [ -d /etc/apt/apt.conf.d ]; then
        if [ -n "$HTTP_PROXY" ]; then
            echo "Acquire::http::Proxy \"${HTTP_PROXY}\";" > /etc/apt/apt.conf.d/99proxy
            echo "Acquire::https::Proxy \"${HTTPS_PROXY}\";" >> /etc/apt/apt.conf.d/99proxy
        fi
    fi
    
    echo "Proxy environment variables configured for all users"
    echo "  ALL_PROXY: ${ALL_PROXY}"
fi

echo "Proxy/VPN setup complete"

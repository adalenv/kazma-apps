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

# -----------------------------------------------------------------------------
# Kill Switch Setup
# -----------------------------------------------------------------------------
# If KAZMA_KILL_SWITCH is set, block all internet if VPN/proxy is not connected

if [ "$KAZMA_KILL_SWITCH" = "1" ]; then
    echo "Kill switch enabled, configuring firewall rules..."
    
    # Check if iptables is available
    if ! command -v iptables &> /dev/null; then
        echo "WARNING: iptables not found, kill switch cannot be configured"
    else
        # For WireGuard VPN
        if [ -n "$KAZMA_VPN" ] && [ "$KAZMA_VPN" = "wireguard" ]; then
            # Check if WireGuard interface exists
            if ip link show wg0 &> /dev/null; then
                echo "Configuring kill switch for WireGuard..."
                
                # Allow loopback
                iptables -A OUTPUT -o lo -j ACCEPT
                iptables -A INPUT -i lo -j ACCEPT
                
                # Allow traffic through WireGuard interface
                iptables -A OUTPUT -o wg0 -j ACCEPT
                iptables -A INPUT -i wg0 -j ACCEPT
                
                # Allow established connections
                iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
                iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
                
                # Allow traffic to WireGuard endpoint (so we can establish the tunnel)
                WG_ENDPOINT=$(grep -i "^Endpoint" /etc/wireguard/wg0.conf 2>/dev/null | cut -d'=' -f2- | tr -d ' ' | cut -d':' -f1)
                if [ -n "$WG_ENDPOINT" ]; then
                    iptables -A OUTPUT -d "$WG_ENDPOINT" -j ACCEPT
                fi
                
                # Allow local network (for RDP connection from Guacamole)
                iptables -A INPUT -s 172.16.0.0/12 -j ACCEPT
                iptables -A OUTPUT -d 172.16.0.0/12 -j ACCEPT
                iptables -A INPUT -s 10.0.0.0/8 -j ACCEPT
                iptables -A OUTPUT -d 10.0.0.0/8 -j ACCEPT
                iptables -A INPUT -s 192.168.0.0/16 -j ACCEPT
                iptables -A OUTPUT -d 192.168.0.0/16 -j ACCEPT
                
                # Block all other outgoing traffic
                iptables -A OUTPUT -j DROP
                
                echo "Kill switch configured: Internet blocked unless WireGuard is connected"
            else
                echo "WARNING: WireGuard interface not found, kill switch blocking all internet"
                # Block everything except local network
                iptables -A OUTPUT -o lo -j ACCEPT
                iptables -A INPUT -i lo -j ACCEPT
                iptables -A INPUT -s 172.16.0.0/12 -j ACCEPT
                iptables -A OUTPUT -d 172.16.0.0/12 -j ACCEPT
                iptables -A INPUT -s 10.0.0.0/8 -j ACCEPT
                iptables -A OUTPUT -d 10.0.0.0/8 -j ACCEPT
                iptables -A INPUT -s 192.168.0.0/16 -j ACCEPT
                iptables -A OUTPUT -d 192.168.0.0/16 -j ACCEPT
                iptables -A OUTPUT -j DROP
            fi
        fi
        
        # For SOCKS proxy
        if [ -n "$KAZMA_PROXY" ] && [ "$KAZMA_PROXY" = "socks5" ]; then
            echo "Configuring kill switch for SOCKS proxy..."
            
            # Extract proxy host and port
            PROXY_HOST=$(echo "$ALL_PROXY" | sed -E 's|socks[45]?://([^:@]+@)?||' | cut -d':' -f1)
            PROXY_PORT=$(echo "$ALL_PROXY" | sed -E 's|socks[45]?://([^:@]+@)?||' | cut -d':' -f2 | cut -d'/' -f1)
            
            if [ -n "$PROXY_HOST" ] && [ -n "$PROXY_PORT" ]; then
                # Allow loopback
                iptables -A OUTPUT -o lo -j ACCEPT
                iptables -A INPUT -i lo -j ACCEPT
                
                # Allow established connections
                iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
                iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
                
                # Allow traffic to SOCKS proxy
                iptables -A OUTPUT -d "$PROXY_HOST" -p tcp --dport "$PROXY_PORT" -j ACCEPT
                
                # Allow local network (for RDP connection from Guacamole)
                iptables -A INPUT -s 172.16.0.0/12 -j ACCEPT
                iptables -A OUTPUT -d 172.16.0.0/12 -j ACCEPT
                iptables -A INPUT -s 10.0.0.0/8 -j ACCEPT
                iptables -A OUTPUT -d 10.0.0.0/8 -j ACCEPT
                iptables -A INPUT -s 192.168.0.0/16 -j ACCEPT
                iptables -A OUTPUT -d 192.168.0.0/16 -j ACCEPT
                
                # Block all other outgoing traffic
                iptables -A OUTPUT -j DROP
                
                echo "Kill switch configured: Internet only accessible through SOCKS proxy at $PROXY_HOST:$PROXY_PORT"
            else
                echo "WARNING: Could not parse SOCKS proxy address, kill switch not configured"
            fi
        fi
    fi
fi

echo "Proxy/VPN setup complete"

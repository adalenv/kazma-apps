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
    
    # Check if wg-quick is available
    if ! command -v wg-quick &> /dev/null; then
        echo "WARNING: wg-quick not found, WireGuard not available"
    else
        # Try to start WireGuard
        # First, try with standard wg-quick (works if container has proper privileges)
        if wg-quick up wg0 2>&1; then
            echo "WireGuard VPN started successfully with wg-quick"
            wg show wg0
        else
            echo "Standard wg-quick failed, trying manual setup..."
            
            # Manual WireGuard setup (works in more restricted containers)
            # This avoids the iptables and sysctl requirements
            
            # Parse the config file for manual setup
            WG_CONF="/etc/wireguard/wg0.conf"
            
            # Extract values from config
            PRIVATE_KEY=$(grep -i "^PrivateKey" "$WG_CONF" | cut -d'=' -f2- | tr -d ' ')
            ADDRESS=$(grep -i "^Address" "$WG_CONF" | cut -d'=' -f2- | tr -d ' ' | cut -d',' -f1)
            DNS=$(grep -i "^DNS" "$WG_CONF" | cut -d'=' -f2- | tr -d ' ')
            PEER_PUBLIC_KEY=$(grep -i "^PublicKey" "$WG_CONF" | cut -d'=' -f2- | tr -d ' ')
            ENDPOINT=$(grep -i "^Endpoint" "$WG_CONF" | cut -d'=' -f2- | tr -d ' ')
            ALLOWED_IPS=$(grep -i "^AllowedIPs" "$WG_CONF" | cut -d'=' -f2- | tr -d ' ')
            PERSISTENT_KEEPALIVE=$(grep -i "^PersistentKeepalive" "$WG_CONF" | cut -d'=' -f2- | tr -d ' ')
            
            if [ -n "$PRIVATE_KEY" ] && [ -n "$ADDRESS" ] && [ -n "$PEER_PUBLIC_KEY" ] && [ -n "$ENDPOINT" ]; then
                echo "Attempting manual WireGuard configuration..."
                
                # Create interface
                ip link add wg0 type wireguard 2>/dev/null || true
                
                # Set private key
                echo "$PRIVATE_KEY" | wg set wg0 private-key /dev/stdin
                
                # Set peer
                if [ -n "$PERSISTENT_KEEPALIVE" ]; then
                    wg set wg0 peer "$PEER_PUBLIC_KEY" endpoint "$ENDPOINT" allowed-ips "${ALLOWED_IPS:-0.0.0.0/0}" persistent-keepalive "$PERSISTENT_KEEPALIVE"
                else
                    wg set wg0 peer "$PEER_PUBLIC_KEY" endpoint "$ENDPOINT" allowed-ips "${ALLOWED_IPS:-0.0.0.0/0}"
                fi
                
                # Set address and bring up
                ip addr add "$ADDRESS" dev wg0 2>/dev/null || true
                ip link set wg0 up
                
                # Add routes for allowed IPs (simplified - just default route through wg0)
                # This is a simpler approach that doesn't require iptables
                if [ "$ALLOWED_IPS" = "0.0.0.0/0" ] || [ "$ALLOWED_IPS" = "0.0.0.0/0, ::/0" ]; then
                    # Get the gateway for the endpoint
                    ENDPOINT_IP=$(echo "$ENDPOINT" | cut -d':' -f1)
                    CURRENT_GW=$(ip route | grep default | awk '{print $3}' | head -1)
                    CURRENT_DEV=$(ip route | grep default | awk '{print $5}' | head -1)
                    
                    if [ -n "$CURRENT_GW" ] && [ -n "$ENDPOINT_IP" ]; then
                        # Add route to endpoint via current gateway
                        ip route add "$ENDPOINT_IP/32" via "$CURRENT_GW" dev "$CURRENT_DEV" 2>/dev/null || true
                        # Replace default route to go through WireGuard
                        ip route replace default dev wg0 2>/dev/null || true
                    fi
                fi
                
                # Configure DNS if specified
                if [ -n "$DNS" ]; then
                    # Backup and update resolv.conf
                    cp /etc/resolv.conf /etc/resolv.conf.backup 2>/dev/null || true
                    echo "# WireGuard DNS" > /etc/resolv.conf
                    for dns_server in $(echo "$DNS" | tr ',' ' '); do
                        echo "nameserver $dns_server" >> /etc/resolv.conf
                    done
                fi
                
                # Verify
                if ip link show wg0 &> /dev/null && [ "$(cat /sys/class/net/wg0/operstate 2>/dev/null)" = "unknown" ] || ip link show wg0 | grep -q "UP"; then
                    echo "WireGuard VPN started successfully (manual setup)"
                    wg show wg0
                else
                    echo "WARNING: WireGuard manual setup may have issues"
                    ip link show wg0 2>/dev/null || echo "Interface wg0 not found"
                fi
            else
                echo "WARNING: Could not parse WireGuard config for manual setup"
                echo "Missing required fields (PrivateKey, Address, PublicKey, or Endpoint)"
            fi
        fi
        
        # Final verification
        if ip link show wg0 &> /dev/null; then
            echo "WireGuard interface is up"
        else
            echo "WARNING: WireGuard interface not found after setup attempts"
            echo "This may require running the container with additional privileges:"
            echo "  --cap-add=NET_ADMIN --sysctl net.ipv4.conf.all.src_valid_mark=1"
        fi
    fi
fi

# -----------------------------------------------------------------------------
# SOCKS Proxy Setup
# -----------------------------------------------------------------------------
# SOCKS proxy is configured via environment variables set by the spawner:
# ALL_PROXY, HTTP_PROXY, HTTPS_PROXY, http_proxy, https_proxy, NO_PROXY

if [ -n "$ALL_PROXY" ] || [ -n "$KAZMA_PROXY" ] || [ -n "$HTTP_PROXY" ] || [ -n "$HTTPS_PROXY" ]; then
    echo "Proxy configuration detected, setting up..."
    
    # Determine proxy URL
    PROXY_URL="${ALL_PROXY:-${KAZMA_PROXY:-${HTTP_PROXY:-$HTTPS_PROXY}}}"
    
    # Create system-wide proxy configuration for all users
    cat > /etc/profile.d/kazma-proxy.sh << EOF
# Kazma Proxy Configuration
export ALL_PROXY="${ALL_PROXY:-$PROXY_URL}"
export HTTP_PROXY="${HTTP_PROXY:-$PROXY_URL}"
export HTTPS_PROXY="${HTTPS_PROXY:-$PROXY_URL}"
export http_proxy="${http_proxy:-${HTTP_PROXY:-$PROXY_URL}}"
export https_proxy="${https_proxy:-${HTTPS_PROXY:-$PROXY_URL}}"
export NO_PROXY="${NO_PROXY:-localhost,127.0.0.1,::1}"
export no_proxy="\$NO_PROXY"
EOF
    
    chmod 644 /etc/profile.d/kazma-proxy.sh
    
    # Source it for current session
    source /etc/profile.d/kazma-proxy.sh
    
    # Configure apt proxy (Debian/Ubuntu)
    if [ -d /etc/apt/apt.conf.d ]; then
        if [ -n "$HTTP_PROXY" ]; then
            cat > /etc/apt/apt.conf.d/99proxy << EOF
Acquire::http::Proxy "${HTTP_PROXY}";
Acquire::https::Proxy "${HTTPS_PROXY:-$HTTP_PROXY}";
EOF
        fi
    fi
    
    # Configure git proxy
    if command -v git &> /dev/null; then
        git config --system http.proxy "${HTTP_PROXY:-$PROXY_URL}" 2>/dev/null || true
        git config --system https.proxy "${HTTPS_PROXY:-$PROXY_URL}" 2>/dev/null || true
    fi
    
    # Configure wget proxy
    if [ -n "$HTTP_PROXY" ]; then
        cat > /etc/wgetrc.d/proxy 2>/dev/null << EOF || true
use_proxy = on
http_proxy = ${HTTP_PROXY}
https_proxy = ${HTTPS_PROXY:-$HTTP_PROXY}
EOF
    fi
    
    # Configure curl proxy (via environment is usually enough, but also curlrc)
    mkdir -p /etc/skel
    cat > /etc/skel/.curlrc << EOF
proxy = "${PROXY_URL}"
EOF
    
    # Copy to desktop user if exists
    if [ -d /home/desktop ]; then
        cp /etc/skel/.curlrc /home/desktop/.curlrc 2>/dev/null || true
        chown desktop:desktop /home/desktop/.curlrc 2>/dev/null || true
    fi
    
    # For SOCKS proxy specifically, configure additional tools
    if echo "$PROXY_URL" | grep -qi "socks"; then
        echo "SOCKS proxy detected: $PROXY_URL"
        
        # Create a wrapper script for applications that don't support SOCKS natively
        # Using proxychains-ng if available, or tsocks
        if command -v proxychains4 &> /dev/null || command -v proxychains &> /dev/null; then
            PROXY_HOST=$(echo "$PROXY_URL" | sed -E 's|socks[45]?://||' | cut -d':' -f1)
            PROXY_PORT=$(echo "$PROXY_URL" | sed -E 's|socks[45]?://||' | cut -d':' -f2 | cut -d'/' -f1)
            PROXY_TYPE="socks5"
            echo "$PROXY_URL" | grep -qi "socks4" && PROXY_TYPE="socks4"
            
            cat > /etc/proxychains.conf << EOF
# Kazma SOCKS Proxy Configuration
strict_chain
proxy_dns
tcp_read_time_out 15000
tcp_connect_time_out 8000

[ProxyList]
$PROXY_TYPE $PROXY_HOST $PROXY_PORT
EOF
            echo "Proxychains configured for SOCKS proxy"
        fi
    fi
    
    echo "Proxy environment configured for all users"
    echo "  Proxy URL: ${PROXY_URL}"
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

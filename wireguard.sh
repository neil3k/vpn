#!/bin/bash
# WireGuard VPN Server Setup Script
# This script runs automatically when the EC2 instance first boots
# It installs and configures WireGuard VPN server

set -e    # Exit on any error

# Update package list and install required packages
apt update
apt install wireguard iptables-persistent -y

# Enable IP forwarding to allow traffic routing through the VPN server
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Configure iptables for NAT (Network Address Translation)
# This allows VPN clients to access the internet through the server
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
netfilter-persistent save    # Make iptables rules persistent across reboots

# Change to WireGuard configuration directory
cd /etc/wireguard

# Set restrictive permissions for key files
umask 077

# Generate cryptographic keys for server and client
wg genkey | tee server_private.key | wg pubkey > server_public.key    # Server key pair
wg genkey | tee client_private.key | wg pubkey > client_public.key    # Client key pair

# Read the generated keys into variables
SERVER_PRIVATE=$(cat server_private.key)
SERVER_PUBLIC=$(cat server_public.key)
CLIENT_PUBLIC=$(cat client_public.key)

# Create WireGuard server configuration file
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
PrivateKey = $SERVER_PRIVATE    # Server's private key
Address = 10.0.0.1/24          # Server's VPN IP address
ListenPort = 51820             # Port to listen on for VPN connections
# Configure iptables rules to forward traffic when VPN starts/stops
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT

[Peer]
PublicKey = $CLIENT_PUBLIC      # Client's public key
AllowedIPs = 10.0.0.2/32       # IP address assigned to this client
EOF

# Start and enable the WireGuard service
systemctl start wg-quick@wg0    # Start the VPN service
systemctl enable wg-quick@wg0   # Enable auto-start on boot

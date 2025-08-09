# Output the VPN server's public IP address and port
# This information is needed to configure WireGuard clients
output "connect_to_vpn" {
  value = "Use this IP in your WireGuard client config: ${aws_eip.vpn_ip.public_ip}:51820"
}
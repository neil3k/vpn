output "connect_to_vpn" {
  value = "Use this IP in your WireGuard client config: ${aws_eip.vpn_ip.public_ip}:51820"
}
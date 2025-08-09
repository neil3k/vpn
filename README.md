# AWS WireGuard VPN Server

This Terraform project deploys a WireGuard VPN server on AWS, providing a secure and fast VPN solution with modern cryptography.

## Architecture

The infrastructure includes:
- **VPC** with public and private subnets
- **WireGuard server** running on Ubuntu 22.04 (t3.micro instance)
- **NAT Gateway** for private subnet internet access
- **Security Group** allowing WireGuard (UDP 51820) and SSH (TCP 22) traffic
- **Elastic IP** for stable VPN server access

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** installed (v1.0+)
3. **AWS CLI** configured with your credentials
4. **WireGuard client** for connecting to the VPN

## Quick Start

1. **Clone and navigate to the project:**
   ```bash
   git clone <your-repo-url>
   cd vpn
   ```

2. **Initialize Terraform:**
   ```bash
   terraform init
   ```

3. **Plan the deployment:**
   ```bash
   terraform plan
   ```

4. **Deploy the infrastructure:**
   ```bash
   terraform apply
   ```

5. **Get the VPN server IP:**
   After deployment, Terraform will output the VPN server's public IP address.

## Configuration

### Server Configuration
The WireGuard server is automatically configured via the `wireguard.sh` script with:
- Server IP: `10.0.0.1/24`
- Listen Port: `51820`
- IP forwarding enabled
- NAT masquerading for internet access

### Client Configuration
After deployment, SSH into the server to get the client configuration:

```bash
ssh ubuntu@<vpn-server-ip>
sudo cat /etc/wireguard/client_private.key
sudo cat /etc/wireguard/server_public.key
```

Create a client configuration file (`client.conf`):
```ini
[Interface]
PrivateKey = <client_private_key>
Address = 10.0.0.2/32
DNS = 8.8.8.8

[Peer]
PublicKey = <server_public_key>
Endpoint = <vpn-server-ip>:51820
AllowedIPs = 0.0.0.0/0
```

## Files Structure

```
├── main.tf          # Main infrastructure resources
├── provider.tf      # AWS provider configuration
├── data.tf          # Data sources (AMI, AZs)
├── output.tf        # Output values
├── variables.tf     # Variable definitions (currently empty)
├── wireguard.sh     # WireGuard server setup script
└── README.md        # This file
```

## Network Details

- **VPC CIDR:** `10.0.0.0/16`
- **Public Subnet:** `10.0.1.0/24`
- **Private Subnet:** `10.0.2.0/24`
- **VPN Network:** `10.0.0.0/24`
- **Region:** `eu-west-2` (London)

## Security Considerations

⚠️ **Important Security Notes:**

1. **SSH Access:** Currently allows SSH from anywhere (`0.0.0.0/0`). Consider restricting to your IP:
   ```hcl
   cidr_blocks = ["YOUR_IP/32"]
   ```

2. **WireGuard Access:** Currently allows connections from anywhere. For better security, restrict to known IP ranges.

3. **Key Management:** Server and client keys are generated automatically. For production use, consider:
   - Implementing proper key rotation
   - Using AWS Secrets Manager for key storage
   - Creating multiple client configurations

## Customization

### Change AWS Region
Edit `provider.tf`:
```hcl
provider "aws" {
  region = "your-preferred-region"
}
```

### Change Instance Type
Edit the `aws_instance` resource in `main.tf`:
```hcl
instance_type = "t3.small"  # or your preferred type
```

### Add Variables
Create variables in `variables.tf` for easier customization:
```hcl
variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}
```

## Costs

Estimated monthly costs (eu-west-2):
- **t3.micro instance:** ~$8.50/month
- **Elastic IP:** ~$3.65/month (when attached)
- **NAT Gateway:** ~$32/month + data transfer costs
- **Data transfer:** Variable based on usage

💡 **Cost Optimization:** For personal use, consider removing the NAT Gateway if private subnet internet access isn't required.

## Troubleshooting

### Connection Issues
1. Check security group rules
2. Verify WireGuard service status:
   ```bash
   sudo systemctl status wg-quick@wg0
   ```
3. Check server logs:
   ```bash
   sudo journalctl -u wg-quick@wg0
   ```

### Key Issues
If client keys need regeneration:
```bash
sudo su
cd /etc/wireguard
wg genkey | tee new_client_private.key | wg pubkey > new_client_public.key
```

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

## Contributing

Feel free to submit issues and enhancement requests!

## License

This project is open source and available under the [MIT License](LICENSE).

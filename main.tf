# Create a Virtual Private Cloud (VPC) for our VPN infrastructure
# This provides an isolated network environment in AWS
resource "aws_vpc" "vpn_vpc" {
  cidr_block           = "10.0.0.0/16"    # IP range for the entire VPC (65,534 possible IPs)
  enable_dns_hostnames = true             # Allow instances to have DNS hostnames
  enable_dns_support   = true             # Enable DNS resolution within the VPC

  tags = {
    Name = "vpn-vpc"
  }
}

# Internet Gateway provides internet access to the VPC
# This allows resources in public subnets to communicate with the internet
resource "aws_internet_gateway" "vpn_igw" {
  vpc_id = aws_vpc.vpn_vpc.id

  tags = {
    Name = "vpn-igw"
  }
}

# Public subnet for resources that need direct internet access
# The VPN server will be placed here to be reachable from the internet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.vpn_vpc.id
  cidr_block              = "10.0.1.0/24"                                    # 254 possible IPs
  availability_zone       = data.aws_availability_zones.available.names[0]   # Use first available AZ
  map_public_ip_on_launch = true                                             # Auto-assign public IPs

  tags = {
    Name = "vpn-public-subnet"
  }
}

# Private subnet for resources that should not have direct internet access
# These resources can access the internet through the NAT Gateway
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.vpn_vpc.id
  cidr_block        = "10.0.2.0/24"                                    # 254 possible IPs
  availability_zone = data.aws_availability_zones.available.names[1]   # Use second available AZ for redundancy

  tags = {
    Name = "vpn-private-subnet"
  }
}

# Elastic IP for the NAT Gateway
# This provides a static public IP address for outbound internet traffic from private subnet
resource "aws_eip" "nat_eip" {
  domain     = "vpc"                                    # Specify this EIP is for use in a VPC
  depends_on = [aws_internet_gateway.vpn_igw]          # Ensure IGW exists before creating EIP

  tags = {
    Name = "vpn-nat-eip"
  }
}

# NAT Gateway allows private subnet resources to access the internet
# This enables outbound internet connectivity while keeping resources private
resource "aws_nat_gateway" "vpn_nat" {
  allocation_id = aws_eip.nat_eip.id                   # Use the Elastic IP created above
  subnet_id     = aws_subnet.public_subnet.id          # Place NAT Gateway in public subnet
  depends_on    = [aws_internet_gateway.vpn_igw]       # Ensure IGW exists first

  tags = {
    Name = "vpn-nat-gw"
  }
}

# Route table for public subnet
# Directs all internet-bound traffic (0.0.0.0/0) to the Internet Gateway
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpn_vpc.id

  route {
    cidr_block = "0.0.0.0/0"                          # Route all traffic to IGW
    gateway_id = aws_internet_gateway.vpn_igw.id      # Use Internet Gateway for internet access
  }

  tags = {
    Name = "vpn-public-rt"
  }
}

# Route table for private subnet
# Directs all internet-bound traffic through the NAT Gateway for secure outbound access
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.vpn_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"                       # Route all traffic to NAT Gateway
    nat_gateway_id = aws_nat_gateway.vpn_nat.id         # Use NAT Gateway for internet access
  }

  tags = {
    Name = "vpn-private-rt"
  }
}

# Associate public subnet with public route table
# This ensures public subnet uses the Internet Gateway for routing
resource "aws_route_table_association" "public_rta" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Associate private subnet with private route table
# This ensures private subnet uses the NAT Gateway for routing
resource "aws_route_table_association" "private_rta" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

# Security group for the WireGuard VPN server
# Defines firewall rules for inbound and outbound traffic
resource "aws_security_group" "wireguard_sg" {
  name        = "wireguard-sg"
  description = "Allow WireGuard VPN"
  vpc_id      = aws_vpc.vpn_vpc.id

  # Allow WireGuard VPN traffic on UDP port 51820
  ingress {
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"] # Allow from anywhere - restrict this for better security
  }

  # Allow SSH access for server management
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow SSH from anywhere - restrict this for better security
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"                                  # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"]                        # Allow to anywhere
  }
}


# EC2 instance for the WireGuard VPN server
# This will be the actual VPN server that clients connect to
resource "aws_instance" "vpn_server" {
  ami                         = data.aws_ami.ubuntu.id                    # Use Ubuntu 22.04 LTS AMI
  instance_type               = "t3.micro"                               # Small instance type (1 vCPU, 1GB RAM)
  vpc_security_group_ids      = [aws_security_group.wireguard_sg.id]     # Apply our security group
  subnet_id                   = aws_subnet.public_subnet.id              # Place in public subnet for internet access
  associate_public_ip_address = true                                     # Assign a public IP automatically

  # User data script runs on first boot to install and configure WireGuard
  user_data = file("wireguard.sh")

  tags = {
    Name = "wireguard-vpn"
  }
}

# Elastic IP for the VPN server
# Provides a static IP address so VPN clients don't need to update configs
resource "aws_eip" "vpn_ip" {
  instance = aws_instance.vpn_server.id                                  # Associate with our VPN server
  domain   = "vpc"                                                       # Specify this EIP is for use in a VPC
}
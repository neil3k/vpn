# Data source to get all available AWS availability zones in the current region
# This ensures our resources are placed in zones that are actually available
data "aws_availability_zones" "available" {
  state = "available"    # Only return zones that are currently available
}

# Data source to get the most recent Ubuntu 22.04 LTS AMI
# This ensures we always use the latest patched version of Ubuntu
data "aws_ami" "ubuntu" {
  most_recent = true                          # Get the most recently created AMI
  owners      = ["099720109477"]              # Canonical's AWS account ID (official Ubuntu AMIs)
  
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]    # Ubuntu 22.04 LTS server images
  }
}
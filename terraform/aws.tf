data "aws_region" "current" {
}

# Data block to grab current IP and add into SG rules
data "http" "current" {
  url = "https://api.ipify.org"
}

data "aws_partition" "current" {}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

#data "aws_ami" "ubuntu" {
#  filter {
#    name   = "name"
#    values = ["hc-security-base-ubuntu-2204*"]
#  }
#  filter {
#    name   = "state"
#    values = ["available"]
#  }
#  most_recent = true
#  owners      = ["888995627335"]
#}

resource "aws_key_pair" "boundary_poc" {
  key_name   = "${var.prefix}-keypair"
  public_key = var.ssh_public_key

  tags = merge(
    { Name = "${var.prefix}-keypair" },
    var.aws_tags
  )
}

resource "aws_vpc" "boundary_poc" {
  cidr_block           = var.aws_vpc_cidr
  enable_dns_hostnames = true

  tags = merge(
    { Name = "${var.prefix}-vpc" },
    var.aws_tags
  )
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.boundary_poc.id
  cidr_block        = var.aws_public_subnet_cidr
  availability_zone = "${var.aws_region}a"

  tags = merge(
    { Name = "${var.prefix}-public-subnet-a" },
    var.aws_tags
  )
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.boundary_poc.id
  cidr_block        = var.aws_private_subnet_cidr
  availability_zone = "${var.aws_region}a"

  tags = merge(
    { Name = "${var.prefix}-private-subnet-a" },
    var.aws_tags
  )
}

resource "aws_internet_gateway" "boundary_poc" {
  vpc_id = aws_vpc.boundary_poc.id

  tags = merge(
    { Name = "${var.prefix}-internet-gateway" },
    var.aws_tags
  )
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.boundary_poc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.boundary_poc.id
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.boundary_poc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.boundary_poc.id
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "boundary_poc" {
  name = "${var.prefix}-security-group"

  vpc_id = aws_vpc.boundary_poc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    self        = true
    cidr_blocks = [aws_subnet.public.cidr_block]
    description = "Allow incoming SSH connections"
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    self        = true
    cidr_blocks = [aws_subnet.public.cidr_block, data.hcp_hvn.vault_hvn.cidr_block]
    description = "Allow incoming Postgres connections"
  }

  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    self        = true
    cidr_blocks = [aws_subnet.public.cidr_block, data.hcp_hvn.vault_hvn.cidr_block]
    description = "Allow incoming RDP connections"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all traffic egress from boundary"
  }

  tags = merge(
    { Name = "${var.prefix}-security-group" },
    var.aws_tags
  )
}

# Security-maintained managed IAM Policy necessary for doormat session
data "aws_iam_policy" "security_compute_access" {
  name = "SecurityComputeAccess"
}

resource "aws_iam_role" "instance_role" {
  name = "${var.prefix}-instance-role"
  path = "/"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = "AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
  managed_policy_arns = [data.aws_iam_policy.security_compute_access.arn]

  tags = merge(
    { Name = "${var.prefix}-instance-role" },
    var.aws_tags
  )
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = "${var.prefix}-instance-profile"
  path = "/"
  role = aws_iam_role.instance_role.name
}

resource "aws_instance" "boundary_target" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.boundary_poc.key_name
  associate_public_ip_address = false
  user_data_base64            = data.cloudinit_config.ssh_trusted_ca.rendered
  user_data_replace_on_change = true
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.boundary_poc.id]
  iam_instance_profile        = aws_iam_instance_profile.instance_profile.name
  tags = merge(
    { Name = "Boundary SSH Target" },
    var.aws_tags
  )
}

//Configure the EC2 host to trust Vault as the CA
data "cloudinit_config" "ssh_trusted_ca" {
  gzip          = false
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content      = <<-EOF
    #!/usr/bin/env bash
    set -euo pipefail
    sudo curl -o /etc/ssh/trusted-user-ca-keys.pem \
    --header "X-Vault-Namespace: admin/${vault_namespace.boundary.path}" \
    -X GET \
    ${var.vault_address}/v1/ssh-client-signer/public_key
    sudo echo TrustedUserCAKeys /etc/ssh/trusted-user-ca-keys.pem >> /etc/ssh/sshd_config
    sudo systemctl restart sshd.service
    EOF
  }

  part {
    content_type = "text/x-shellscript"
    content      = <<-EOF
    #!/usr/bin/env bash
    set -euo pipefail
    sudo adduser nick
    EOF
  }
}

resource "aws_eip" "boundary_poc" {
  domain = "vpc"
  tags = merge(
    { Name = "${var.prefix}-eip" },
    var.aws_tags
  )
}

resource "aws_nat_gateway" "boundary_poc" {
  allocation_id = aws_eip.boundary_poc.id
  subnet_id     = aws_subnet.public.id

  tags = merge(
    { Name = "${var.prefix}-nat" },
    var.aws_tags
  )

  depends_on = [aws_internet_gateway.boundary_poc]
}

resource "aws_security_group" "boundary_ingress_worker_ssh" {
  name        = "boundary_ingress_worker_allow_ssh_9202"
  description = "SG for Boundary Ingress Worker"
  vpc_id      = aws_vpc.boundary_poc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${data.http.current.response_body}/32"]
  }

  ingress {
    from_port   = 9202
    to_port     = 9202
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh"
  }
}

### BEGIN: Session Recording Configuration ###

data "aws_caller_identity" "current" {}

locals {
  my_email = split("/", data.aws_caller_identity.current.arn)[2]
}

data "aws_iam_policy" "demo_user_permissions_boundary" {
  name = "DemoUser"
}

data "aws_iam_user" "demo" {
  user_name = "demo-${local.my_email}"
}

resource "aws_iam_user" "boundary_bsr" {
  count                = data.aws_iam_user.demo.id != null ? 0 : 1
  name                 = "demo-${local.my_email}"
  permissions_boundary = data.aws_iam_policy.demo_user_permissions_boundary.arn
  force_destroy        = true
}

resource "aws_iam_user_policy_attachment" "boundary_bsr" {
  count      = data.aws_iam_user.demo.id != null ? 0 : 1
  user       = aws_iam_user.boundary_bsr[0].name
  policy_arn = data.aws_iam_policy.demo_user_permissions_boundary.arn
}

resource "aws_iam_access_key" "boundary_bsr" {
  user = "demo-${local.my_email}"
}

resource "aws_s3_bucket" "boundary_session_recording" {
  bucket        = var.s3_bucket_name
  force_destroy = true
  tags = merge(
    { Name = "${var.prefix}-s3-bucket" },
    var.aws_tags
  )
}

resource "aws_s3_bucket_versioning" "versioning_demo" {
  bucket = aws_s3_bucket.boundary_session_recording.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_metric" "demo-bucket-metric" {
  bucket = aws_s3_bucket.boundary_session_recording.id
  name   = "EntireBucket"
}

### END: Session Recording Configuration ###
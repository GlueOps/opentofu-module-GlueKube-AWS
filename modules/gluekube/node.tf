data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_security_group" "node_sg" {
  name        = "${var.cluster_name}-${var.name}-sg"
  description = "Security group for ${var.role} nodes"
  vpc_id      = var.vpc_id

  # Internal/private network - allow all TCP ports
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Internal TCP traffic"
  }

  # Internal/private network - allow all UDP ports
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
    description = "Internal UDP traffic"
  }

  # Public access - SSH (port 22)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  # Public access - HTTP (port 80)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access"
  }

  # Public access - HTTPS (port 443)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access"
  }

  # ICMP
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "ICMP"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-${var.name}-sg"
  }
}

resource "aws_instance" "cluster_node" {
  for_each               = toset([for i in range(0, var.node_count) : tostring(i)])
  ami                    = var.image != "" ? var.image : data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_ids[tonumber(each.key) % length(var.subnet_ids)]
  vpc_security_group_ids = [aws_security_group.node_sg.id]

  user_data_base64 = base64encode(templatefile("${path.module}/cloudinit/cloud-init-${var.role}.yaml", {
    public_key = autoglue_ssh_key.ssh_key.public_key
    hostname   = "${var.role}-${var.name}-${each.key}"
  }))

  root_block_device {
    volume_size = var.storage_size_gb
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.role}-${var.name}-${each.key}"
    Role = var.role
  }
}

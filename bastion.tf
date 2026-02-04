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

resource "autoglue_ssh_key" "bastion" {
  name    = "${var.autoglue.autoglue_cluster_name}-bastion"
  comment = "GlueKube bastion SSH Key"
}

resource "aws_security_group" "bastion" {
  name        = "${var.autoglue.autoglue_cluster_name}-bastion-sg"
  description = "Security group for bastion server"
  vpc_id      = module.vpc.vpc_id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.autoglue.autoglue_cluster_name}-bastion-sg"
  }
}

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.bastion.instance_type
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.bastion.id]

  user_data_base64 = base64encode(templatefile("${path.module}/cloudinit/cloud-init-bastion.yaml", {
    public_key = autoglue_ssh_key.bastion.public_key
    hostname   = "bastion"
  }))

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.autoglue.autoglue_cluster_name}-bastion"
    Role = "bastion"
  }
}

resource "autoglue_server" "bastion" {
  hostname           = "bastion"
  public_ip_address  = aws_instance.bastion.public_ip
  private_ip_address = aws_instance.bastion.private_ip
  role               = "bastion"
  ssh_key_id         = autoglue_ssh_key.bastion.id
  ssh_user           = "cluster"
}

resource "autoglue_cluster_bastion" "bastion" {
  cluster_id = autoglue_cluster.cluster.id
  server_id  = autoglue_server.bastion.id
}

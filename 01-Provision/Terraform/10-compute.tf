#######################################################
###   This Module will create the EC2 Instance(s),  ###
###             Required for this lab               ###  
#######################################################
#
# NOTE: this file provisions the raw EC2 instances only - the bastion,
# the Kube master node(s), and the Kube worker node(s). Installing an
# operating system's specific configuration or Kubernetes itself is
# handled outside Terraform, in a separate step.
#
# NOTE: the number of master and worker nodes is user-configurable, not
# fixed. var.kube-master-count and var.kube-worker-count (variables.tf)
# each carry a default, so this works with no input at all, but either
# can be overridden - the actual instance count follows whatever value
# they resolve to.
#
# The count = ... argument on each resource is what turns a single
# resource block into a loop: Terraform creates that many copies of the
# block, numbered 0 through count - 1, and count.index is which copy is
# currently being created.
#
# Each node's private_ip is calculated, not typed in - cidrhost() takes
# the private subnet's CIDR and a host number, and returns the actual IP
# for that offset. The host number is var.kube-master-ip-start (or
# kube-worker-ip-start) plus count.index, so node 0 gets the start
# address, node 1 gets the next one, and so on - every node's IP is
# derived from its position in the loop, not set individually.
#
#------------------------------------------------------

# First create the SSH Key Pair localy and add it to AWS
#-------------------------------------------------------

# Create a random suffix so the key name is unique per deployment
resource "random_string" "ssh-key-random" {
  length  = 6
  special = false
  upper   = false
}

# Create an RSA Key Pair of size 4096 bits
resource "tls_private_key" "ssh-key-pair-local-01" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create the SSH Key on AWS
resource "aws_key_pair" "demo-ssh-key-pair-01" {
  depends_on = [tls_private_key.ssh-key-pair-local-01]
  key_name   = "${random_string.ssh-key-random.result}-demo-key"
  public_key = tls_private_key.ssh-key-pair-local-01.public_key_openssh
}

# Create a local file with the content of the SSH Key
resource "local_file" "demo-ssh-key-pair" {
  depends_on      = [tls_private_key.ssh-key-pair-local-01]
  content         = tls_private_key.ssh-key-pair-local-01.private_key_pem
  filename        = "${random_string.ssh-key-random.result}-${var.ssh-file-name}"
  file_permission = "0400"
}

#========================================

# Second create the EC2 Instance(s)
#-----------------------------------

# The bastion's private_ip is calculated with cidrhost(), using the
# public subnet's CIDR (pub-sub-01-cidr) and a fixed host number
# (bastion-ip-host-num, see variables.tf) - this always resolves to .11
# in that subnet.

# Create Bastion Host in Public Subnet
resource "aws_instance" "bastion-01" {
  depends_on                  = [aws_route_table.pub-rt-01, aws_key_pair.demo-ssh-key-pair-01]
  ami                         = data.aws_ami.ami-os.id
  instance_type               = var.bastion-node-size
  subnet_id                   = aws_subnet.pub-sub-01.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.pub-sg-01.id]
  private_ip                  = cidrhost(var.pub-sub-01-cidr, var.bastion-ip-host-num)
  key_name                    = aws_key_pair.demo-ssh-key-pair-01.key_name

  # Copy the private key onto the bastion so it can be used to jump to the private Kube nodes
  provisioner "file" {
    content     = tls_private_key.ssh-key-pair-local-01.private_key_pem
    destination = var.ssh-file-name
    connection {
      type        = "ssh"
      user        = var.ec2-user-name
      private_key = tls_private_key.ssh-key-pair-local-01.private_key_pem
      host        = self.public_ip
    }
  }

  provisioner "remote-exec" {
    inline = ["chmod 400 ${var.ssh-file-name}"]
    connection {
      type        = "ssh"
      user        = var.ec2-user-name
      private_key = tls_private_key.ssh-key-pair-local-01.private_key_pem
      host        = self.public_ip
    }
  }

  # Copy the scripts folder to the ubuntu user's home directory
  provisioner "file" {
    source      = "k8s-scripts/"
    destination = "k8s-scripts"
    connection {
      type        = "ssh"
      user        = var.ec2-user-name
      private_key = tls_private_key.ssh-key-pair-local-01.private_key_pem
      host        = self.public_ip
    }
  }

  # Make every script executable
  provisioner "remote-exec" {
    inline = ["chmod +x k8s-scripts/* 2>/dev/null || true"]
    connection {
      type        = "ssh"
      user        = var.ec2-user-name
      private_key = tls_private_key.ssh-key-pair-local-01.private_key_pem
      host        = self.public_ip
    }
  }

  tags = {
    Name       = "demo-bastion-01"
    DeployedBy = "TerraForm"
    UsedFor    = "K8sDemo"
    User       = "tshaker"
  }
}

# The number of master nodes comes from var.kube-master-count
# (variables.tf), which has a default but can be overridden. count turns
# this block into a loop of that many nodes, indexed 0 to count - 1. Each
# node's private_ip is cidrhost(priv-sub-01-cidr, kube-master-ip-start +
# count.index), and its Name tag is zero-padded with count.index for
# readability (demo-kube-master-01, -02, ...).

# Create Kube Master Node(s) in Private Subnet
resource "aws_instance" "kube-master" {
  count                   = var.kube-master-count
  depends_on              = [aws_route_table.priv-rt-01, aws_nat_gateway.main-natgw, aws_key_pair.demo-ssh-key-pair-01]
  ami                     = data.aws_ami.ami-os.id
  instance_type           = var.kube-master-node-size
  subnet_id               = aws_subnet.priv-sub-01.id
  vpc_security_group_ids  = [aws_security_group.priv-sg-01.id]
  private_ip              = cidrhost(var.priv-sub-01-cidr, var.kube-master-ip-start + count.index)
  key_name                = aws_key_pair.demo-ssh-key-pair-01.key_name

  root_block_device {
    volume_size           = var.kube-node-disk-size
    delete_on_termination = true
  }

  tags = {
    Name       = "demo-kube-master-${format("%02d", count.index + 1)}"
    DeployedBy = "TerraForm"
    UsedFor    = "K8sDemo"
    User       = "tshaker"
  }
}

# Same pattern as the master node(s) above, using kube-worker-count and
# kube-worker-ip-start instead.

# Create Kube Worker Node(s) in Private Subnet
resource "aws_instance" "kube-worker" {
  count                   = var.kube-worker-count
  depends_on              = [aws_route_table.priv-rt-01, aws_nat_gateway.main-natgw, aws_key_pair.demo-ssh-key-pair-01]
  ami                     = data.aws_ami.ami-os.id
  instance_type           = var.kube-worker-node-size
  subnet_id               = aws_subnet.priv-sub-01.id
  vpc_security_group_ids  = [aws_security_group.priv-sg-01.id]
  private_ip              = cidrhost(var.priv-sub-01-cidr, var.kube-worker-ip-start + count.index)
  key_name                = aws_key_pair.demo-ssh-key-pair-01.key_name

  root_block_device {
    volume_size           = var.kube-node-disk-size
    delete_on_termination = true
  }

  tags = {
    Name       = "demo-kube-worker-${format("%02d", count.index + 1)}"
    DeployedBy = "TerraForm"
    UsedFor    = "K8sDemo"
    User       = "tshaker"
  }
}


# Write instance IDs and region for the power on/off scripts
resource "local_file" "instance-ids" {
  filename        = "${path.module}/start-stop-scripts/instance-ids.env"
  file_permission = "0644"
  content         = <<-EOT
    AWS_REGION="${var.aws-region}"
    BASTION_ID="${aws_instance.bastion-01.id}"
    MASTER_IDS=(${join(" ", aws_instance.kube-master[*].id)})
    WORKER_IDS=(${join(" ", aws_instance.kube-worker[*].id)})
  EOT
}

#========================================
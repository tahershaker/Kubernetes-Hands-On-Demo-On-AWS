#######################################################
###     This Module will hold the values of the     ###
###    required output for the deployed resources   ###  
#######################################################
#
# NOTE: these outputs show you how to reach and manage this environment
# after it's deployed - bastion address, load balancer address, SSH key
# location, and every node's IP. If you close this terminal, run
# `terraform output` again any time to see these same values.
#
# NOTE: kube-master-nodes and kube-worker-nodes list every node that was
# created. Master and worker counts have defaults, but can be changed by
# the user, so how many nodes appear here varies depending on what
# kube-master-count and kube-worker-count were set to at apply time.
#
#------------------------------------------------------

# Node IP lines, built once here so the summary block below can reuse them
locals {
  master-lines = join("\n", [for inst in aws_instance.kube-master : "  - ${inst.tags["Name"]}: IP=${inst.private_ip}"])
  worker-lines = join("\n", [for inst in aws_instance.kube-worker : "  - ${inst.tags["Name"]}: IP=${inst.private_ip}"])
}

output "bastion-fqdn" {
  value = aws_instance.bastion-01.public_dns
}

output "bastion-public-ip" {
  value = aws_instance.bastion-01.public_ip
}

output "bastion-private-ip" {
  value = aws_instance.bastion-01.private_ip
}

output "lb-fqdn" {
  value = aws_lb.nlb-01.dns_name
}

output "lb-public-ip" {
  value = aws_eip.lb-eip.public_ip
}

output "k8s-scripts-path-on-bastion" {
  value = "/home/${var.ec2-user-name}/k8s-scripts"
}

# The AWS-registered key pair name, and the local file it's saved to.
# The local filename has a random prefix, added in 10-compute.tf, so
# repeated deployments never collide with an old key file.
output "ssh-key-name-and-local-path" {
  value = "${aws_key_pair.demo-ssh-key-pair-01.key_name}  (local file: ${random_string.ssh-key-random.result}-${var.ssh-file-name})"
}

# The filename and path the key is copied to ON the bastion itself -
# note this has no random prefix, unlike the local copy above, since the
# bastion's "file" provisioner in 10-compute.tf writes it as plain
# var.ssh-file-name into the login user's home directory.
output "ssh-key-name-and-path-on-bastion" {
  value = "/home/${var.ec2-user-name}/${var.ssh-file-name}"
}

# One entry per master node - name and private IP.
output "kube-master-nodes" {
  value = {
    for inst in aws_instance.kube-master : inst.tags["Name"] => inst.private_ip
  }
}

# One entry per worker node - name and private IP.
output "kube-worker-nodes" {
  value = {
    for inst in aws_instance.kube-worker : inst.tags["Name"] => inst.private_ip
  }
}

output "Deployment-Outputs" {
  value = <<EOF

  ╔══════════════════════════════════════════════════════╗
  ║                                                      ║
  ║        PROVISIONING COMPLETED SUCCESSFULLY           ║
  ║                                                      ║
  ╚══════════════════════════════════════════════════════╝

  ========================================================
  Resource and information outputs for this deployement:
  ========================================================
  - Bastion Host FQDN:                          ${aws_instance.bastion-01.public_dns}
  - Bastion Host Public IP:                     ${aws_instance.bastion-01.public_ip}
  - Bastion Host Private IP:                    ${aws_instance.bastion-01.private_ip}
  - Load Balancer FQDN:                         ${aws_lb.nlb-01.dns_name}
  - Load Balancer Public IP:                    ${aws_eip.lb-eip.public_ip}
  - SSH Key Name:                               ${aws_key_pair.demo-ssh-key-pair-01.key_name}
  - SSH Key Local Path:                         ${random_string.ssh-key-random.result}-${var.ssh-file-name}
  - SSH Key Path on Bastion:                    /home/${var.ec2-user-name}/${var.ssh-file-name}
  - Script Folder Path on Bastion:              /home/${var.ec2-user-name}/k8s-scripts

  ----------------------------------------------------------
  
  Kube Master Node(s):
${local.master-lines}
  
  ----------------------------------------------------------
  
  Kube Worker Node(s):
${local.worker-lines}
  
  ----------------------------------------------------------
  
  =================================================================
  NOTE: this information is needed to connect to and manage this
  environment (SSH access, node IPs, load balancer address). It is
  recommended you save it somewhere before closing this terminal.

  You can also see it again any time by running: terraform output
  =================================================================

  ╔══════════════════════════════════════════════════════╗
  ║                                                      ║
  ║              END OF DEPLOYMENT OUTPUT                ║
  ║                                                      ║
  ╚══════════════════════════════════════════════════════╝
  
  EOF
}
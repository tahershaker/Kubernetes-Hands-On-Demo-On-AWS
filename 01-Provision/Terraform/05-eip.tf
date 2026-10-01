###################################################
###  This Module will create the Elastic IP(s)  ###
###           rquired for this lab              ###  
###################################################
#
# NOTE: two EIPs total for the whole lab - one for the NAT Gateway's
# outbound traffic, one for the Load Balancer's inbound traffic.
#
#--------------------------------------------------


# NOTE: attached to the NAT Gateway (06-nat-gw.tf), giving the private
# subnet's outbound traffic a stable public IP.

# Create NAT GW EIP
resource "aws_eip" "nat-gw-eip" {
  depends_on = [aws_internet_gateway.main-igw]

  tags = {
    Name       = "demo-eip-nat-01"
    DeployedBy = "TerraForm"
    UsedFor    = "K8sDemo"
    User       = "tshaker"
  }
}


# NOTE: attached to the Network Load Balancer (09-load-balancer.tf), the
# single public entry point for HTTP/HTTPS traffic into the cluster.

# Create LB EIP
resource "aws_eip" "lb-eip" {
  depends_on = [aws_internet_gateway.main-igw]

  tags = {
    Name       = "demo-eip-lb-01"
    DeployedBy = "TerraForm"
    UsedFor    = "K8sDemo"
    User       = "tshaker"
  }
}

#========================================
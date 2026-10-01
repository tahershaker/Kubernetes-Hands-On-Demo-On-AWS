#######################################################
###  This Module will create the Load Balancer(s),  ###
###   its Target Group(s), and Listener(s)           ###  
#######################################################
#
# NOTE: this file assumes 10-compute.tf defines aws_instance.kube-master
# (count = var.kube-master-count) and aws_instance.kube-worker
# (count = var.kube-worker-count) as collections, not individually named
# resources. The target group attachments below loop over those counts,
# so any number of masters or workers gets registered automatically -
# no manual attachment block per node.
#
#------------------------------------------------------

# First create Load balancers

# Create Network Load Balancer and assign the EIP to it
resource "aws_lb" "nlb-01" {
  name                             = "demo-nlb-01"
  load_balancer_type               = "network"
  internal                         = false
  enable_cross_zone_load_balancing = true
  security_groups                  = [aws_security_group.pub-sg-01.id]

  subnet_mapping {
    subnet_id     = aws_subnet.pub-sub-01.id
    allocation_id = aws_eip.lb-eip.id
  }

  tags = {
    Name       = "demo-nlb-01"
    DeployedBy = "TerraForm"
    UsedFor    = "K8sDemo"
    User       = "tshaker"
  }
}

#========================================================================

# Second create Target Groups

# Create an http LB Target Group - forwards to the ingress controller on the Kube nodes
resource "aws_lb_target_group" "http-tg-01" {
  depends_on = [aws_lb.nlb-01]
  name       = "demo-http-tg-01"
  port       = 80
  protocol   = "TCP"
  vpc_id     = aws_vpc.main-vpc.id

  tags = {
    Name       = "demo-http-tg-01"
    DeployedBy = "TerraForm"
    UsedFor    = "K8sDemo"
    User       = "tshaker"
  }
}

# Create an https LB Target Group - forwards to the ingress controller on the Kube nodes
resource "aws_lb_target_group" "https-tg-01" {
  depends_on = [aws_lb.nlb-01]
  name       = "demo-https-tg-01"
  port       = 443
  protocol   = "TCP"
  vpc_id     = aws_vpc.main-vpc.id

  tags = {
    Name       = "demo-https-tg-01"
    DeployedBy = "TerraForm"
    UsedFor    = "K8sDemo"
    User       = "tshaker"
  }
}

#========================================================================

# Third create Target Group Attachments
# Every master AND every worker is registered on both target groups,
# since the ingress controller can land on any node in this demo
# cluster. count loops over however many nodes actually exist -
# kube-master-count masters, kube-worker-count workers.

# Create http Target Group Attachments - masters
resource "aws_lb_target_group_attachment" "http-tg-att-master" {
  count            = var.kube-master-count
  depends_on       = [aws_lb_target_group.http-tg-01]
  target_group_arn = aws_lb_target_group.http-tg-01.arn
  target_id        = aws_instance.kube-master[count.index].id
  port             = 80
}

# Create http Target Group Attachments - workers
resource "aws_lb_target_group_attachment" "http-tg-att-worker" {
  count            = var.kube-worker-count
  depends_on       = [aws_lb_target_group.http-tg-01]
  target_group_arn = aws_lb_target_group.http-tg-01.arn
  target_id        = aws_instance.kube-worker[count.index].id
  port             = 80
}

# Create https Target Group Attachments - masters
resource "aws_lb_target_group_attachment" "https-tg-att-master" {
  count            = var.kube-master-count
  depends_on       = [aws_lb_target_group.https-tg-01]
  target_group_arn = aws_lb_target_group.https-tg-01.arn
  target_id        = aws_instance.kube-master[count.index].id
  port             = 443
}

# Create https Target Group Attachments - workers
resource "aws_lb_target_group_attachment" "https-tg-att-worker" {
  count            = var.kube-worker-count
  depends_on       = [aws_lb_target_group.https-tg-01]
  target_group_arn = aws_lb_target_group.https-tg-01.arn
  target_id        = aws_instance.kube-worker[count.index].id
  port             = 443
}

#========================================================================

# Forth create Load Balancer Listeners

# Create http Listener
resource "aws_lb_listener" "http-listener-01" {
  depends_on        = [aws_lb.nlb-01, aws_lb_target_group.http-tg-01]
  load_balancer_arn = aws_lb.nlb-01.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.http-tg-01.arn
  }
}

# Create https Listener
resource "aws_lb_listener" "https-listener-01" {
  depends_on        = [aws_lb.nlb-01, aws_lb_target_group.https-tg-01]
  load_balancer_arn = aws_lb.nlb-01.arn
  port              = "443"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.https-tg-01.arn
  }
}

#========================================================================
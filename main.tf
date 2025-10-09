provider "aws" {
  region = "ap-south-1"
}

# ---------------------------
# VPC
# ---------------------------
resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "eks-vpc"
  }
}

# ---------------------------
# Subnets
# ---------------------------
data "aws_availability_zones" "available" {}

resource "aws_subnet" "eks_subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = element(["10.0.10.0/24", "10.0.20.0/24"], count.index)
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "eks-subnet-${count.index}"
  }
}

# ---------------------------
# Internet Gateway
# ---------------------------
resource "aws_internet_gateway" "eks_igw" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = "eks-igw"
  }
}

# ---------------------------
# Route Table
# ---------------------------
resource "aws_route_table" "eks_rt" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks_igw.id
  }

  tags = {
    Name = "eks-rt"
  }
}

resource "aws_route_table_association" "eks_rta" {
  count          = 2
  subnet_id      = aws_subnet.eks_subnet[count.index].id
  route_table_id = aws_route_table.eks_rt.id
}

# ---------------------------
# Security Group
# ---------------------------
resource "aws_security_group" "eks_sg" {
  name        = "eks-sg"
  description = "Security group for EKS cluster"
  vpc_id      = aws_vpc.eks_vpc.id

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------------------------
# EKS Cluster Role
# ---------------------------
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Effect = "Allow"
      Sid    = ""
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ---------------------------
# EKS Cluster
# ---------------------------
resource "aws_eks_cluster" "eks_cluster" {
  name     = "eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.28"

  vpc_config {
    subnet_ids         = aws_subnet.eks_subnet[*].id
    security_group_ids = [aws_security_group.eks_sg.id]
  }
}

# ---------------------------
# Worker Node Role
# ---------------------------
resource "aws_iam_role" "eks_worker_role" {
  name = "eks-worker-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "worker_node_policy" {
  role       = aws_iam_role.eks_worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "cni_policy" {
  role       = aws_iam_role.eks_worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "registry_policy" {
  role       = aws_iam_role.eks_worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# ---------------------------
# IAM Instance Profile
# ---------------------------
resource "aws_iam_instance_profile" "eks_worker_profile" {
  name = "eks-worker-profile"
  role = aws_iam_role.eks_worker_role.name
}

# ---------------------------
# Launch Template
# ---------------------------
resource "aws_launch_template" "eks_worker_lt" {
  name_prefix   = "eks-worker-"
  image_id      = "ami-0360c520857e3138f"
  instance_type = "t3.medium"
  key_name      = "windows"

  iam_instance_profile {
    name = aws_iam_instance_profile.eks_worker_profile.name
  }

  vpc_security_group_ids = [aws_security_group.eks_sg.id]
}

# ---------------------------
# Auto Scaling Group
# ---------------------------
resource "aws_autoscaling_group" "eks_worker_asg" {
  desired_capacity    = 2
  min_size            = 1
  max_size            = 3
  vpc_zone_identifier = aws_subnet.eks_subnet[*].id

  launch_template {
    id      = aws_launch_template.eks_worker_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "eks-worker-node"
    propagate_at_launch = true
  }
}

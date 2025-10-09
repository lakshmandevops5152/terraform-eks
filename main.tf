provider "aws" {
  region = "ap-south-1"
}

# -------------------------------
# 1. Create VPC and Networking
# -------------------------------
resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "eks-vpc"
  }
}

resource "aws_subnet" "eks_subnet1" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "eks-subnet-1"
  }
}

resource "aws_subnet" "eks_subnet2" {
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "eks-subnet-2"
  }
}

resource "aws_internet_gateway" "eks_igw" {
  vpc_id = aws_vpc.eks_vpc.id
  tags = {
    Name = "eks-igw"
  }
}

resource "aws_route_table" "eks_route_table" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks_igw.id
  }

  tags = {
    Name = "eks-route-table"
  }
}

resource "aws_route_table_association" "eks_rta1" {
  subnet_id      = aws_subnet.eks_subnet1.id
  route_table_id = aws_route_table.eks_route_table.id
}

resource "aws_route_table_association" "eks_rta2" {
  subnet_id      = aws_subnet.eks_subnet2.id
  route_table_id = aws_route_table.eks_route_table.id
}

# -------------------------------
# 2. Security Group for EKS Cluster
# -------------------------------
resource "aws_security_group" "eks_cluster_sg" {
  name        = "eks-cluster-sg"
  description = "Allow all inbound and outbound traffic for EKS"
  vpc_id      = aws_vpc.eks_vpc.id

  ingress {
    description = "Allow all inbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "eks-cluster-sg"
  }
}

# -------------------------------
# 3. IAM Roles
# -------------------------------
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-role"

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

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_container_registry_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# -------------------------------
# 4. EKS Cluster
# -------------------------------
resource "aws_eks_cluster" "eks_cluster" {
  name     = "my-eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids         = [aws_subnet.eks_subnet1.id, aws_subnet.eks_subnet2.id]
    security_group_ids = [aws_security_group.eks_cluster_sg.id]
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

# -------------------------------
# 5. Auto Scaling Group for Worker Nodes
# -------------------------------

# Security Group for worker nodes
resource "aws_security_group" "worker_sg" {
  vpc_id      = aws_vpc.eks_vpc.id
  description = "Security group for worker nodes"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "eks-worker-sg"
  }
}

# IAM Instance Profile for Worker Nodes
resource "aws_iam_instance_profile" "eks_node_profile" {
  name = "eks-node-instance-profile"
  role = aws_iam_role.eks_node_role.name
}

# Launch configuration for Auto Scaling Group
resource "aws_launch_configuration" "eks_worker_lc" {
  name_prefix          = "eks-worker-lc-"
  image_id             = "ami-02d26659fd82cf299"
  instance_type        = "t3.medium"
  key_name             = "windows"
  security_groups      = [aws_security_group.worker_sg.id]
  iam_instance_profile = aws_iam_instance_profile.eks_node_profile.name

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group for worker nodes
resource "aws_autoscaling_group" "eks_worker_asg" {
  name                 = "eks-worker-asg"
  max_size             = 3
  min_size             = 1
  desired_capacity     = 2
  launch_configuration = aws_launch_configuration.eks_worker_lc.id
  vpc_zone_identifier  = [aws_subnet.eks_subnet1.id, aws_subnet.eks_subnet2.id]
  health_check_type    = "EC2"
  force_delete         = true

  tag {
    key                 = "Name"
    value               = "eks-worker-node"
    propagate_at_launch = true
  }

  depends_on = [
    aws_launch_configuration.eks_worker_lc,
    aws_eks_cluster.eks_cluster
  ]
}

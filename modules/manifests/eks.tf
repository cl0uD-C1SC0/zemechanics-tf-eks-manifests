# EKS IAM ACCESS ENTRY
resource "aws_eks_access_entry" "iam-user-access-entry" {
  cluster_name = aws_eks_cluster.zemechanics-cluster.name
  principal_arn = var.aws_iam_user_arn
  type = "STANDARD"
}

resource "aws_eks_access_policy_association" "iam_policy-access-cluster-admin" {
  cluster_name  = aws_eks_cluster.zemechanics-cluster.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = var.aws_iam_user_arn

  access_scope {
    type       = "cluster"
  }
}

resource "aws_eks_access_policy_association" "iam_policy-access-eks-admin" {
  cluster_name  = aws_eks_cluster.zemechanics-cluster.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSAdminPolicy"
  principal_arn = var.aws_iam_user_arn

  access_scope {
    type       = "cluster"
  }
}

# CLUSTER IAM ROLE
resource "aws_iam_role" "cluster-role" {
  name = "eks-cluster-example"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster-role.name
}

# EKS CONFIGS
resource "aws_eks_cluster" "zemechanics-cluster" {
  name = var.cluster_name

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  role_arn = aws_iam_role.cluster-role.arn
  version  = "1.35"

  vpc_config {
    endpoint_public_access = true
    security_group_ids = [ aws_security_group.eks-sg.id ]
    subnet_ids = [aws_subnet.us-east-1a-pub.id, aws_subnet.us-east-1b-pub.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_subnet.us-east-1a-pub, aws_subnet.us-east-1b-pub
  ]
}

# EKS NodeGroup
resource "aws_eks_node_group" "ndg-nodegroup" {
  cluster_name    = aws_eks_cluster.zemechanics-cluster.name
  node_group_name = var.nodegroup_name
  node_role_arn   = aws_iam_role.ndg-role.arn
  subnet_ids      = [ aws_subnet.us-east-1a-pub.id, aws_subnet.us-east-1b-pub.id ]

  scaling_config {
    desired_size = 3
    max_size     = 3
    min_size     = 2
  }

  update_config {
    max_unavailable = 1
  }


  depends_on = [
    aws_eks_cluster.zemechanics-cluster,
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.AmazonEC2ContainerRegistryReadOnly,
  ]
}

resource "aws_iam_role" "ndg-role" {
  name = "zemechanics-ndg-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.ndg-role.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.ndg-role.name

}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.ndg-role.name

}

# EKS ADDONS
resource "aws_eks_addon" "vpc-cni" {
  cluster_name = aws_eks_cluster.zemechanics-cluster.name
  addon_name   = "vpc-cni"

  depends_on = [ aws_eks_cluster.zemechanics-cluster ]
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.zemechanics-cluster.name
  addon_name = "coredns"

  depends_on = [ aws_eks_cluster.zemechanics-cluster ]
}

resource "aws_eks_addon" "kubeproxy" {
  cluster_name = aws_eks_cluster.zemechanics-cluster.name
  addon_name = "kube-proxy"

  depends_on = [ aws_eks_cluster.zemechanics-cluster ]
}

resource "aws_eks_addon" "metricsserver" {
  cluster_name = aws_eks_cluster.zemechanics-cluster.name
  addon_name = "metrics-server"

  depends_on = [ aws_eks_cluster.zemechanics-cluster ]
}

resource "aws_eks_addon" "kube-state-metrics" {
  cluster_name = aws_eks_cluster.zemechanics-cluster.name
  addon_name = "kube-state-metrics"

  depends_on = [ aws_eks_cluster.zemechanics-cluster ]
}

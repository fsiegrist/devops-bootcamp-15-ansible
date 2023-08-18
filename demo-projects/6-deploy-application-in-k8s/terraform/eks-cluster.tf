module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.2"

  cluster_name = "myapp-eks-cluster"  
  cluster_version = "1.27"  # kubernetes version

  vpc_id = module.vpc.vpc_id                # inspect the available outputs of the vpc module
  subnet_ids = module.vpc.private_subnets   # inspect the available outputs of the vpc module

  eks_managed_node_groups = {  # copied (and adjusted) from the examples on the eks module documentation page
    dev = {
      min_size     = 1
      max_size     = 3
      desired_size = 3

      instance_types = ["t2.small"]
    }
  }

  cluster_endpoint_private_access = false
  cluster_endpoint_public_access = true

  tags = {  # there are no mandatory tags for an eks cluster
    environment = "development"
    application = "myapp"
  }
}
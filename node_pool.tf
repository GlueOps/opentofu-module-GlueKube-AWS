module "node_pool" {
  for_each               = { for np in var.node_pools : np.name => np }
  source                 = "./modules/gluekube"
  name                   = each.value.name
  instance_type          = each.value.instance_type
  storage_size_gb        = each.value.storage_size_gb
  image                  = each.value.image
  role                   = each.value.role
  node_count             = each.value.node_count
  kubernetes_labels      = each.value.kubernetes_labels
  kubernetes_annotations = each.value.kubernetes_annotations
  kubernetes_taints      = each.value.kubernetes_taints
  vpc_id                 = module.vpc.vpc_id
  subnet_ids             = each.value.subnet == "public" ? module.vpc.public_subnets : (each.value.subnet == "intra" ? module.vpc.intra_subnets : module.vpc.private_subnets)
  vpc_cidr               = var.vpc_cidr_block
  cluster_name           = var.autoglue.autoglue_cluster_name
  attached               = each.value.attached
  region                 = var.region
}

resource "autoglue_cluster_node_pools" "autoglue_cluster_node_pools" {
  cluster_id = autoglue_cluster.cluster.id
  node_pool_ids = [
    for np in module.node_pool : np.node_pool_id  if np.attached
  ]
}

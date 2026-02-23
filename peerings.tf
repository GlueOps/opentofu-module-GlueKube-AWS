
module "vpc_peering_accepter_with_routes" {
  for_each = { for pc in var.peering_configs : "${pc.vpc_peering_connection_id}-${pc.destination_cidr_block}" => pc }
  source   = "./modules/vpc_peering_accepter_with_routes"

  route_table_ids = try(each.value.include_intra_routes, false) ? concat(module.vpc.private_route_table_ids, module.vpc.public_route_table_ids, module.vpc.intra_route_table_ids) : concat(module.vpc.private_route_table_ids, module.vpc.public_route_table_ids)

  peering_configs = [{
    vpc_peering_connection_id = each.value.vpc_peering_connection_id
    destination_cidr_block    = each.value.destination_cidr_block
  }]
}
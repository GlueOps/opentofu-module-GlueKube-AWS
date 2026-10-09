output "role" {
  value = var.role
}

output "master_private_ips" {
  value = var.role == "master" ? sort([for s in autoglue_server.node : s.private_ip_address]) : []
}

output "node_pool_id" {
  value = autoglue_node_pool.node_pool.id
}
output "attached" {
  value = var.attached
}

output "instance_amis" {
  value = { for k, instance in aws_instance.cluster_node : k => instance.ami }
}

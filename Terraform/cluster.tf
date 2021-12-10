resource "digitalocean_kubernetes_cluster" "do_challenge" {
  name    = "do-challenge-cluster"
  region  = var.cluster_region
  version = var.cluster_version

  vpc_uuid     = digitalocean_vpc.do_challenege_vpc.id
  auto_upgrade = var.cluster_auto_upgrade

  maintenance_policy {
    start_time = "01:00"
    day        = "sunday"
  }

  node_pool {
    name       = "cluster-node-pool"
    size       = "s-2vcpu-4gb"
    auto_scale = true
    min_nodes  = var.cluster_autoscale_min_nodes
    max_nodes  = var.cluster_autoscale_max_nodes
  }
}

resource "digitalocean_vpc" "do_challenege_vpc" {
  name     = "do-challenge-vpc"
  region   = var.cluster_region
  ip_range = "10.0.0.0/16"
}

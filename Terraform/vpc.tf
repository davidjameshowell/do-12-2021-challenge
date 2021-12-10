resource "digitalocean_vpc" "do_challenege_vpc" {
  name     = "do_challenge_vpc"
  region   = "sf03"
  ip_range = "10.0.0.0/16"
}

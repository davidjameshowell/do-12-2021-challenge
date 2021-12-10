terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
  backend "s3" {
    bucket                      = "djh-projects-do-challenge-statefiles"
    key                         = "do-challenge-12-2021-k8-cluster"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    region                      = "us-west-2"
    endpoint                    = "sfo3.digitaloceanspaces.com"
  }
}

provider "digitalocean" {
  token = var.do_token
}

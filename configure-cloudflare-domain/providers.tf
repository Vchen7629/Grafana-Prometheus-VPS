terraform {
  required_providers {
    cloudflare = {
        source = "cloudflare/cloudflare"
        version = "~> 4"
    }
  }
}

provider "cloudflare" {
    api_token = var.cloudflare-api-token
}
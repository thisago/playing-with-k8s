terraform {
  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "2.27.1"
    }
  }
}

provider "vultr" {}

resource "vultr_vpc" "kbvpc1" {
  description = "Kubernetes VPC 1"
  region      = "sea"
}

resource "vultr_kubernetes" "kbcl1" {
  label   = "kbcl1"
  region  = vultr_vpc.kbvpc1.region
  version = "v1.33.0+3"

  vpc_id = vultr_vpc.kbvpc1.id

  node_pools {
    label         = "kbpl1"
    plan          = "vc2-1c-2gb"
    node_quantity = 1
  }
}

# commands to import
# tofu -chdir=tofu import vultr_vpc2.kbvpc1 vpc-123456
# tofu -chdir=tofu import vultr_kubernetes.cluster k8s-123456

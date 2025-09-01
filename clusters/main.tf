terraform {
  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "2.27.1"
    }
  }
  backend "local" {
    path = "tfstates/terraform.tfstate"
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
    plan          = var.one_cpu_two_gb_ram
    node_quantity = 1
  }
}

resource "local_file" "kbcl1_kube_config" {
  content         = base64decode(vultr_kubernetes.kbcl1.kube_config)
  filename        = var.kubeconfig_path
  file_permission = "0600"
  depends_on      = [vultr_kubernetes.kbcl1]
}

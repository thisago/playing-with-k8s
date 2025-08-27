output "control_pane_ip" {
  value = vultr_kubernetes.kbcl1.ip
}

output "kubeconfig" {
  value = vultr_kubernetes.kbcl1.kube_config
  description = "Kubeconfig file content to access the EKS cluster"
  sensitive = true
}

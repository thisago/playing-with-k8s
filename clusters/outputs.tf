output "control_pane_ip" {
  value = vultr_kubernetes.kbcl1.ip
}

output "kubeconfig_path" {
  description = "Full path to the rendered kubeconfig file (local_file resource output)"
  value       = local_file.kbcl1_kube_config.filename
}

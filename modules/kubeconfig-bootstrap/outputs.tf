output "kubeconfig_path" {
  description = "Path of the generated kubeconfig file"
  value       = local_sensitive_file.kubeconfig.filename
}

output "kubeconfig" {
  description = "Generated kubeconfig content"
  value       = local_sensitive_file.kubeconfig.content
  sensitive   = true
}

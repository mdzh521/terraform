apiVersion: v1
kind: Config
clusters:
  - name: ${cluster_name}
    cluster:
      server: ${endpoint}
      certificate-authority-data: ${cluster_ca}
users:
  - name: ${service_account}@${cluster_name}
    user:
      token: ${sa_token}
contexts:
  - name: ${service_account}@${cluster_name}
    context:
      cluster: ${cluster_name}
      user: ${service_account}@${cluster_name}
current-context: ${service_account}@${cluster_name}

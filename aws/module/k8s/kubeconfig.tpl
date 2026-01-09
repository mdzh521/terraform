apiVersion: v1
kind: Config
clusters:
  - name: ${cluster_name}
    cluster:
      certificate-authority-data: ${cluster_ca}
      server: ${endpoint}
contexts:
  - name: ${service_account}@${cluster_name}
    context:
      cluster: ${cluster_name}
      user: ${service_account}
users:
  - name: ${service_account}
    user:
      token: ${sa_token}
current-context: ${service_account}@${cluster_name}
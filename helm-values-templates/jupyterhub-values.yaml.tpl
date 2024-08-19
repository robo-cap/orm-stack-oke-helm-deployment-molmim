---
singleuser:
  defaultUrl: "/lab"
  extraEnv:
    JUPYTERHUB_SINGLEUSER_APP: "jupyter_server.serverapp.ServerApp"
  %{ if playbooks_repo != "" }
  lifecycleHooks:
    postStart:
      exec:
        command:
          [
            "/bin/sh",
            "-c",
            "git -C examples pull || git clone ${playbooks_repo} examples"
          ]
  %{ endif }
  cloudMetadata:
    blockWithIptables: false
  image:
    name: quay.io/jupyter/scipy-notebook
    tag: ubuntu-22.04
hub:
  config:
    Authenticator:
      admin_users:
        - ${admin_user}
    DummyAuthenticator:
        password: '${admin_password}'
    JupyterHub:
      authenticator_class: dummy

ingress:
  enabled: true
  ingressClassName: nginx
  annotations:
    cert-manager.io/cluster-issuer: "le-clusterissuer"

proxy:
  service:
    type: ClusterIP
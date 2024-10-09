# orm-stack-oke-helm-deployment-molmim

## Getting started

This stack deploys an OKE cluster with two nodepools:
- one nodepool with flexible shapes
- one nodepool with GPU shapes

And several supporting applications using helm:
- nginx
- cert-manager
- jupyterhub

With the scope of demonstrating [nVidia NIM MolMIM](https://docs.nvidia.com/nim/bionemo/molmim/latest/index.html) self-hosted model capabilities.

**Note:** For helm deployments it's necessary to create bastion and operator host (with the associated policy for the operator to manage the clsuter), **or** configure a cluster with public API endpoint.

In case the bastion and operator hosts are not created, is a prerequisite to have the following tools already installed and configured:
- bash
- helm
- jq
- kubectl
- oci-cli

## Helm Deployments

### Nginx

[Nginx](https://kubernetes.github.io/ingress-nginx/deploy/) is deployed and configured as default ingress controller.

### Cert-manager

[Cert-manager](https://cert-manager.io/docs/) is deployed to handle the configuration of TLS certificate for the configured ingress resources. Currently it's using the [staging Let's Encrypt endpoint](https://letsencrypt.org/docs/staging-environment/).

### Jupyterhub

[Jupyterhub](https://jupyterhub.readthedocs.io/en/stable/) will be accessible to the address: [https://jupyter.a.b.c.d.nip.io](https://jupyter.a.b.c.d.nip.io), where a.b.c.d is the public IP address of the load balancer associated with the NGINX ingress controller.

JupyterHub is using a dummy authentication scheme (user/password) and the access is secured using the variables:

```
jupyter_admin_user
jupyter_admin_password
```

It also supports the option to automatically clone a git repo when user is connecting and making it available under `examples` directory.

If you are looking to integrate JupyterHub with an Identity Provider, please take a look at the options available here: https://oauthenticator.readthedocs.io/en/latest/tutorials/provider-specific-setup/index.html

For integration with your OCI tenancy IDCS domain, you may go through the following steps:

1. Setup a new **Application** in IDCS

- Navigate to the following address: https://cloud.oracle.com/identity/domains/

- Click on the `OracleIdentityCloudService` domain

- Navigate to `Integrated applications` from the left-side menu

- Click **Add application**

- Select *Confidential Application* and click **Launch worflow**

2. Application configuration

- Under *Add application details* configure

    name: `Jupyterhub`

    (all the other fields are optional, you may leave them empty)

- Under *Configure OAuth*

    Resource server configuration -> *Skip for later*

    Client configuration -> *Configure this application as a client now*

    Authorization:
    - Check the `Authorization code` check-box
    - Leave the other check-boxes unchecked

    Redirect URL:

    `https://<jupyterhub-domain>/hub/oauth_callback`

- Under *Configure policy*
    
    Web tier policy -> *Skip for later*

- Click **Finish**

- Scroll down wehere you fill find the *General Information* section.

- Copy the `Client ID` and `Client secret`:

- Click **Activate** button at the top.

3. Connect to the OKE cluster and update the JupyterHub Helm deployment values.

- Create a file named `oauth2-values.yaml` with the following content (make sure to fill-in the values relevant for your setup)

    ```yaml
    hub:
      config:
        Authenticator:
          allow_all: true
        GenericOAuthenticator:
          client_id: <client-id>
          client_secret: <client-secret>

          authorize_url:  <idcs-stripe-url>/oauth2/v1/authorize
          token_url:  <idcs-stripe-url>/oauth2/v1/token
          userdata_url:  <idcs-stripe-url>/oauth2/v1/userinfo

          scope:
          - openid
          - email
          username_claim: "email"
        JupyterHub:
          authenticator_class: generic-oauth
    ```

    **Note:** IDCS stripe URL can be fetched from the OracleIdentityCloudService IDCS Domain Overview -> Domain Information -> Domain URL.

    Should be something like this: `https://idcs-18bb6a27b33d416fb083d27a9bcede3b.identity.oraclecloud.com`


- Execute the following command to update the JupyterHub Helm deployment:

    ```bash
    helm upgrade jupyterhub jupyterhub --repo https://hub.jupyter.org/helm-chart/ --reuse-values -f oauth2-values.yaml
    ```


### NIM MolMIM

MolMIM is deployed using [NIM](https://docs.nvidia.com/nim/index.html).

Parameters:
- `nim_image_repository` and `nim_image_tag` - used to specify the container image location
- `NGC_API_KEY` - required to authenticate with NGC services

To customize the helm chart deployment, create a file `nim_user_values_override.yaml` with the values override.

In case of manual deployment, assign this multiline string to the `nim_user_values_override` variable.

## How to deploy?

1. Deploy via ORM
- Create a new stack
- Upload the TF configuration files
- Configure the variables
- Apply

2. Local deployment

- Create a file called `terraform.auto.tfvars` with the required values.

```
# ORM injected values

region            = "eu-frankfurt-1"
tenancy_ocid      = "ocid1.tenancy.oc1..aaaaaaaaiyavtwbz4kyu7g7b6wglllccbflmjx2lzk5nwpbme44mv54xu7dq"
compartment_ocid  = "ocid1.compartment.oc1..aaaaaaaaqi3if6t4n24qyabx5pjzlw6xovcbgugcmatavjvapyq3jfb4diqq"

# OKE Terraform module values
create_iam_resources     = false
create_iam_tag_namespace = false
ssh_public_key           = "<ssh_public_key>"

## NodePool with non-GPU shape is created by default with size 1
simple_np_flex_shape   = { "instanceShape" = "VM.Standard.E4.Flex", "ocpus" = 2, "memory" = 16 }

## NodePool with GPU shape is created by default with size 0
gpu_np_size  = 1
gpu_np_shape = "VM.GPU.A10.1"

## OKE Deployment values
cluster_name           = "oke"
vcn_name               = "oke-vcn"
compartment_id         = "ocid1.compartment.oc1..aaaaaaaaqi3if6t4n24qyabx5pjzlw6xovcbgugcmatavjvapyq3jfb4diqq"

# Jupyter Hub deployment values
jupyter_admin_user     = "oracle-ai"
jupyter_admin_password = "<admin-passowrd>"
playbooks_repo         = "https://github.com/robo-cap/molmim-jupyter-notebooks.git"

# NIM Deployment values
nim_image_repository   = "nvcr.io/nim/nvidia/molmim"
nim_image_tag          = "1.0.0"
NGC_API_KEY            = "<ngc_api_key>"
```

- Execute the commands

```
terraform init
terraform plan
terraform apply
```

## Known Issues

If `terraform destroy` fails, manually remove the LoadBalancer resource configured for the Nginx Ingress Controller.

After `terrafrom destroy`, the block volumes corresponding to the PVCs used by the applications in the cluster won't be removed. You have to manually remove them.

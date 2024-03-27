# Boundary Multi-Cloud Demo

## Quick Start

1. You must have an HCP Boundary and Vault cluster deployed.
2. Create a terraform.auto.tfvars file following the example.
3. Logging into a doormat managed Azure short-term subscription in hashicorp02:

```shell
az login --tenant 237fbc04-c52a-458b-af97-eaf7157c0cd4
```

4. Logging into AWS via doormat:

```shell
doormat login && eval $(doormat aws export --account aws_nick.wong_test)
```

5. Make sure Boundary workers are functional in AWS and Azure. Workers should
   have a `Last Seen` status within seconds when you view it in the admin console.
   Also check that the `boundary` systemd service is running in the VM.

```shell
sudo systemctl status -l boundary
sudo journalctl -xfe -u boundary.service
```

6. Once all infrastructures are functionality. Test out the target connection using 
   the demo scripts in the `scripts` folder. Remember to export the `BOUNDARY_ADD`
   env variable and the target ID before executing the script.

## TODO
- Added Multi-Hop workers by connecting self-managed workers in a private subnet with HCP workers. 

## Notes

- Use [Auth0 OIDC well-know endpoint](https://dev-p6g32x14ae33zvpy.us.auth0.com/.well-known/openid-configuration) to determine available claims.
- Use the [Auth0 Authentication API Debugger Extension](https://auth0.com/docs/customize/extensions/authentication-api-debugger-extension) to see the id_token returned.
- Use [Auth0 Flow Actions](https://community.auth0.com/t/how-to-add-roles-and-permissions-to-the-id-token-using-actions/84506) to add custom claims to the id_token.

## Resources
- [Alex Harness: Boundary Multi-Cloud demo](https://github.com/mocofound/multicloud-pam-hcp-boundary/tree/main)
- [Danny Knights: Vault Credential Injection For Boundary](https://github.com/dannyjknights/vault-credential-injection-for-boundary)
- [Danny Knights: Boundary Session Recording Demo](https://github.com/dannyjknights/hcp-boundary-session-recording)
- [Danny Knights: Boundary OIDC Demo](https://github.com/dannyjknights/hcp-boundary-okta-oidc)
- [Jose Merchan: Simple Boundary Demo](https://github.com/jm-merchan/Simple_Boundary_Demo/tree/master)
- [Access the internet from a private subnet using a NAT gateway](https://docs.aws.amazon.com/vpc/latest/userguide/nat-gateway-scenarios.html#public-nat-internet-access)
- [Doormat session minimum permission requirements](https://docs.prod.secops.hashicorp.services/base_images/aws_ami/#minimum-permissions)
- [Install Boundary under systemd](https://developer.hashicorp.com/boundary/docs/install-boundary/systemd)
- [Doormat access thru Azure CLI](https://docs.prod.secops.hashicorp.services/doormat/cli/azure/)
- [AKS Networking Deep Dive](https://inder-devops.medium.com/aks-networking-deep-dive-kubenet-vs-azure-cni-vs-azure-cni-overlay-a51709171ce9#:~:text=Pods%20CIDR,communicate%20directly%20with%20each%20other.)
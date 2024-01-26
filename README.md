# Boundary Multi-Cloud Demo

## Notes

- Use [Auth0 OIDC well-know endpoint](https://dev-p6g32x14ae33zvpy.us.auth0.com/.well-known/openid-configuration) to determine available claims.
- Use the [Auth0 Authentication API Debugger Extension](https://auth0.com/docs/customize/extensions/authentication-api-debugger-extension) to see the id_token returned.
- Use [Auth0 Flow Actions](https://community.auth0.com/t/how-to-add-roles-and-permissions-to-the-id-token-using-actions/84506) to add custom claims to the id_token.

## Resources
[Alex Harness: Boundary Multi-Cloud demo](https://github.com/mocofound/multicloud-pam-hcp-boundary/tree/main)
[Danny Knights: Vault Credential Injection For Boundary](https://github.com/dannyjknights/vault-credential-injection-for-boundary)
[Danny Knights: Boundary Session Recording Demo](https://github.com/dannyjknights/hcp-boundary-session-recording)
[Danny Knights: Boundary OIDC Demo](https://github.com/dannyjknights/hcp-boundary-okta-oidc)
[Jose Merchan: Simple Boundary Demo](https://github.com/jm-merchan/Simple_Boundary_Demo/tree/master)
[Access the internet from a private subnet using a NAT gateway](https://docs.aws.amazon.com/vpc/latest/userguide/nat-gateway-scenarios.html#public-nat-internet-access)
[Doormat session minimum permission requirements](https://docs.prod.secops.hashicorp.services/base_images/aws_ami/#minimum-permissions)
[Install Boundary under systemd](https://developer.hashicorp.com/boundary/docs/install-boundary/systemd)
[Doormat access thru Azure CLI](https://docs.prod.secops.hashicorp.services/doormat/cli/azure/)
data "hcp_hvn" "vault_hvn" {
  hvn_id = var.vault_hvn_id
}

resource "hcp_aws_network_peering" "peer" {
  hvn_id          = data.hcp_hvn.vault_hvn.hvn_id
  peering_id      = "boundary-multi-cloud-demo-peering"
  peer_vpc_id     = aws_vpc.boundary_poc.id
  peer_account_id = aws_vpc.boundary_poc.owner_id
  peer_vpc_region = var.aws_region
}

resource "hcp_hvn_route" "peer_route" {
  hvn_link         = data.hcp_hvn.vault_hvn.self_link
  hvn_route_id     = "boundary-multi-cloud-demo-route"
  destination_cidr = aws_vpc.boundary_poc.cidr_block
  target_link      = hcp_aws_network_peering.peer.self_link
}

resource "aws_vpc_peering_connection_accepter" "peer" {
  vpc_peering_connection_id = hcp_aws_network_peering.peer.provider_peering_id
  auto_accept               = true
}

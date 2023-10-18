resource "nsxt_policy_project" "project-green" {
  display_name        = "project-green"
  nsx_id              = "project-green"
  description         = "Terraform provisioned Project"
  short_id            = "green"
  tier0_gateway_paths = ["/infra/tier-0s/parent-t0"]
  site_info {
     edge_cluster_paths  = ["/infra/sites/default/enforcement-points/default/edge-clusters/9d4c32ae-25f4-47ac-a98e-74c4832869b0"]
     }
  depends_on = [nsxt_policy_tier0_gateway.parent-t0 ]
}


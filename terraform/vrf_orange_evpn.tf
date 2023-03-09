resource "nsxt_policy_tier0_gateway" "vrf-orange" {
  description              = "Tier-0 VRF provisioned by Terraform"
  display_name             = "vrf-orange"
  nsx_id                   = "vrf-orange"
  failover_mode            = "PREEMPTIVE"
  default_rule_logging     = false
  enable_firewall          = true
  ha_mode                  = "ACTIVE_ACTIVE"
  edge_cluster_path        = data.nsxt_policy_edge_cluster.ec.path
  vrf_config {
    gateway_path        = nsxt_policy_tier0_gateway.parent-t0.path
    route_distinguisher = "65002:1"
    evpn_transit_vni    = 76100
    route_target {
      auto_mode      = false
      import_targets = ["65100:1"]
      export_targets = ["65002:1"]
    }
  }
}

resource "nsxt_policy_gateway_redistribution_config" "parent-t0-vrf-orange" {
  gateway_path = nsxt_policy_tier0_gateway.vrf-orange.path
  bgp_enabled  = true

  rule {
    name  = "rule-1"
    types = ["TIER0_STATIC", "TIER0_CONNECTED", "TIER0_EXTERNAL_INTERFACE", "TIER0_SEGMENT", "TIER0_ROUTER_LINK", "TIER0_SERVICE_INTERFACE", "TIER0_LOOPBACK_INTERFACE", "TIER0_DNS_FORWARDER_IP", "TIER0_IPSEC_LOCAL_IP", "TIER0_NAT", "TIER1_NAT", "TIER1_STATIC", "TIER1_LB_VIP", "TIER1_LB_SNAT", "TIER1_DNS_FORWARDER_IP", "TIER1_CONNECTED", "TIER1_SERVICE_INTERFACE", "TIER1_SEGMENT", "TIER1_IPSEC_LOCAL_ENDPOINT" ]
  }
}

resource "nsxt_policy_segment" "vrf-orange-segment-01" {
  display_name        = "vrf-orange-segment-01"
  description         = "Terraform provisioned Segment"
  connectivity_path   = nsxt_policy_tier0_gateway.vrf-orange.path
  transport_zone_path = data.nsxt_policy_transport_zone.overlay_transport_zone.path
  subnet {
    cidr        = "172.16.10.1/24"
    }
}

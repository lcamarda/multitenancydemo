resource "nsxt_policy_tier0_gateway" "vrf-red" {
  description              = "VRF provisioned by Terraform"
  display_name             = "vrf-red"
  failover_mode            = "PREEMPTIVE"
  default_rule_logging     = false
  enable_firewall          = true
  ha_mode                  = "ACTIVE_ACTIVE"
  edge_cluster_path        = data.nsxt_policy_edge_cluster.ec.path

  bgp_config {
    local_as_num    = "65002"
    multipath_relax = false

  }
  vrf_config {
    gateway_path        = nsxt_policy_tier0_gateway.parent-t0.path
  }

  tag {
    scope = "vrf"
    tag   = "red"
  }
}

resource "nsxt_policy_gateway_redistribution_config" "vrf-red-redistribution" {
  gateway_path = nsxt_policy_tier0_gateway.vrf-red.path
  bgp_enabled  = true

  rule {
    name  = "rule-1"
    types = ["TIER0_STATIC", "TIER0_CONNECTED", "TIER0_EXTERNAL_INTERFACE", "TIER0_SEGMENT", "TIER0_ROUTER_LINK", "TIER0_SERVICE_INTERFACE", "TIER0_LOOPBACK_INTERFACE", "TIER0_DNS_FORWARDER_IP", "TIER0_IPSEC_LOCAL_IP", "TIER0_NAT", "TIER1_NAT", "TIER1_STATIC", "TIER1_LB_VIP", "TIER1_LB_SNAT", "TIER1_DNS_FORWARDER_IP", "TIER1_CONNECTED", "TIER1_SERVICE_INTERFACE", "TIER1_SEGMENT", "TIER1_IPSEC_LOCAL_ENDPOINT" ]
  }
}


resource "nsxt_policy_segment" "vrf-red-left" {
  display_name        = "vrf-red-left"
  transport_zone_path = data.nsxt_policy_transport_zone.edge_vlan_transport_zone.path
  vlan_ids = [102]
  advanced_config {
    uplink_teaming_policy = "teaming-1"
  }
}


resource "nsxt_policy_segment" "vrf-red-right" {
  display_name        = "vrf-red-right"
  transport_zone_path = data.nsxt_policy_transport_zone.edge_vlan_transport_zone.path
  vlan_ids = [202]
  advanced_config {
    uplink_teaming_policy = "teaming-2"
  }
}

resource "nsxt_policy_tier0_gateway_interface" "red_vrf_uplink1" {
  display_name   = "node1left"
  type           = "EXTERNAL"
  edge_node_path = data.nsxt_policy_edge_node.node1.path
  gateway_path   = nsxt_policy_tier0_gateway.vrf-red.path
  segment_path   = nsxt_policy_segment.vrf-red-left.path
  subnets        = ["192.168.254.1/24"]
  mtu            = 1500
}


resource "nsxt_policy_tier0_gateway_interface" "red_vrf_uplink2" {
  display_name   = "node2left"
  type           = "EXTERNAL"
  edge_node_path = data.nsxt_policy_edge_node.node2.path
  gateway_path   = nsxt_policy_tier0_gateway.vrf-red.path
  segment_path   = nsxt_policy_segment.vrf-red-left.path
  subnets        = ["192.168.254.2/24"]
  mtu            = 1500
}

resource "nsxt_policy_tier0_gateway_interface" "red_vrf_uplink3" {
  display_name   = "node1right"
  type           = "EXTERNAL"
  edge_node_path = data.nsxt_policy_edge_node.node1.path
  gateway_path   = nsxt_policy_tier0_gateway.vrf-red.path
  segment_path   = nsxt_policy_segment.vrf-red-right.path
  subnets        = ["192.168.253.1/24"]
  mtu            = 1500
}

resource "nsxt_policy_tier0_gateway_interface" "red_vrf_uplink4" {
  display_name   = "node2right"
  type           = "EXTERNAL"
  edge_node_path = data.nsxt_policy_edge_node.node2.path
  gateway_path   = nsxt_policy_tier0_gateway.vrf-red.path
  segment_path   = nsxt_policy_segment.vrf-red-right.path
  subnets        = ["192.168.253.2/24"]
  mtu            = 1500
}

resource "nsxt_policy_bgp_neighbor" "vrf-red-bgp-1" {
  display_name          = "vrf-red-bpg-1"
  description           = "Terraform provisioned BgpNeighborConfig"
  bgp_path              = nsxt_policy_tier0_gateway.vrf-red.bgp_config.0.path
  graceful_restart_mode = "HELPER_ONLY"
  hold_down_time        = 12
  keep_alive_time       = 3
  neighbor_address      = "192.168.254.3"
  remote_as_num         = "65100"
}

resource "nsxt_policy_bgp_neighbor" "vrf-red-bgp-2" {
  display_name          = "vrf-red-bpg-1"
  description           = "Terraform provisioned BgpNeighborConfig"
  bgp_path              = nsxt_policy_tier0_gateway.vrf-red.bgp_config.0.path
  graceful_restart_mode = "HELPER_ONLY"
  hold_down_time        = 12
  keep_alive_time       = 3
  neighbor_address      = "192.168.253.3"
  remote_as_num         = "65100"
}




resource "nsxt_policy_segment" "vrf-red-segment-01" {
  display_name        = "vrf-red-segment-01"
  description         = "Terraform provisioned Segment"
  connectivity_path   = nsxt_policy_tier0_gateway.vrf-red.path
  transport_zone_path = data.nsxt_policy_transport_zone.overlay_transport_zone.path
  subnet {
    cidr        = "172.16.10.1/24"

  }
}

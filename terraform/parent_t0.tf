terraform {
  required_providers {
    nsxt = {
      source = "vmware/nsxt"
    }
  }
}

provider "nsxt" {
  host                 = "lm-paris"
  username             = "admin"
  password             = "VMware1!VMware1!"
  allow_unverified_ssl = true
  max_retries          = 2
}

data "nsxt_policy_transport_zone" "overlay_transport_zone" {
  transport_type = "OVERLAY_STANDARD"
  is_default     = true
}

data "nsxt_policy_transport_zone" "vlan_transport_zone" {
  transport_type = "VLAN_BACKED"
  is_default     = true
}

data "nsxt_policy_transport_zone" "edge_vlan_transport_zone" {
  display_name = "nsx-uplinks-vlan-transportzone"
}

data "nsxt_policy_edge_cluster" "ec" {
  display_name = "EdgeCluster"
}

data "nsxt_policy_edge_node" "node1" {
  edge_cluster_path = data.nsxt_policy_edge_cluster.ec.path
  display_name = "edgenode-01a"
}

data "nsxt_policy_edge_node" "node2" {
  edge_cluster_path = data.nsxt_policy_edge_cluster.ec.path
  display_name = "edgenode-02a"
}


resource "nsxt_policy_tier0_gateway" "parent-t0" {
  description              = "VRF provisioned by Terraform"
  display_name             = "parent-t0"
  failover_mode            = "PREEMPTIVE"
  default_rule_logging     = false
  enable_firewall          = true
  ha_mode                  = "ACTIVE_ACTIVE"
  edge_cluster_path        = data.nsxt_policy_edge_cluster.ec.path

  bgp_config {
    local_as_num    = "65002"
    multipath_relax = false
  }
}



resource "nsxt_policy_segment" "parent-t0-left" {
  display_name        = "parent-t0-left"
  transport_zone_path = data.nsxt_policy_transport_zone.edge_vlan_transport_zone.path
  vlan_ids = [100]
  advanced_config {
    uplink_teaming_policy = "teaming-1"
  }
}


resource "nsxt_policy_segment" "parent-t0-right" {
  display_name        = "parent-t0-right"
  transport_zone_path = data.nsxt_policy_transport_zone.edge_vlan_transport_zone.path
  vlan_ids = [200]
  advanced_config {
    uplink_teaming_policy = "teaming-2"
  }
}

resource "nsxt_policy_tier0_gateway_interface" "parent-t0-uplink1" {
  display_name   = "node1left"
  type           = "EXTERNAL"
  edge_node_path = data.nsxt_policy_edge_node.node1.path
  gateway_path   = nsxt_policy_tier0_gateway.parent-t0.path
  segment_path   = nsxt_policy_segment.parent-t0-left.path
  subnets        = ["192.168.254.1/24"]
  mtu            = 1500
}


resource "nsxt_policy_tier0_gateway_interface" "parent-t0-uplink2" {
  display_name   = "node2left"
  type           = "EXTERNAL"
  edge_node_path = data.nsxt_policy_edge_node.node2.path
  gateway_path   = nsxt_policy_tier0_gateway.parent-t0.path
  segment_path   = nsxt_policy_segment.parent-t0-left.path
  subnets        = ["192.168.254.2/24"]
  mtu            = 1500
}

resource "nsxt_policy_tier0_gateway_interface" "parent-t0-uplink3" {
  display_name   = "node1right"
  type           = "EXTERNAL"
  edge_node_path = data.nsxt_policy_edge_node.node1.path
  gateway_path   = nsxt_policy_tier0_gateway.parent-t0.path
  segment_path   = nsxt_policy_segment.parent-t0-right.path
  subnets        = ["192.168.253.1/24"]
  mtu            = 1500
}

resource "nsxt_policy_tier0_gateway_interface" "parent-t0-uplink4" {
  display_name   = "node2right"
  type           = "EXTERNAL"
  edge_node_path = data.nsxt_policy_edge_node.node2.path
  gateway_path   = nsxt_policy_tier0_gateway.parent-t0.path
  segment_path   = nsxt_policy_segment.parent-t0-right.path
  subnets        = ["192.168.253.2/24"]
  mtu            = 1500
}


resource "nsxt_policy_bgp_neighbor" "parent-t0-bgp-1" {
  display_name          = "parent-t0-bpg-1"
  description           = "Terraform provisioned BgpNeighborConfig"
  bgp_path              = nsxt_policy_tier0_gateway.parent-t0.bgp_config.0.path
  graceful_restart_mode = "HELPER_ONLY"
  hold_down_time        = 12
  keep_alive_time       = 3
  neighbor_address      = "192.168.254.3"
  remote_as_num         = "65100"
  route_filtering {
     address_family   = "L2VPN_EVPN"
  }
  route_filtering {
     address_family   = "IPV4"
  }
}
resource "nsxt_policy_bgp_neighbor" "parent-t0-bgp-2" {
  display_name          = "parent-t0-bpg-2"
  description           = "Terraform provisioned BgpNeighborConfig"
  bgp_path              = nsxt_policy_tier0_gateway.parent-t0.bgp_config.0.path
  graceful_restart_mode = "HELPER_ONLY"
  hold_down_time        = 12
  keep_alive_time       = 3
  neighbor_address      = "192.168.253.3"
  remote_as_num         = "65100"
  route_filtering {
     address_family   = "L2VPN_EVPN"
  }
  route_filtering {
     address_family   = "IPV4"
  }
}

resource "nsxt_policy_gateway_redistribution_config" "parent-t0-redistribution" {
  gateway_path = nsxt_policy_tier0_gateway.parent-t0.path
  bgp_enabled  = true

  rule {
    name  = "rule-1"
    types = ["TIER0_STATIC", "TIER0_CONNECTED", "TIER0_EXTERNAL_INTERFACE", "TIER0_SEGMENT", "TIER0_ROUTER_LINK", "TIER0_SERVICE_INTERFACE", "TIER0_LOOPBACK_INTERFACE", "TIER0_DNS_FORWARDER_IP", "TIER0_IPSEC_LOCAL_IP", "TIER0_NAT", "TIER0_EVPN_TEP_IP", "TIER1_NAT", "TIER1_STATIC", "TIER1_LB_VIP", "TIER1_LB_SNAT", "TIER1_DNS_FORWARDER_IP", "TIER1_CONNECTED", "TIER1_SERVICE_INTERFACE", "TIER1_SEGMENT", "TIER1_IPSEC_LOCAL_ENDPOINT" ]
  }
}

data "nsxt_policy_vni_pool" "vnipool" {
  display_name = "vnipool"
}

resource "nsxt_policy_evpn_config" "evpn_config" {
  display_name = "evpn"
  gateway_path = nsxt_policy_tier0_gateway.parent-t0.path

  mode          = "INLINE"
  vni_pool_path = data.nsxt_policy_vni_pool.vnipool.path
}

resource "nsxt_policy_evpn_tunnel_endpoint" "evpn-endpoint1" {
  display_name = "evpn-endpoint1"

  external_interface_path = nsxt_policy_tier0_gateway_interface.parent-t0-uplink1.path
  edge_node_path          = data.nsxt_policy_edge_node.node1.path

  local_address = "192.18.252.252"
  mtu           = 8800

}

resource "nsxt_policy_evpn_tunnel_endpoint" "evpn-endpoint2" {
  display_name = "evpn-endpoint2"

  external_interface_path = nsxt_policy_tier0_gateway_interface.parent-t0-uplink2.path
  edge_node_path          = data.nsxt_policy_edge_node.node2.path

  local_address = "192.18.252.253"
  mtu           = 8800

}

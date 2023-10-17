terraform {
  required_providers {
    nsxt = {
      source = "vmware/nsxt"
    }
  }
}

provider "nsxt" {
  host                 = "lm-paris"
  username             = "greenadmin@corp.local"
  password             = "VMware1!"
  allow_unverified_ssl = true
  max_retries          = 2
}

data "nsxt_policy_project" "project-green" {
  id = "project-green"
}

data "nsxt_policy_edge_cluster" "edge_cluster" {
  id = "9d4c32ae-25f4-47ac-a98e-74c4832869b0"
}


#data "nsxt_policy_tier0_gateway" "tier0_gw_gateway" {
#  id = "parent-t0"
#}

data "nsxt_policy_service" "ssh" {
  display_name = "SSH"
}

data "nsxt_policy_service" "http" {
  display_name = "HTTP"
}

data "nsxt_policy_service" "https" {
  display_name = "HTTPS"
}

resource "nsxt_policy_tier1_gateway" "green-t1-01" {
  context {
    project_id = data.nsxt_policy_project.project-green.id
  }
  description               = "Tier-1 provisioned by Terraform"
  display_name              = "green-t1-01"
  nsx_id                    = "green-t1-01"
  edge_cluster_path         = data.nsxt_policy_edge_cluster.edge_cluster.path
  failover_mode             = "NON_PREEMPTIVE"
  default_rule_logging      = "false"
  enable_firewall           = "true"
  enable_standby_relocation = "false"
  # force_whitelisting        = "false"
  tier0_path                = "/infra/tier-0s/parent-t0"
  route_advertisement_types = ["TIER1_STATIC_ROUTES", "TIER1_CONNECTED"]

}

# Create DHCP server
resource "nsxt_policy_dhcp_server" "dhcp_server" {
   context {
    project_id = data.nsxt_policy_project.project-green.id
  }
  display_name      = "DHCP Server"
  description       = "Terraform provisioned DHCP Server Config"
  edge_cluster_path = data.nsxt_policy_edge_cluster.edge_cluster.path
  lease_time        = 86400
}

# Create NSX-T Overlay Segment
resource "nsxt_policy_segment" "green-segment-01" {
  context {
    project_id = data.nsxt_policy_project.project-green.id
  }
  display_name        = "green-segment-01"
  nsx_id              = "green-segment-01"
  description         = "Segment created by Terraform"
  connectivity_path   = nsxt_policy_tier1_gateway.green-t1-01.path
  dhcp_config_path    = nsxt_policy_dhcp_server.dhcp_server.path

  subnet {
    cidr        = "172.16.199.1/24"
    dhcp_ranges = ["172.16.199.10-172.16.199.100"]

    dhcp_v4_config {
      server_address = "172.16.199.254/24"
      lease_time     = 86400
      dns_servers    = ["192.168.110.10"]
    }
  }
}

# Create Security Groups
resource "nsxt_policy_group" "web_servers" {
   context {
    project_id = data.nsxt_policy_project.project-green.id
  }
  display_name = "WEB"
  nsx_id       = "WEB"
  description  = "Terraform provisioned Group"

  criteria {
    condition {
      key         = "Tag"
      member_type = "VirtualMachine"
      operator    = "CONTAINS"
      value       = "Web"
    }
  }
}

resource "nsxt_policy_group" "app_servers" {
   context {
    project_id = data.nsxt_policy_project.project-green.id
  }
  display_name = "APP"
  nsx_id       = "APP"
  description  = "Terraform provisioned Group"

  criteria {
    condition {
      key         = "Tag"
      member_type = "VirtualMachine"
      operator    = "CONTAINS"
      value       = "App"
    }
  }
}

resource "nsxt_policy_group" "db_servers" {
   context {
    project_id = data.nsxt_policy_project.project-green.id
  }
  display_name = "DB"
  nsx_id       = "DB"
  description  = "Terraform provisioned Group"
  criteria {
    condition {
      key         = "Tag"
      member_type = "VirtualMachine"
      operator    = "CONTAINS"
      value       = "DB"
    }
  }
}

# Create Custom Services
resource "nsxt_policy_service" "service_tcp8443" {
  context {
    project_id = data.nsxt_policy_project.project-green.id
  }
  description  = "HTTPS service provisioned by Terraform"
  display_name = "TCP_8443"
  nsx_id       = "TCP_8443"
  l4_port_set_entry {
    display_name      = "TCP8443"
    description       = "TCP port 8443 entry"
    protocol          = "TCP"
    destination_ports = ["8443"]
  }
}


# Create Security Policies

# DFW Infrastructure Category Rules
resource "nsxt_policy_security_policy" "Infrastructure" {
  context {
    project_id = data.nsxt_policy_project.project-green.id
  }
  display_name = "Infrastructure"
  description  = "Terraform provisioned Security Policy"
  category     = "Infrastructure"
  locked       = false
  stateful     = true
  tcp_strict   = false

  rule {
    display_name = "Allow DHCP"
    action       = "ALLOW"
    services     = ["/infra/services/DHCP-Server", "/infra/services/DHCP-Client"]
    logged       = false
    notes        = "Allow access to DHCP Server"
  }
}

# DFW Application Category Rules
resource "nsxt_policy_security_policy" "allow_app" {
  context {
    project_id = data.nsxt_policy_project.project-green.id
  }
  display_name = "Allow Application Flows"
  description  = "Terraform provisioned Security Policy"
  category     = "Application"
  locked       = false
  stateful     = true
  tcp_strict   = false

  rule {
    display_name       = "Allow HTTPS to Web Servers"
    destination_groups = [nsxt_policy_group.web_servers.path]
    action             = "ALLOW"
    services           = [data.nsxt_policy_service.https.path]
    logged             = true
    scope              = [nsxt_policy_group.web_servers.path]
  }

  rule {
    display_name       = "Allow TCP 8443 to App Servers"
    source_groups      = [nsxt_policy_group.web_servers.path]
    destination_groups = [nsxt_policy_group.app_servers.path]
    action             = "ALLOW"
    services           = [nsxt_policy_service.service_tcp8443.path]
    logged             = true
    scope              = [nsxt_policy_group.web_servers.path, nsxt_policy_group.app_servers.path]
  }

  rule {
    display_name       = "Allow HTTP to DB Servers"
    source_groups      = [nsxt_policy_group.app_servers.path]
    destination_groups = [nsxt_policy_group.db_servers.path]
    action             = "ALLOW"
    services           = [data.nsxt_policy_service.http.path]
    logged             = true
    scope              = [nsxt_policy_group.app_servers.path, nsxt_policy_group.db_servers.path]
  }
}


resource nsxt_policy_gateway_policy "green_gateway_policy" {
  context {
    project_id = data.nsxt_policy_project.project-green.id
  }
  display_name    = "tf-gw-policy"
  description     = "Terraform provisioned Gateway Policy"
  category        = "LocalGatewayRules"
  locked          = false
  sequence_number = 1
  stateful        = true
  tcp_strict      = false

  rule {
    display_name       = "rule1"
    destination_groups = [nsxt_policy_group.app_servers.path, nsxt_policy_group.web_servers.path]
    disabled           = true
    action             = "ALLOW"
    logged             = true
    scope              = [nsxt_policy_tier1_gateway.green-t1-01.path]
  }
}

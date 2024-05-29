locals {
  image_name = var.image
  ip = {
    authorized = var.whitelist_ips
    private    = ["10.0.0.0/28", "10.1.0.0/28", "10.2.0.0/28"]
  }

  domain = var.dns_name
}

resource "google_cloud_run_service" "service" {
  location = var.region
  name     = var.name

  template {
    spec {
      container_concurrency = 1
      timeout_seconds       = 600
      service_account_name  = var.service_account

      containers {
        image = local.image_name
        dynamic "env" {
          for_each = var.env_vars
          content {
            name  = env.key
            value = env.value
          }
        }
      }
    }
  }

  metadata {
    annotations = {
      #    This sets the service to only allow all traffic
      "run.googleapis.com/ingress" = "all"
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
  autogenerate_revision_name = true
}


resource "google_compute_global_address" "service-lb-ip" {
  count = var.is_public ? 1 : 0
  name  = "${var.name}-lb-ip"
}

resource "google_compute_region_network_endpoint_group" "serverless-neg" {
  name                  = "${var.name}-serverless-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region
  cloud_run {
    service = google_cloud_run_service.service.name
  }
}

resource "google_compute_security_policy" "security-policy" {
  name = "${var.name}-security"

  rule {
    action   = "allow"
    priority = "1000"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        // Whitelist the local VPC network and any additional authorized routes
        src_ip_ranges = length(local.ip.authorized) > 0 ? concat(local.ip.authorized, local.ip.private) : local.ip.private
      }
    }
    description = "Allow access to authorized IPs only"
  }

  // Global deny rule for all other traffic
  rule {
    action   = "deny(403)"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "default deny rule"
  }
}

module "service-loadbalancer" {
  source  = "GoogleCloudPlatform/lb-http/google//modules/serverless_negs"
  version = "~> 6.0"
  name    = "${var.name}-service"
  project = var.project

  address        = var.is_public ? google_compute_global_address.service-lb-ip[0].address : ""
  create_address = var.is_public ? false : true

  ssl                             = var.is_public
  managed_ssl_certificate_domains = var.is_public ? [local.domain] : []
  https_redirect                  = true

  backends = {
    default = {
      description = null
      groups = [
        {
          group = google_compute_region_network_endpoint_group.serverless-neg.id
        }
      ]
      enable_cdn              = false
      security_policy         = null
      custom_request_headers  = null
      custom_response_headers = null
      security_policy         = google_compute_security_policy.security-policy.id

      iap_config = {
        enable               = false
        oauth2_client_id     = ""
        oauth2_client_secret = ""
      }
      log_config = {
        enable      = false
        sample_rate = null
      }
    }
  }
}


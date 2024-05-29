output "cloud-run-ip" {
  value = var.is_public ? google_compute_global_address.service-lb-ip[0].address : ""
}

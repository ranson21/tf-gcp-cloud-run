variable "project" {
  description = "Name of the GCP Project"
  type        = string
}

variable "name" {
  description = "Name of the service that will be deployed"
  type        = string
}

variable "image" {
  description = "Docker image to use with Cloud Run"
  type        = string
}

variable "dns_name" {
  description = "DNS Name for the Service"
  type        = string
}

variable "region" {
  description = "Geographic region for hosting the project"
  type        = string
}

/**
* Begin Default Variables
*/
variable "is_public" {
  description = "Set whether to add an SSL certificate"
  type        = bool
  default     = false
}

variable "whitelist_ips" {
  description = "List of IP addresses to whitelist"
  type        = list(string)
  default     = []
}

variable "service_account" {
  type        = string
  description = "Service Account to attach to the cloud run instance, leave empty to use default compute creds"
  default     = ""
}

variable "env_vars" {
  type        = map(string)
  description = "Environment Variables for the Container Instance"
  default     = {}
}

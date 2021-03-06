variable "cluster_name" {}
variable "worker_instance_type" {}
variable "worker_instance_min_count" {}
variable "worker_instance_max_count" {}

variable "autoscale_security_group" {}

variable "worker_instance_storage_size" {}

variable "vpc_id" {}
variable "subnet_ids" {
  type = "list"
}

variable "eks_endpoint" {}
variable "eks_certificate_authority" {}

variable "public_key" {}

variable "enable_ssh" {
  default = false
}
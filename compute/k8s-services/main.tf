# --------------------------------------------------
# Init
# --------------------------------------------------

terraform {
  backend          "s3"             {}
  required_version = "~> 0.11.7"
}

provider "aws" {
  region  = "${var.aws_region}"
  version = "~> 1.40"

  assume_role {
    role_arn = "${var.aws_assume_role_arn}"
  }
}

provider "kubernetes" {
  config_path = "${pathexpand("~/.kube/config_${var.eks_cluster_name}")}"
}

provider "helm" {
  kubernetes {
    config_path = "${pathexpand("~/.kube/config_${var.eks_cluster_name}")}"
  }
}

# --------------------------------------------------
# Get remote state of cluster deployment
# --------------------------------------------------

data "terraform_remote_state" "cluster" {
  backend = "s3"

  config {
    bucket = "${var.terraform_state_s3_bucket}"
    key    = "${var.aws_region}/k8s-${var.eks_cluster_name}/cluster/terraform.tfstate"
    region = "${var.terraform_state_region}"
  }
}

# --------------------------------------------------
# KIAM
# --------------------------------------------------

module "kiam_deploy" {
  source                  = "../../_sub/compute/k8s-kiam"                           # rename before release
  deploy                  = "${var.kiam_deploy}"
  cluster_name            = "${var.eks_cluster_name}"
  aws_workload_account_id = "${var.aws_workload_account_id}"
  worker_role_id          = "${data.terraform_remote_state.cluster.eks_worker_role_id}"
}

# --------------------------------------------------
# Service Broker
# --------------------------------------------------

module "servicebroker_deploy" {
  source                  = "../../_sub/compute/k8s-servicebroker"  # rename before release
  deploy                  = "${var.servicebroker_deploy}"
  aws_region              = "${var.aws_region}"
  aws_workload_account_id = "${var.aws_workload_account_id}"
  cluster_name            = "${var.eks_cluster_name}"
  table_name              = "eks-servicebroker-${var.eks_cluster_name}"
  kiam_server_role_id     = "${module.kiam_deploy.kiam_server_role_id}"
}

# --------------------------------------------------
# Flux
# --------------------------------------------------

module "flux_deploy" {
  source            = "../../_sub/compute/k8s-flux"
  deploy            = "${var.flux_deploy}"
  cluster_name      = "${var.eks_cluster_name}"
  namespace         = "${var.flux_k8s_namespace}"
  git_url           = "${var.flux_git_url}"
  git_branch        = "${var.flux_git_branch}"
  git_label         = "${var.flux_git_label}"
  git_key           = "${base64decode(var.flux_git_key_base64)}"
  registry_endpoint = "${var.flux_registry_endpoint}"
  registry_username = "${var.flux_registry_username}"
  registry_password = "${var.flux_registry_password}"
  registry_email    = "${var.flux_registry_email}"
}

# --------------------------------------------------
# Harbor
# --------------------------------------------------

# module "harbor_s3" {
#   source    = "../../_sub/storage/s3-bucket"
#   deploy    = "${var.harbor_deploy}"
#   s3_bucket = "${var.harbor_s3_bucket}"
# }

# module "harbor_postgres" {
#   source = "../../_sub/database/rds-postgres-harbor"
#   deploy = "${var.harbor_deploy}"

#   vpc_id                                 = "${module.eks_cluster.vpc_id}"
#   allow_connections_from_security_groups = ["${module.eks_workers.nodes_sg_id}"]
#   subnet_ids                             = "${module.eks_cluster.subnet_ids}"

#   # postgresdb_engine_version = "${var.harbor_postgresdb_engine_version}"
#   db_storage_size           = "${var.harbor_db_storage_size}"
#   db_instance_size          = "${var.harbor_db_instance_size}"
#   db_server_identifier      = "${var.harbor_db_server_identifier}"
#   db_name                   = "postgres-${var.eks_cluster_name}"
#   db_username               = "${var.harbor_db_server_username}"
#   db_password               = "${var.harbor_db_server_password}"
#   port                      = "${var.harbor_db_server_port}"

#   harbor_k8s_namespace = "${var.harbor_k8s_namespace}"
# }

# module "harbor_deploy" {
#   source = "../../_sub/compute/k8s-harbor"
#   deploy = "${var.harbor_deploy}"

#   cluster_name   = "${var.eks_cluster_name}"
#   namespace      = "${var.harbor_k8s_namespace}"
#   worker_role_id = "${data.terraform_remote_state.cluster.eks_worker_role_id}"

#   registry_endpoint              = "registry.${var.eks_cluster_name}.${var.dns_zone_name}"
#   registry_endpoint_external_url = "https://registry.${var.eks_cluster_name}.${var.dns_zone_name}"
#   notary_endpoint                = "notary.${var.eks_cluster_name}.${var.dns_zone_name}"

#   db_server_host     = "${module.harbor_postgres.db_address}"
#   db_server_username = "${var.harbor_db_server_username}"
#   db_server_password = "${var.harbor_db_server_password}"
#   db_server_port     = "${var.harbor_db_server_port}"

#   bucket_name        = "${module.harbor_s3.bucket_name}"
#   s3_region          = "${var.aws_region}"
#   s3_region_endpoint = "http://s3.${var.aws_region}.amazonaws.com"
#   s3_acces_key       = "${var.harbor_s3_acces_key}"
#   s3_secret_key      = "${var.harbor_s3_secret_key}"
# }
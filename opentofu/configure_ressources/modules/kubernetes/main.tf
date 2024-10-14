terraform {
  required_providers {
    kubernetes = {
      source  = "opentofu/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "opentofu/helm"
      version = "~> 2.15.0"
    }
  }
}

locals {
  namespaces = ["gitlab", "gitlab-runner", "dev", "stg", "prod", "monitoring"]
  creating = ["dev", "stg", "prod", "monitoring"]
}

resource "kubernetes_namespace_v1" "environments" {
  for_each = toset(local.creating)

  metadata {
    name = each.key
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "null_resource" "namespace_creation_check" {
  for_each = kubernetes_namespace_v1.environments

  triggers = {
    namespace_name = each.value.metadata[0].name
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Checking namespace ${each.value.metadata[0].name}"
      kubectl get namespace ${each.value.metadata[0].name} || (echo "Namespace ${each.value.metadata[0].name} not found" && exit 1)
    EOT
  }

  depends_on = [kubernetes_namespace_v1.environments]
}

output "created_namespaces" {
  value = [for ns in kubernetes_namespace_v1.environments : ns.metadata[0].name]
  description = "List of namespaces that were created"
}

output "all_namespaces" {
  value = local.namespaces
  description = "List of all namespaces"
}
resource "kubernetes_deployment" "uptime_kuma" {
  metadata {
    name      = "uptime-kuma"
    namespace = "monitoring"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "uptime-kuma"
      }
    }

    template {
      metadata {
        labels = {
          app = "uptime-kuma"
        }
      }

      spec {
        container {
          image = "louislam/uptime-kuma:1"
          name  = "uptime-kuma"

          port {
            container_port = 3001
          }

          volume_mount {
            name       = "data"
            mount_path = "/app/data"
          }
        }

        volume {
          name = "data"
          empty_dir {}
        }
      }
    }
  }
}

resource "kubernetes_service" "uptime_kuma" {
  metadata {
    name      = "uptime-kuma"
    namespace = "monitoring"
  }

  spec {
    selector = {
      app = "uptime-kuma"
    }

    port {
      port        = 80
      target_port = 3001
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_v1" "uptime_kuma" {
  metadata {
    name      = "uptime-kuma-ingress"
    namespace = "monitoring" 
    annotations = {
      "kubernetes.io/ingress.provider"                   = "nginx"
      "nginx.ingress.kubernetes.io/proxy-body-size"      = "512m"
      "nginx.ingress.kubernetes.io/proxy-connect-timeout" = "15"
      "nginx.ingress.kubernetes.io/proxy-read-timeout"    = "600"
      "nginx.ingress.kubernetes.io/service-upstream"      = "true"
      # "cert-manager.io/issuer" = "your-issuer-name"
    }
  }

  spec {
    ingress_class_name = "gitlab-nginx"  

    rule {
      host = "kuma.${var.hostname}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "uptime-kuma"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
    # tls {
    #   hosts       = ["kuma.tubbel-top"]
    #   secret_name = "uptime-kuma-tls"
    # }
  }
}


resource "kubernetes_network_policy" "allow_all" {
  for_each = toset(local.namespaces)

  metadata {
    name      = "allow-all"
    namespace = each.key
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress", "Egress"]
    
    ingress {
      from {
        namespace_selector {}
      }
    }

    egress {
      to {
        namespace_selector {}
      }
    }
  }
}

output "kubernetes_namespaces" {
  value = [for ns in local.namespaces : ns]
}

output "uptime_kuma_url" {
  value = "http://${kubernetes_ingress_v1.uptime_kuma.spec[0].rule[0].host}"
}
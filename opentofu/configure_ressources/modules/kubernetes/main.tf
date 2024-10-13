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

variable "gitlab_deploy_token" {
  description = "GitLab Deploy Token"
  type        = string
  sensitive   = true
}

variable "gitlab_agent_token" {
  description = "GitLab Agent Token"
  type        = string
  sensitive   = true
}


resource "kubernetes_namespace" "environments" {
  for_each = toset(["dev", "stg", "prod", "monitoring", "gitlab-agent"])

  metadata {
    name = each.key
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "kubernetes_deployment" "uptime_kuma" {
  metadata {
    name      = "uptime-kuma"
    namespace = kubernetes_namespace.environments["monitoring"].metadata[0].name
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
    namespace = kubernetes_namespace.environments["monitoring"].metadata[0].name
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
      # Wenn Sie ein TLS-Zertifikat mit cert-manager verwenden möchten:
      # "cert-manager.io/issuer" = "your-issuer-name"
    }
  }

  spec {
    ingress_class_name = "gitlab-nginx"  # Verwenden Sie die gleiche Ingress-Klasse wie bei GitLab

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

    # Wenn Sie TLS verwenden möchten, fügen Sie den folgenden Block hinzu:
    # tls {
    #   hosts       = ["kuma.tubbel-top"]
    #   secret_name = "uptime-kuma-tls"
    # }
  }
}


resource "kubernetes_network_policy" "monitoring_egress" {
  metadata {
    name      = "monitoring-egress"
    namespace = "monitoring"
  }

  spec {
    pod_selector {}
    policy_types = ["Egress"]
    
    egress {
      to {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "gitlab"
          }
        }
      }
      to {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "gitlab-runner"
          }
        }
      }
      to {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "dev"
          }
        }
      }
      to {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "stg"
          }
        }
      }
      to {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "prod"
          }
        }
      }
    }
  }
}

locals {
  namespaces = ["gitlab", "gitlab-runner", "dev", "stg", "prod"]
}

resource "kubernetes_network_policy" "allow_monitoring_ingress" {
  count = length(local.namespaces)

  metadata {
    name      = "allow-monitoring-ingress"
    namespace = local.namespaces[count.index]
  }

  spec {
    pod_selector {}
    policy_types = ["Ingress"]
    
    ingress {
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "monitoring"
          }
        }
      }
    }
  }
}


output "kubernetes_namespaces" {
  value = [for ns in kubernetes_namespace.environments : ns.metadata[0].name]
}

output "uptime_kuma_url" {
  value = "http://${kubernetes_ingress_v1.uptime_kuma.spec[0].rule[0].host}"
}
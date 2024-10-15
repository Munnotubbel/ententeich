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
    gitlab = {
      source  = "opentofu/gitlab"
      version = "~> 17.4.0"
    }
  }
}

locals {
  namespaces = ["gitlab", "gitlab-runner", "dev", "stg", "prod", "monitoring"]
  creating   = ["dev", "stg", "prod", "monitoring"]
}


resource "kubernetes_namespace" "environments" {
  for_each = toset(local.creating)

  metadata {
    name = each.key
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "kubernetes_deployment" "uptime_kuma" {
  depends_on = [kubernetes_namespace.environments]
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
  depends_on = [kubernetes_namespace.environments]
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
  depends_on = [kubernetes_namespace.environments]
  metadata {
    name      = "uptime-kuma-ingress"
    namespace = "monitoring" 
    annotations = {
      "kubernetes.io/ingress.provider"                   = "nginx"
      "nginx.ingress.kubernetes.io/proxy-body-size"      = "512m"
      "nginx.ingress.kubernetes.io/proxy-connect-timeout" = "15"
      "nginx.ingress.kubernetes.io/proxy-read-timeout"    = "600"
      "nginx.ingress.kubernetes.io/service-upstream"      = "true"
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
  }
}


resource "kubernetes_network_policy" "allow_all" {
  depends_on = [kubernetes_namespace.environments]
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


locals {
  source_namespace = "gitlab"
  target_namespaces = ["dev", "stg", "prod"]
}

data "kubernetes_secret" "gitlab_registry_secret" {
  metadata {
    name      = "gitlab-registry-secret"
    namespace = local.source_namespace
  }
}

resource "kubernetes_secret" "copied_registry_secrets" {
  depends_on = [kubernetes_namespace.environments]
  for_each = toset(local.target_namespaces)

  metadata {
    name      = data.kubernetes_secret.gitlab_registry_secret.metadata[0].name
    namespace = each.key
  }

  data = data.kubernetes_secret.gitlab_registry_secret.data

  type = data.kubernetes_secret.gitlab_registry_secret.type
}

data "gitlab_user" "registry_user" {
  username = "root" 
}


resource "gitlab_personal_access_token" "registry_token" {
  user_id = local.registry_user
  name        = "Container Registry Token"
  expires_at = formatdate("YYYY-MM-DD", timeadd(timestamp(), "8760h"))
  scopes      = ["read_registry"]
}

locals {
  registry_user = data.gitlab_user.registry_user.id
  token_value   = coalesce(gitlab_personal_access_token.registry_token.token, "")
}


resource "kubernetes_secret" "gitlab_imagepullsecret" {
  for_each = toset(local.target_namespaces)
  depends_on = [kubernetes_namespace.environments, gitlab_personal_access_token.registry_token]

  metadata {
    name      = "gitlab-imagepullsecret"
    namespace = each.key
  }

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "registry.${var.hostname}" = {
          username = "root",
          password = gitlab_personal_access_token.registry_token.token,
          auth     = base64encode(join(":", ["root", gitlab_personal_access_token.registry_token.token]))
        }
      }
    })
  }

  type = "kubernetes.io/dockerconfigjson"
}


output "kubernetes_namespaces" {
  value = [for ns in local.namespaces : ns]
}

output "uptime_kuma_url" {
  value = "http://${kubernetes_ingress_v1.uptime_kuma.spec[0].rule[0].host}"
}
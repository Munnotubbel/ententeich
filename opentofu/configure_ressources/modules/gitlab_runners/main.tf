  terraform {
    required_providers {
      kubernetes = {
        source  = "opentofu/kubernetes"
        version = "~> 2.0"
      }
      helm = {
        source  = "opentofu/helm"
        version = "~> 2.0"
      }
      gitlab = {
        source  = "opentofu/gitlab"
        version = "~> 17.4.0"
      }
    }
  }

  resource "kubernetes_namespace" "gitlab_runner" {
    metadata {
      name = var.namespace
      labels = {
        name = "gitlab-runner"
      }
    }
  }

resource "kubernetes_cluster_role_binding" "gitlab_runner_admin" {
  depends_on = [kubernetes_namespace.gitlab_runner]
  metadata {
    name = "gitlab-runner-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "gitlab-runner"
    namespace = "gitlab-runner"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
}

resource "kubernetes_service_account" "gitlab_runner" {
  depends_on = [kubernetes_namespace.gitlab_runner]
  metadata {
    name      = "gitlab-runner"
    namespace = "gitlab-runner"
  }
}


data "kubernetes_secret" "gitlab_runner_secret" {
  metadata {
    name      = "gitlab-gitlab-runner-secret"
    namespace = "gitlab"
  }
}

resource "kubernetes_secret" "gitlab_runner_secret_copy" {
  metadata {
    name      = "gitlab-gitlab-runner-secret"
    namespace = "gitlab-runner"
    labels    = data.kubernetes_secret.gitlab_runner_secret.metadata[0].labels
  }

  data = data.kubernetes_secret.gitlab_runner_secret.data
  type = data.kubernetes_secret.gitlab_runner_secret.type
}

  resource "helm_release" "gitlab_runner" {
    depends_on = [kubernetes_namespace.gitlab_runner]
    name       = "gitlab-runner"
    repository = "https://charts.gitlab.io"
    chart      = "gitlab-runner"
    namespace  = "gitlab-runner"
    version    = var.chart_version
    wait       = false

    set {
      name  = "gitlabUrl"
      value = "http://gitlab-webservice-default.gitlab.svc.cluster.local:8080"
    
    }

    set {
        name  = "runners.secret"
        value = "gitlab-gitlab-runner-secret"
      }

    set {
      name  = "rbac.create"
      value = false
    }

    set {
      name = "rbac.serviceAccountName"
      value = "gitlab-runner"
    }

    set {
      name  = "serviceAccount.create"
      value = false
    }
    
    set {
      name  = "serviceAccount.name"
      value = "gitlab-runner"
    }

    set {
      name  = "runners.privileged"
      value = true
    }

    set {
      name  = "runners.namespace"
      value = kubernetes_namespace.gitlab_runner.metadata[0].name
    }

    
    set {
      name  = "concurrent"
      value = var.concurrent_runners
    }

    set {
      name  = "checkInterval"
      value = 15
    }

    set {
      name  = "runners.image"
      value = "alpine:latest"
    }

    set {
      name  = "runners.tags"
      value = "shared"
    }

    set {
      name  = "runners.runUntagged"
      value = true
    }

    set {
      name  = "runners.executor"
      value = "kubernetes"
    }

    set {
      name ="shutdown_timeout"
      value = 10
    }
    
    set  {
      name = "connectionMaxAge"
      value = "600m"
    }


set {
  name  = "runners.config"
  value = <<-EOT
    [[runners]]
      log_level = "debug"
      environment = ["GIT_SSL_NO_VERIFY=1"]
      [runners.kubernetes]
      namespace = "gitlab-runner"
      service_account = "gitlab-runner"
      [runners.kubernetes.volumes]
        [[runners.kubernetes.volumes.secret]]
          name = "gitlab-gitlab-runner-secret"
          mount_path = "/secrets"
      [runners.custom_build_dir]
      [runners.cache]
        [runners.cache.s3]
        [runners.cache.gcs]
      [runners.custom]
        artifact_upload_timeout = "5m"
        run_exec = ""
        pre_clone_script = ""
        pre_build_script = ""
        post_build_script = ""
        cleanup_exec = ""

  EOT
}

    set {
      name = "metrics.enabled"
      value = true
    }
    
     set {
      name = "metrics.port"
      value = 9252
    }

    set {
      name = "service.enabled"
      value = true
    }


    dynamic "set" {
      for_each = var.additional_helm_values
      content {
        name  = set.key
        value = set.value
      }
    }
  }


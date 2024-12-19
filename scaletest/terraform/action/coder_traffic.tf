locals {
  wait_baseline_duration        = "5m"
  workspace_traffic_job_timeout = "15m"
  workspace_traffic_duration    = "10m"
  bytes_per_tick                = 1024
  tick_interval                 = "100ms"

  traffic_types = {
    ssh = {
      wait_duration_minutes = "0"
      flags = [
        "--ssh",
      ]
    }
    webterminal = {
      wait_duration_minutes = "5"
      flags = []
    }
    app = {
      wait_duration_minutes = "10"
      flags = [
        "--app=wsec",
      ]
    }
  }
}

resource "time_sleep" "wait_baseline" {
  depends_on = [
    kubernetes_job.create_workspaces_primary,
    kubernetes_job.create_workspaces_europe,
    kubernetes_job.create_workspaces_asia,
  ]
  # depends_on = [
  #   kubernetes_job.push_template_primary,
  #   kubernetes_job.push_template_europe,
  #   kubernetes_job.push_template_asia,
  # ]

  create_duration = local.wait_baseline_duration
}

resource "kubernetes_job" "workspace_traffic_primary" {
  provider = kubernetes.primary

  for_each = local.traffic_types
  metadata {
    name      = "${var.name}-workspace-traffic-${each.key}"
    namespace = kubernetes_namespace.coder_primary.metadata.0.name
    labels = {
      "app.kubernetes.io/name" = "${var.name}-workspace-traffic-${each.key}"
    }
  }
  spec {
    completions = 1
    backoff_limit = 0
    template {
      metadata {}
      spec {
        affinity {
          node_affinity {
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "cloud.google.com/gke-nodepool"
                  operator = "In"
                  values   = ["${google_container_node_pool.node_pool["primary_misc"].name}"]
                }
              }
            }
          }
        }
        container {
          name  = "cli"
          image = "${var.coder_image_repo}:${var.coder_image_tag}"
          command = concat([
            "/opt/coder",
            "--verbose",
            "--url=${local.deployments.primary.url}",
            "--token=${trimspace(data.local_file.api_key.content)}",
            "exp",
            "scaletest",
            "workspace-traffic",
            "--template=kubernetes-primary",
            "--concurrency=0",
            "--bytes-per-tick=${local.bytes_per_tick}",
            "--tick-interval=${local.tick_interval}",
            "--scaletest-prometheus-wait=30s",
            "--job-timeout=${local.workspace_traffic_duration}",
          ], local.traffic_types[each.key].flags)
        }
        restart_policy = "Never"
      }
    }
  }
  wait_for_completion = true

  timeouts {
    create = local.workspace_traffic_job_timeout
  }

  depends_on = [time_sleep.wait_baseline]
}

resource "kubernetes_job" "workspace_traffic_europe" {
  provider = kubernetes.europe

for_each = local.traffic_types
  metadata {
    name      = "${var.name}-workspace-traffic-${each.key}"
    namespace = kubernetes_namespace.coder_europe.metadata.0.name
    labels = {
      "app.kubernetes.io/name" = "${var.name}-workspace-traffic-${each.key}"
    }
  }
  spec {
    completions = 1
    backoff_limit = 0
    template {
      metadata {}
      spec {
        affinity {
          node_affinity {
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "cloud.google.com/gke-nodepool"
                  operator = "In"
                  values   = ["${google_container_node_pool.node_pool["europe_misc"].name}"]
                }
              }
            }
          }
        }
        container {
          name  = "cli"
          image = "${var.coder_image_repo}:${var.coder_image_tag}"
          command = concat([
            "/opt/coder",
            "--verbose",
            "--url=${local.deployments.primary.url}",
            "--token=${trimspace(data.local_file.api_key.content)}",
            "exp",
            "scaletest",
            "workspace-traffic",
            "--template=kubernetes-europe",
            "--concurrency=0",
            "--bytes-per-tick=${local.bytes_per_tick}",
            "--tick-interval=${local.tick_interval}",
            "--scaletest-prometheus-wait=30s",
            "--job-timeout=${local.workspace_traffic_duration}",
            "--workspace-proxy-url=${local.deployments.europe.url}",
          ], local.traffic_types[each.key].flags)
        }
        restart_policy = "Never"
      }
    }
  }
  wait_for_completion = true

  timeouts {
    create = local.workspace_traffic_job_timeout
  }

  depends_on = [time_sleep.wait_baseline]
}

resource "kubernetes_job" "workspace_traffic_asia" {
  provider = kubernetes.asia

  for_each = local.traffic_types
  metadata {
    name      = "${var.name}-workspace-traffic-${each.key}"
    namespace = kubernetes_namespace.coder_asia.metadata.0.name
    labels = {
      "app.kubernetes.io/name" = "${var.name}-workspace-traffic-${each.key}"
    }
  }
  spec {
    completions = 1
    backoff_limit = 0
    template {
      metadata {}
      spec {
        affinity {
          node_affinity {
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "cloud.google.com/gke-nodepool"
                  operator = "In"
                  values   = ["${google_container_node_pool.node_pool["asia_misc"].name}"]
                }
              }
            }
          }
        }
        container {
          name  = "cli"
          image = "${var.coder_image_repo}:${var.coder_image_tag}"
          command = concat([
            "/opt/coder",
            "--verbose",
            "--url=${local.deployments.primary.url}",
            "--token=${trimspace(data.local_file.api_key.content)}",
            "exp",
            "scaletest",
            "workspace-traffic",
            "--template=kubernetes-asia",
            "--concurrency=0",
            "--bytes-per-tick=${local.bytes_per_tick}",
            "--tick-interval=${local.tick_interval}",
            "--scaletest-prometheus-wait=30s",
            "--job-timeout=${local.workspace_traffic_duration}",
            "--workspace-proxy-url=${local.deployments.asia.url}",
          ], local.traffic_types[each.key].flags)
        }
        restart_policy = "Never"
      }
    }
  }
  wait_for_completion = true

  timeouts {
    create = local.workspace_traffic_job_timeout
  }

  depends_on = [time_sleep.wait_baseline]
}

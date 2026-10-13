# ---------------------------------------------------------------- Teams & access
resource "github_team" "this" {
  for_each    = var.teams
  name        = each.key
  description = each.value.description
  privacy     = "closed"
}

resource "github_team_repository" "this" {
  for_each   = var.teams
  team_id    = github_team.this[each.key].id
  repository = var.repo
  permission = each.value.permission
}

locals {
  memberships = merge([
    for team, cfg in var.teams : { for user in cfg.members : "${team}/${user}" => { team = team, user = user } }
  ]...)
}

resource "github_team_membership" "this" {
  for_each = local.memberships
  team_id  = github_team.this[each.value.team].id
  username = each.value.user
  role     = "member"
}

# ---------------------------------------------------------------- Protect the trunk
resource "github_repository_ruleset" "protect_trunk" {
  name        = "protect-trunk"
  repository  = var.repo
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  # Break-glass: org admins may bypass checks when merging a PR (never by direct push). Audited.
  bypass_actors {
    actor_id    = 1
    actor_type  = "OrganizationAdmin"
    bypass_mode = "pull_request"
  }

  rules {
    deletion                = true
    non_fast_forward        = true
    required_linear_history = true

    pull_request {
      required_approving_review_count   = 1
      require_code_owner_review         = true
      dismiss_stale_reviews_on_push     = true
      require_last_push_approval        = true
      required_review_thread_resolution = true
    }

    required_status_checks {
      strict_required_status_checks_policy = true
      dynamic "required_check" {
        for_each = var.required_checks
        content {
          context = required_check.value
        }
      }
    }
  }
}

# ---------------------------------------------------------------- Environments
resource "github_repository_environment" "dev" {
  repository  = var.repo
  environment = "dev"
}

resource "github_repository_environment" "staging" {
  repository  = var.repo
  environment = "staging"
  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment" "prod" {
  repository  = var.repo
  environment = "prod"
  # GitHub only accepts reviewers that already have access to the repo, so give teams access first
  depends_on = [github_team_repository.this]
  reviewers {
    teams = [github_team.this["leads"].id, github_team.this["platform"].id]
  }
  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment_deployment_policy" "main_only" {
  for_each       = { staging = github_repository_environment.staging, prod = github_repository_environment.prod }
  repository     = var.repo
  environment    = each.value.environment
  branch_pattern = "main"
}

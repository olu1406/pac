# Azure Management Group and Subscription Baseline Module
# Implements secure management group hierarchy with RBAC baseline, Azure Policy, and Defender for Cloud

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
}

# Data source for current client configuration
data "azurerm_client_config" "current" {}

# Root management group (if creating new hierarchy)
resource "azurerm_management_group" "root" {
  count = var.create_management_group_hierarchy ? 1 : 0

  display_name = var.organization_name
  name         = "${var.organization_name}-root"

  subscription_ids = var.root_subscription_ids
}

# Security management group
resource "azurerm_management_group" "security" {
  count = var.create_management_group_hierarchy ? 1 : 0

  display_name               = "Security"
  name                      = "${var.organization_name}-security"
  parent_management_group_id = azurerm_management_group.root[0].id

  subscription_ids = var.security_subscription_ids
}

# Workloads management group
resource "azurerm_management_group" "workloads" {
  count = var.create_management_group_hierarchy ? 1 : 0

  display_name               = "Workloads"
  name                      = "${var.organization_name}-workloads"
  parent_management_group_id = azurerm_management_group.root[0].id

  subscription_ids = var.workload_subscription_ids
}

# Platform management group
resource "azurerm_management_group" "platform" {
  count = var.create_management_group_hierarchy ? 1 : 0

  display_name               = "Platform"
  name                      = "${var.organization_name}-platform"
  parent_management_group_id = azurerm_management_group.root[0].id

  subscription_ids = var.platform_subscription_ids
}

# Sandbox management group
resource "azurerm_management_group" "sandbox" {
  count = var.create_management_group_hierarchy ? 1 : 0

  display_name               = "Sandbox"
  name                      = "${var.organization_name}-sandbox"
  parent_management_group_id = azurerm_management_group.root[0].id

  subscription_ids = var.sandbox_subscription_ids
}

# Azure Policy Assignments for Security Baseline
# Security baseline policy initiative
resource "azurerm_policy_set_definition" "security_baseline" {
  count = var.create_security_policies ? 1 : 0

  name         = "${var.organization_name}-security-baseline"
  policy_type  = "Custom"
  display_name = "Security Baseline Policy Initiative"
  description  = "Baseline security controls for all subscriptions"

  management_group_id = var.create_management_group_hierarchy ? azurerm_management_group.root[0].id : var.existing_root_management_group_id

  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/404c3081-a854-4457-ae30-26a93ef643f9"
    parameter_values = jsonencode({
      effect = {
        value = "Audit"
      }
    })
  }

  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/1e30110a-5ceb-460c-a204-c1c3969c6d62"
    parameter_values = jsonencode({
      effect = {
        value = "Audit"
      }
    })
  }

  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/0961003e-5a0a-4549-abde-af6a37f2724d"
    parameter_values = jsonencode({
      effect = {
        value = "Audit"
      }
    })
  }

  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/e1e5fd5d-3e4c-4ce1-8661-7d1873ae6b15"
    parameter_values = jsonencode({
      effect = {
        value = "Audit"
      }
    })
  }
}

# Assign security baseline to root management group
resource "azurerm_management_group_policy_assignment" "security_baseline" {
  count = var.create_security_policies ? 1 : 0

  name                 = "security-baseline"
  policy_definition_id = azurerm_policy_set_definition.security_baseline[0].id
  management_group_id  = var.create_management_group_hierarchy ? azurerm_management_group.root[0].id : var.existing_root_management_group_id
  display_name         = "Security Baseline Policy Assignment"
  description          = "Assigns security baseline policies to all subscriptions"

  identity {
    type = "SystemAssigned"
  }

  location = var.location
}

# Deny policy for high-risk actions
resource "azurerm_policy_definition" "deny_high_risk_actions" {
  count = var.create_security_policies ? 1 : 0

  name         = "${var.organization_name}-deny-high-risk-actions"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Deny High Risk Actions"
  description  = "Denies high-risk actions that could compromise security"

  management_group_id = var.create_management_group_hierarchy ? azurerm_management_group.root[0].id : var.existing_root_management_group_id

  policy_rule = jsonencode({
    if = {
      anyOf = [
        {
          allOf = [
            {
              field  = "type"
              equals = "Microsoft.Security/securityContacts"
            },
            {
              field   = "Microsoft.Security/securityContacts/email"
              exists  = "false"
            }
          ]
        },
        {
          allOf = [
            {
              field = "type"
              equals = "Microsoft.Network/networkSecurityGroups/securityRules"
            },
            {
              anyOf = [
                {
                  allOf = [
                    {
                      field  = "Microsoft.Network/networkSecurityGroups/securityRules/access"
                      equals = "Allow"
                    },
                    {
                      field  = "Microsoft.Network/networkSecurityGroups/securityRules/direction"
                      equals = "Inbound"
                    },
                    {
                      anyOf = [
                        {
                          field  = "Microsoft.Network/networkSecurityGroups/securityRules/sourceAddressPrefix"
                          equals = "*"
                        },
                        {
                          field  = "Microsoft.Network/networkSecurityGroups/securityRules/sourceAddressPrefix"
                          equals = "Internet"
                        }
                      ]
                    }
                  ]
                }
              ]
            }
          ]
        }
      ]
    }
    then = {
      effect = "deny"
    }
  })

  parameters = jsonencode({
    effect = {
      type = "String"
      metadata = {
        displayName = "Effect"
        description = "The effect determines what happens when the policy rule is evaluated to match"
      }
      allowedValues = [
        "Audit",
        "Deny",
        "Disabled"
      ]
      defaultValue = "Deny"
    }
  })
}

# Assign deny policy to root management group
resource "azurerm_management_group_policy_assignment" "deny_high_risk_actions" {
  count = var.create_security_policies ? 1 : 0

  name                 = "deny-high-risk-actions"
  policy_definition_id = azurerm_policy_definition.deny_high_risk_actions[0].id
  management_group_id  = var.create_management_group_hierarchy ? azurerm_management_group.root[0].id : var.existing_root_management_group_id
  display_name         = "Deny High Risk Actions"
  description          = "Denies high-risk actions across all subscriptions"

  parameters = jsonencode({
    effect = {
      value = "Deny"
    }
  })
}
# RBAC Role Definitions
# Security Reader role for cross-subscription access
resource "azurerm_role_definition" "security_reader" {
  count = var.create_custom_roles ? 1 : 0

  role_definition_id = uuidv5("dns", "${var.organization_name}-security-reader")
  name               = "${var.organization_name}-security-reader"
  scope              = var.create_management_group_hierarchy ? azurerm_management_group.root[0].id : var.existing_root_management_group_id
  description        = "Custom security reader role with enhanced permissions"

  permissions {
    actions = [
      "Microsoft.Security/*/read",
      "Microsoft.Authorization/*/read",
      "Microsoft.Resources/*/read",
      "Microsoft.Network/*/read",
      "Microsoft.Compute/*/read",
      "Microsoft.Storage/*/read",
      "Microsoft.KeyVault/*/read",
      "Microsoft.Sql/*/read",
      "Microsoft.Web/*/read"
    ]
    not_actions = []
  }

  assignable_scopes = [
    var.create_management_group_hierarchy ? azurerm_management_group.root[0].id : var.existing_root_management_group_id
  ]
}

# Security Operator role for incident response
resource "azurerm_role_definition" "security_operator" {
  count = var.create_custom_roles ? 1 : 0

  role_definition_id = uuidv5("dns", "${var.organization_name}-security-operator")
  name               = "${var.organization_name}-security-operator"
  scope              = var.create_management_group_hierarchy ? azurerm_management_group.root[0].id : var.existing_root_management_group_id
  description        = "Custom security operator role for incident response"

  permissions {
    actions = [
      "Microsoft.Security/*/read",
      "Microsoft.Security/alerts/dismiss/action",
      "Microsoft.Security/securityStatuses/read",
      "Microsoft.Authorization/*/read",
      "Microsoft.Resources/*/read",
      "Microsoft.Network/networkSecurityGroups/securityRules/write",
      "Microsoft.Network/networkSecurityGroups/write",
      "Microsoft.Compute/virtualMachines/restart/action",
      "Microsoft.Compute/virtualMachines/deallocate/action"
    ]
    not_actions = []
  }

  assignable_scopes = [
    var.create_management_group_hierarchy ? azurerm_management_group.root[0].id : var.existing_root_management_group_id
  ]
}

# Break glass emergency access role
resource "azurerm_role_definition" "break_glass" {
  count = var.enable_break_glass_role ? 1 : 0

  role_definition_id = uuidv5("dns", "${var.organization_name}-break-glass")
  name               = "${var.organization_name}-break-glass"
  scope              = var.create_management_group_hierarchy ? azurerm_management_group.root[0].id : var.existing_root_management_group_id
  description        = "Emergency break glass role with elevated permissions"

  permissions {
    actions = [
      "*"
    ]
    not_actions = [
      "Microsoft.Authorization/*/Delete",
      "Microsoft.Blueprint/*/Delete",
      "Microsoft.Compute/galleries/share/action"
    ]
  }

  assignable_scopes = [
    var.create_management_group_hierarchy ? azurerm_management_group.root[0].id : var.existing_root_management_group_id
  ]
}

# RBAC assignments for security groups
resource "azurerm_role_assignment" "security_readers" {
  count = length(var.security_reader_groups)

  scope              = var.create_management_group_hierarchy ? azurerm_management_group.security[0].id : var.existing_security_management_group_id
  role_definition_id = var.create_custom_roles ? azurerm_role_definition.security_reader[0].role_definition_resource_id : null
  role_definition_name = var.create_custom_roles ? null : "Security Reader"
  principal_id       = var.security_reader_groups[count.index]
}

resource "azurerm_role_assignment" "security_operators" {
  count = length(var.security_operator_groups)

  scope              = var.create_management_group_hierarchy ? azurerm_management_group.security[0].id : var.existing_security_management_group_id
  role_definition_id = var.create_custom_roles ? azurerm_role_definition.security_operator[0].role_definition_resource_id : null
  role_definition_name = var.create_custom_roles ? null : "Security Admin"
  principal_id       = var.security_operator_groups[count.index]
}

resource "azurerm_role_assignment" "break_glass_users" {
  count = var.enable_break_glass_role ? length(var.break_glass_user_ids) : 0

  scope              = var.create_management_group_hierarchy ? azurerm_management_group.root[0].id : var.existing_root_management_group_id
  role_definition_id = azurerm_role_definition.break_glass[0].role_definition_resource_id
  principal_id       = var.break_glass_user_ids[count.index]
}
# Microsoft Defender for Cloud Configuration
# Enable Defender for Cloud on subscriptions
resource "azurerm_security_center_subscription_pricing" "defender_servers" {
  count = var.enable_defender_for_cloud ? length(var.defender_subscription_ids) : 0

  tier          = "Standard"
  resource_type = "VirtualMachines"
  subplan       = "P2"
}

resource "azurerm_security_center_subscription_pricing" "defender_storage" {
  count = var.enable_defender_for_cloud ? length(var.defender_subscription_ids) : 0

  tier          = "Standard"
  resource_type = "StorageAccounts"
  subplan       = "DefenderForStorageV2"
}

resource "azurerm_security_center_subscription_pricing" "defender_sql" {
  count = var.enable_defender_for_cloud ? length(var.defender_subscription_ids) : 0

  tier          = "Standard"
  resource_type = "SqlServers"
}

resource "azurerm_security_center_subscription_pricing" "defender_containers" {
  count = var.enable_defender_for_cloud ? length(var.defender_subscription_ids) : 0

  tier          = "Standard"
  resource_type = "Containers"
}

resource "azurerm_security_center_subscription_pricing" "defender_keyvault" {
  count = var.enable_defender_for_cloud ? length(var.defender_subscription_ids) : 0

  tier          = "Standard"
  resource_type = "KeyVaults"
}

# Security Center Contact
resource "azurerm_security_center_contact" "main" {
  count = var.enable_defender_for_cloud && var.security_contact_email != "" ? 1 : 0

  name                = "default1"
  email               = var.security_contact_email
  phone               = var.security_contact_phone
  alert_notifications = true
  alerts_to_admins    = true
}

# Security Center Auto Provisioning
resource "azurerm_security_center_auto_provisioning" "main" {
  count = var.enable_defender_for_cloud ? 1 : 0

  auto_provision = "On"
}

# Log Analytics Workspace for Security Center
resource "azurerm_log_analytics_workspace" "security" {
  count = var.enable_defender_for_cloud && var.create_log_analytics_workspace ? 1 : 0

  name                = "${var.organization_name}-security-logs"
  location            = var.location
  resource_group_name = var.security_resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days

  tags = var.tags
}

# Security Center Workspace
resource "azurerm_security_center_workspace" "main" {
  count = var.enable_defender_for_cloud && var.create_log_analytics_workspace ? length(var.defender_subscription_ids) : 0

  scope        = "/subscriptions/${var.defender_subscription_ids[count.index]}"
  workspace_id = azurerm_log_analytics_workspace.security[0].id
}
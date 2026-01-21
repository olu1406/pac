# Outputs for Azure Management Group and Subscription Baseline Module

# Management Group outputs
output "root_management_group_id" {
  description = "The root management group ID"
  value       = var.create_management_group_hierarchy ? azurerm_management_group.root[0].id : var.existing_root_management_group_id
}

output "security_management_group_id" {
  description = "The security management group ID"
  value       = var.create_management_group_hierarchy ? azurerm_management_group.security[0].id : var.existing_security_management_group_id
}

output "workloads_management_group_id" {
  description = "The workloads management group ID"
  value       = var.create_management_group_hierarchy ? azurerm_management_group.workloads[0].id : null
}

output "platform_management_group_id" {
  description = "The platform management group ID"
  value       = var.create_management_group_hierarchy ? azurerm_management_group.platform[0].id : null
}

output "sandbox_management_group_id" {
  description = "The sandbox management group ID"
  value       = var.create_management_group_hierarchy ? azurerm_management_group.sandbox[0].id : null
}

# Azure Policy outputs
output "security_baseline_policy_set_id" {
  description = "ID of the security baseline policy set definition"
  value       = var.create_security_policies ? azurerm_policy_set_definition.security_baseline[0].id : null
}

output "security_baseline_assignment_id" {
  description = "ID of the security baseline policy assignment"
  value       = var.create_security_policies ? azurerm_management_group_policy_assignment.security_baseline[0].id : null
}

output "deny_high_risk_actions_policy_id" {
  description = "ID of the deny high risk actions policy definition"
  value       = var.create_security_policies ? azurerm_policy_definition.deny_high_risk_actions[0].id : null
}

output "deny_high_risk_actions_assignment_id" {
  description = "ID of the deny high risk actions policy assignment"
  value       = var.create_security_policies ? azurerm_management_group_policy_assignment.deny_high_risk_actions[0].id : null
}

# RBAC outputs
output "security_reader_role_id" {
  description = "ID of the custom security reader role"
  value       = var.create_custom_roles ? azurerm_role_definition.security_reader[0].role_definition_resource_id : null
}

output "security_operator_role_id" {
  description = "ID of the custom security operator role"
  value       = var.create_custom_roles ? azurerm_role_definition.security_operator[0].role_definition_resource_id : null
}

output "break_glass_role_id" {
  description = "ID of the break glass emergency access role"
  value       = var.enable_break_glass_role ? azurerm_role_definition.break_glass[0].role_definition_resource_id : null
}

# Microsoft Defender for Cloud outputs
output "defender_for_cloud_enabled" {
  description = "Whether Microsoft Defender for Cloud is enabled"
  value       = var.enable_defender_for_cloud
}

output "security_contact_email" {
  description = "Security contact email address"
  value       = var.enable_defender_for_cloud && var.security_contact_email != "" ? var.security_contact_email : null
  sensitive   = true
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace for security logging"
  value       = var.enable_defender_for_cloud && var.create_log_analytics_workspace ? azurerm_log_analytics_workspace.security[0].id : null
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace for security logging"
  value       = var.enable_defender_for_cloud && var.create_log_analytics_workspace ? azurerm_log_analytics_workspace.security[0].name : null
}

output "log_analytics_workspace_resource_group" {
  description = "Resource group name of the Log Analytics workspace"
  value       = var.enable_defender_for_cloud && var.create_log_analytics_workspace ? azurerm_log_analytics_workspace.security[0].resource_group_name : null
}
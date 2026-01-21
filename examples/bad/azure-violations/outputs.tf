output "resource_group_name" {
  description = "Name of the insecure resource group"
  value       = azurerm_resource_group.main.name
}

output "insecure_nsg_id" {
  description = "ID of the insecure network security group"
  value       = azurerm_network_security_group.insecure.id
}

output "empty_nsg_id" {
  description = "ID of the empty network security group"
  value       = azurerm_network_security_group.empty.id
}

output "insecure_storage_account_name" {
  description = "Name of the insecure storage account"
  value       = azurerm_storage_account.insecure.name
}

output "public_container_name" {
  description = "Name of the public storage container"
  value       = azurerm_storage_container.public.name
}

output "service_principal_object_id" {
  description = "Object ID of the insecure service principal"
  value       = azuread_service_principal.insecure.object_id
}

output "wildcard_role_definition_id" {
  description = "ID of the wildcard role definition"
  value       = azurerm_role_definition.wildcard_role.role_definition_resource_id
}

output "violations_summary" {
  description = "Summary of intentional security violations"
  value = {
    critical_violations = [
      "AZ-IAM-001: Custom RBAC role allows wildcard actions (*)",
      "AZ-NET-001: SSH access from any source (*)",
      "AZ-NET-002: RDP access from any source (*)",
      "AZ-DATA-003: Storage container allows public access"
    ]
    high_violations = [
      "AZ-IAM-002: Owner role assigned at subscription scope (if enabled)",
      "AZ-NET-003: Unrestricted inbound access to all ports",
      "AZ-NET-005: High-risk port (MySQL) accessible from anywhere",
      "AZ-DATA-001: Storage account not enforcing HTTPS-only",
      "AZ-DATA-005: Storage account TLS version below 1.2"
    ]
    medium_violations = [
      "AZ-IAM-003: Service principal without credential expiration",
      "AZ-IAM-005: Privileged role assignment (Security Administrator)",
      "AZ-NET-004: NSG with no custom rules",
      "AZ-DATA-002: Storage account allows public blob access",
      "AZ-DATA-006: Storage account without blob soft delete"
    ]
    total_expected_violations = 12
    note = "Subscription-level violations require subscription_id variable to be set"
  }
}
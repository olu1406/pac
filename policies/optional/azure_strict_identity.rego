# Optional Azure Identity Controls - Strict Security Policies
# These controls enforce stricter identity security policies that may impact operational flexibility
# Enable these controls only after careful consideration of operational impact

# CONTROL: OPT-AZ-IAM-001
# TITLE: Require Conditional Access for all administrative roles
# SEVERITY: HIGH
# FRAMEWORKS: NIST-800-53:AC-2, CIS-Azure:1.1, ISO-27001:A.9.2.1
# STATUS: DISABLED (uncomment to enable)
# OPTIONAL: true
# PREREQUISITES: Conditional Access policies configured in Azure AD
# IMPACT: May block administrative access if Conditional Access is not properly configured

# package terraform.security.azure.optional.strict_identity
# 
# import rego.v1
# 
# deny contains msg if {
#     resource := input.planned_values.root_module.resources[_]
#     resource.type == "azurerm_role_assignment"
#     
#     # Check for administrative roles without conditional access requirement
#     is_administrative_role(resource.values.role_definition_name)
#     not has_conditional_access_policy()
#     
#     msg := {
#         "control_id": "OPT-AZ-IAM-001",
#         "severity": "HIGH",
#         "resource": resource.address,
#         "message": sprintf("Administrative role '%s' requires Conditional Access policy", [resource.values.role_definition_name]),
#         "remediation": "Configure Conditional Access policies for administrative roles requiring MFA and device compliance"
#     }
# }
# 
# is_administrative_role(role_name) if {
#     administrative_roles := [
#         "Owner",
#         "Contributor",
#         "User Access Administrator",
#         "Security Administrator",
#         "Global Administrator",
#         "Privileged Role Administrator",
#         "Application Administrator"
#     ]
#     role_name in administrative_roles
# }
# 
# has_conditional_access_policy() if {
#     # This would need to be checked against Azure AD configuration
#     # For Terraform validation, we assume it's configured if referenced
#     policy := input.planned_values.root_module.resources[_]
#     policy.type == "azuread_conditional_access_policy"
# }

# CONTROL: OPT-AZ-IAM-002
# TITLE: Enforce Privileged Identity Management for all privileged access
# SEVERITY: HIGH
# FRAMEWORKS: NIST-800-53:AC-2, CIS-Azure:1.15, ISO-27001:A.9.2.1
# STATUS: DISABLED (uncomment to enable)
# OPTIONAL: true
# PREREQUISITES: Azure AD Premium P2 license and PIM configuration
# IMPACT: Changes privileged access workflow to just-in-time model

# deny contains msg if {
#     resource := input.planned_values.root_module.resources[_]
#     resource.type == "azurerm_role_assignment"
#     
#     # Check for privileged roles that should use PIM
#     is_privileged_role(resource.values.role_definition_name)
#     not is_pim_eligible_assignment(resource)
#     
#     msg := {
#         "control_id": "OPT-AZ-IAM-002",
#         "severity": "HIGH",
#         "resource": resource.address,
#         "message": sprintf("Privileged role '%s' should use PIM eligible assignment", [resource.values.role_definition_name]),
#         "remediation": "Configure role assignment as PIM eligible instead of permanent assignment"
#     }
# }
# 
# is_privileged_role(role_name) if {
#     privileged_roles := [
#         "Owner",
#         "User Access Administrator",
#         "Security Administrator",
#         "Global Administrator",
#         "Privileged Role Administrator"
#     ]
#     role_name in privileged_roles
# }
# 
# is_pim_eligible_assignment(assignment) if {
#     # Check if this is a PIM eligible assignment
#     # This would typically be managed through Azure AD PIM, not Terraform
#     assignment.values.condition != null
#     contains(assignment.values.condition, "eligible")
# }

# CONTROL: OPT-AZ-IAM-003
# TITLE: Require certificate-based authentication for service principals
# SEVERITY: MEDIUM
# FRAMEWORKS: NIST-800-53:IA-5, CIS-Azure:1.2, ISO-27001:A.9.4.2
# STATUS: DISABLED (uncomment to enable)
# OPTIONAL: true
# PREREQUISITES: Certificate management infrastructure in place
# IMPACT: Requires migration from password-based to certificate-based authentication

# deny contains msg if {
#     resource := input.planned_values.root_module.resources[_]
#     resource.type == "azuread_application_password"
#     
#     # Service principals should use certificates instead of passwords
#     msg := {
#         "control_id": "OPT-AZ-IAM-003",
#         "severity": "MEDIUM",
#         "resource": resource.address,
#         "message": "Service principal uses password authentication instead of certificate",
#         "remediation": "Replace azuread_application_password with azuread_application_certificate for enhanced security"
#     }
# }

# CONTROL: OPT-AZ-IAM-004
# TITLE: Enforce break-glass account monitoring and alerting
# SEVERITY: HIGH
# FRAMEWORKS: NIST-800-53:AC-2, CIS-Azure:1.16, ISO-27001:A.9.2.1
# STATUS: DISABLED (uncomment to enable)
# OPTIONAL: true
# PREREQUISITES: Monitoring and alerting infrastructure configured
# IMPACT: Requires additional monitoring configuration and alert handling procedures

# deny contains msg if {
#     resource := input.planned_values.root_module.resources[_]
#     resource.type == "azuread_user"
#     
#     # Check for break-glass accounts without proper monitoring
#     is_break_glass_account(resource.values)
#     not has_monitoring_configuration(resource.values.user_principal_name)
#     
#     msg := {
#         "control_id": "OPT-AZ-IAM-004",
#         "severity": "HIGH",
#         "resource": resource.address,
#         "message": "Break-glass account requires monitoring and alerting configuration",
#         "remediation": "Configure Azure Monitor alerts for break-glass account sign-ins and activities"
#     }
# }
# 
# is_break_glass_account(user) if {
#     # Identify break-glass accounts by naming convention or tags
#     contains(lower(user.user_principal_name), "breakglass")
# }
# 
# is_break_glass_account(user) if {
#     contains(lower(user.user_principal_name), "emergency")
# }
# 
# is_break_glass_account(user) if {
#     contains(lower(user.display_name), "break glass")
# }
# 
# has_monitoring_configuration(user_principal_name) if {
#     # Check for monitoring alert rules
#     alert := input.planned_values.root_module.resources[_]
#     alert.type == "azurerm_monitor_activity_log_alert"
#     contains(alert.values.criteria[_].category, "Administrative")
# }

# CONTROL: OPT-AZ-IAM-005
# TITLE: Require just-in-time access for virtual machine administration
# SEVERITY: MEDIUM
# FRAMEWORKS: NIST-800-53:AC-6, CIS-Azure:7.4, ISO-27001:A.9.2.3
# STATUS: DISABLED (uncomment to enable)
# OPTIONAL: true
# PREREQUISITES: Azure Security Center Standard tier and JIT configuration
# IMPACT: Changes VM access workflow to require JIT approval

# deny contains msg if {
#     resource := input.planned_values.root_module.resources[_]
#     resource.type == "azurerm_linux_virtual_machine"
#     
#     # Check if VM allows direct SSH access without JIT
#     allows_direct_ssh_access(resource)
#     not has_jit_configuration(resource)
#     
#     msg := {
#         "control_id": "OPT-AZ-IAM-005",
#         "severity": "MEDIUM",
#         "resource": resource.address,
#         "message": "Virtual machine allows direct SSH access without just-in-time configuration",
#         "remediation": "Configure Azure Security Center JIT VM access for administrative connections"
#     }
# }
# 
# deny contains msg if {
#     resource := input.planned_values.root_module.resources[_]
#     resource.type == "azurerm_windows_virtual_machine"
#     
#     # Check if VM allows direct RDP access without JIT
#     allows_direct_rdp_access(resource)
#     not has_jit_configuration(resource)
#     
#     msg := {
#         "control_id": "OPT-AZ-IAM-005",
#         "severity": "MEDIUM",
#         "resource": resource.address,
#         "message": "Virtual machine allows direct RDP access without just-in-time configuration",
#         "remediation": "Configure Azure Security Center JIT VM access for administrative connections"
#     }
# }
# 
# allows_direct_ssh_access(vm) if {
#     # Check associated NSG rules for SSH access
#     nsg := input.planned_values.root_module.resources[_]
#     nsg.type == "azurerm_network_security_rule"
#     nsg.values.destination_port_range == "22"
#     nsg.values.access == "Allow"
#     nsg.values.direction == "Inbound"
# }
# 
# allows_direct_rdp_access(vm) if {
#     # Check associated NSG rules for RDP access
#     nsg := input.planned_values.root_module.resources[_]
#     nsg.type == "azurerm_network_security_rule"
#     nsg.values.destination_port_range == "3389"
#     nsg.values.access == "Allow"
#     nsg.values.direction == "Inbound"
# }
# 
# has_jit_configuration(vm) if {
#     # Check for JIT policy configuration
#     jit := input.planned_values.root_module.resources[_]
#     jit.type == "azurerm_security_center_jit_network_access_policy"
#     vm_config := jit.values.virtual_machine[_]
#     vm_config.virtual_machine_id == vm.values.id
# }
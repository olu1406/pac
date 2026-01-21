# Multi-Cloud Security Policy System Makefile

.PHONY: help test validate scan clean install setup docs lint format

# Default target
.DEFAULT_GOAL := help

# Configuration
TERRAFORM_DIR ?= .
ENVIRONMENT ?= local
OUTPUT_FORMAT ?= json
SEVERITY_FILTER ?= all

# Colors for output
BLUE := \033[36m
GREEN := \033[32m
YELLOW := \033[33m
RED := \033[31m
NC := \033[0m

help: ## Show this help message
	@echo "$(BLUE)Multi-Cloud Security Policy System$(NC)"
	@echo ""
	@echo "$(GREEN)Available commands:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(GREEN)Configuration:$(NC)"
	@echo "  TERRAFORM_DIR=$(TERRAFORM_DIR)"
	@echo "  ENVIRONMENT=$(ENVIRONMENT)"
	@echo "  OUTPUT_FORMAT=$(OUTPUT_FORMAT)"
	@echo "  SEVERITY_FILTER=$(SEVERITY_FILTER)"

install: ## Install required dependencies
	@echo "$(BLUE)Installing dependencies...$(NC)"
	@if ! command -v terraform >/dev/null 2>&1; then \
		echo "$(RED)Error: terraform not found. Please install Terraform first.$(NC)"; \
		exit 1; \
	fi
	@if ! command -v conftest >/dev/null 2>&1; then \
		echo "$(YELLOW)Installing conftest...$(NC)"; \
		if command -v brew >/dev/null 2>&1; then \
			brew install conftest; \
		else \
			echo "$(RED)Error: conftest not found. Please install conftest manually.$(NC)"; \
			exit 1; \
		fi; \
	fi
	@if ! command -v opa >/dev/null 2>&1; then \
		echo "$(YELLOW)Installing OPA...$(NC)"; \
		if command -v brew >/dev/null 2>&1; then \
			brew install opa; \
		else \
			echo "$(RED)Error: opa not found. Please install OPA manually.$(NC)"; \
			exit 1; \
		fi; \
	fi
	@echo "$(GREEN)Dependencies installed successfully$(NC)"

setup: install ## Set up the development environment
	@echo "$(BLUE)Setting up development environment...$(NC)"
	@mkdir -p reports
	@mkdir -p .git/hooks
	@if [ -f scripts/setup-git-hooks.sh ]; then \
		chmod +x scripts/setup-git-hooks.sh; \
		./scripts/setup-git-hooks.sh; \
	fi
	@echo "$(GREEN)Development environment ready$(NC)"

validate: ## Validate policy syntax and structure
	@echo "$(BLUE)Validating policies...$(NC)"
	@if [ -d policies ]; then \
		find policies -name "*.rego" -exec opa fmt --diff {} \; || { \
			echo "$(RED)Policy formatting issues found$(NC)"; \
			exit 1; \
		}; \
		find policies -name "*.rego" -exec opa test {} \; || { \
			echo "$(RED)Policy syntax errors found$(NC)"; \
			exit 1; \
		}; \
		echo "$(GREEN)All policies are valid$(NC)"; \
	else \
		echo "$(YELLOW)No policies directory found$(NC)"; \
	fi

scan: ## Run security policy scan
	@echo "$(BLUE)Running security policy scan...$(NC)"
	@TERRAFORM_DIR=$(TERRAFORM_DIR) \
	 ENVIRONMENT=$(ENVIRONMENT) \
	 OUTPUT_FORMAT=$(OUTPUT_FORMAT) \
	 SEVERITY_FILTER=$(SEVERITY_FILTER) \
	 ./scripts/scan.sh

test: ## Run all tests
	@echo "$(BLUE)Running tests...$(NC)"
	@if [ -d tests ]; then \
		for test_script in tests/test-*.sh; do \
			if [ -f "$$test_script" ]; then \
				echo "$(YELLOW)Running $$test_script...$(NC)"; \
				chmod +x "$$test_script"; \
				"$$test_script" || exit 1; \
			fi; \
		done; \
		echo "$(GREEN)All tests passed$(NC)"; \
	else \
		echo "$(YELLOW)No tests directory found$(NC)"; \
	fi

test-examples: ## Test good and bad examples
	@echo "$(BLUE)Testing example configurations...$(NC)"
	@if [ -d examples/good ]; then \
		for example in examples/good/*/; do \
			if [ -d "$$example" ]; then \
				echo "$(YELLOW)Testing good example: $$example$(NC)"; \
				TERRAFORM_DIR="$$example" $(MAKE) scan || { \
					echo "$(RED)Good example failed: $$example$(NC)"; \
					exit 1; \
				}; \
			fi; \
		done; \
	fi
	@if [ -d examples/bad ]; then \
		for example in examples/bad/*/; do \
			if [ -d "$$example" ]; then \
				echo "$(YELLOW)Testing bad example: $$example$(NC)"; \
				TERRAFORM_DIR="$$example" $(MAKE) scan && { \
					echo "$(RED)Bad example should have failed: $$example$(NC)"; \
					exit 1; \
				} || echo "$(GREEN)Bad example correctly failed: $$example$(NC)"; \
			fi; \
		done; \
	fi
	@echo "$(GREEN)Example testing completed$(NC)"

lint: ## Lint all code and policies
	@echo "$(BLUE)Linting code and policies...$(NC)"
	@# Lint shell scripts
	@if command -v shellcheck >/dev/null 2>&1; then \
		find scripts -name "*.sh" -exec shellcheck {} \; || { \
			echo "$(RED)Shell script linting failed$(NC)"; \
			exit 1; \
		}; \
	else \
		echo "$(YELLOW)shellcheck not found, skipping shell script linting$(NC)"; \
	fi
	@# Lint Rego policies
	@if [ -d policies ]; then \
		find policies -name "*.rego" -exec opa fmt --diff {} \; || { \
			echo "$(RED)Rego policy formatting issues found$(NC)"; \
			exit 1; \
		}; \
	fi
	@echo "$(GREEN)Linting completed$(NC)"

format: ## Format all code and policies
	@echo "$(BLUE)Formatting code and policies...$(NC)"
	@# Format Rego policies
	@if [ -d policies ]; then \
		find policies -name "*.rego" -exec opa fmt --write {} \;; \
		echo "$(GREEN)Rego policies formatted$(NC)"; \
	fi

docs: ## Generate documentation
	@echo "$(BLUE)Generating documentation...$(NC)"
	@if [ -f scripts/generate-docs.sh ]; then \
		chmod +x scripts/generate-docs.sh; \
		./scripts/generate-docs.sh; \
	else \
		echo "$(YELLOW)Documentation generator not found$(NC)"; \
	fi

clean: ## Clean up generated files
	@echo "$(BLUE)Cleaning up...$(NC)"
	@rm -rf reports/
	@rm -f terraform.tfplan
	@rm -f terraform.tfstate.backup
	@find . -name "*.tfplan" -delete
	@find . -name ".terraform.lock.hcl" -delete
	@echo "$(GREEN)Cleanup completed$(NC)"

clean-all: clean ## Clean up everything including .terraform directories
	@echo "$(BLUE)Deep cleaning...$(NC)"
	@find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	@echo "$(GREEN)Deep cleanup completed$(NC)"

# Development targets
dev-setup: setup ## Alias for setup
dev-test: validate test ## Run validation and tests for development
dev-scan: validate scan ## Run validation and scan for development

# CI/CD targets
ci-install: install ## Install dependencies for CI
ci-validate: validate lint ## Validate for CI
ci-test: test test-examples ## Run all tests for CI
ci-scan: scan ## Run scan for CI

# Environment-specific targets
scan-dev: ## Scan with development environment
	@$(MAKE) scan ENVIRONMENT=dev

scan-test: ## Scan with test environment
	@$(MAKE) scan ENVIRONMENT=test

scan-prod: ## Scan with production environment
	@$(MAKE) scan ENVIRONMENT=prod

# Output format targets
scan-json: ## Generate JSON report only
	@$(MAKE) scan OUTPUT_FORMAT=json

scan-markdown: ## Generate Markdown report only
	@$(MAKE) scan OUTPUT_FORMAT=markdown

scan-both: ## Generate both JSON and Markdown reports
	@$(MAKE) scan OUTPUT_FORMAT=both

# Severity filtering targets
scan-critical: ## Show only critical violations
	@$(MAKE) scan SEVERITY_FILTER=critical

scan-high: ## Show high and critical violations
	@$(MAKE) scan SEVERITY_FILTER=high

scan-medium: ## Show medium, high, and critical violations
	@$(MAKE) scan SEVERITY_FILTER=medium

# Help for specific commands
help-scan: ## Show detailed scan help
	@./scripts/scan.sh --help

help-make: ## Show Makefile variables and targets
	@echo "$(BLUE)Makefile Configuration Variables:$(NC)"
	@echo "  TERRAFORM_DIR    - Directory containing Terraform files (default: .)"
	@echo "  ENVIRONMENT      - Environment name for reporting (default: local)"
	@echo "  OUTPUT_FORMAT    - Report format: json, markdown, both (default: json)"
	@echo "  SEVERITY_FILTER  - Filter by severity: low, medium, high, critical, all (default: all)"
	@echo ""
	@echo "$(BLUE)Example Usage:$(NC)"
	@echo "  make scan TERRAFORM_DIR=./infrastructure ENVIRONMENT=prod"
	@echo "  make test-examples"
	@echo "  make scan-critical OUTPUT_FORMAT=both"

# Property-based testing targets
test-pbt: ## Run property-based tests
	@echo "$(BLUE)Running property-based tests...$(NC)"
	@if [ -f scripts/run-pbt.sh ]; then \
		chmod +x scripts/run-pbt.sh; \
		./scripts/run-pbt.sh --iterations 50; \
	else \
		echo "$(YELLOW)Property-based test runner not found$(NC)"; \
	fi

test-pbt-quick: ## Run property-based tests with fewer iterations
	@echo "$(BLUE)Running quick property-based tests...$(NC)"
	@if [ -f scripts/run-pbt.sh ]; then \
		chmod +x scripts/run-pbt.sh; \
		./scripts/run-pbt.sh --iterations 10; \
	else \
		echo "$(YELLOW)Property-based test runner not found$(NC)"; \
	fi

test-pbt-parallel: ## Run property-based tests in parallel
	@echo "$(BLUE)Running property-based tests in parallel...$(NC)"
	@if [ -f scripts/run-pbt.sh ]; then \
		chmod +x scripts/run-pbt.sh; \
		./scripts/run-pbt.sh --parallel --iterations 50; \
	else \
		echo "$(YELLOW)Property-based test runner not found$(NC)"; \
	fi

test-pbt-specific: ## Run specific property-based test (use TEST_NAME=test-name)
	@echo "$(BLUE)Running specific property-based test: $(TEST_NAME)...$(NC)"
	@if [ -f scripts/run-pbt.sh ] && [ -n "$(TEST_NAME)" ]; then \
		chmod +x scripts/run-pbt.sh; \
		./scripts/run-pbt.sh --test $(TEST_NAME) --iterations 25; \
	else \
		echo "$(RED)Usage: make test-pbt-specific TEST_NAME=policy-consistency$(NC)"; \
		echo "$(YELLOW)Available tests: policy-consistency, control-toggle, report-format, syntax-validation, no-credentials$(NC)"; \
	fi

test-all: test test-pbt test-examples ## Run all tests including property-based tests
#!/bin/bash

# Multi-Cloud Security Policy - Local Development Setup
# Sets up local development environment with watch mode and pre-commit hooks

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default configuration
INSTALL_DEPS="${INSTALL_DEPS:-true}"
SETUP_HOOKS="${SETUP_HOOKS:-true}"
SETUP_WATCH="${SETUP_WATCH:-false}"
VERBOSE="${VERBOSE:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1" >&2
    fi
}

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Multi-Cloud Security Policy - Local Development Setup

Sets up local development environment with:
- Dependency installation and validation
- Git pre-commit hooks for policy validation
- Watch mode for policy development iteration
- Development configuration and tools

OPTIONS:
    --no-deps               Skip dependency installation
    --no-hooks              Skip pre-commit hook setup
    --watch                 Enable watch mode for policy development
    -v, --verbose           Enable verbose output
    -h, --help              Show this help message

EXAMPLES:
    $0                      # Full setup with dependencies and hooks
    $0 --no-deps            # Setup without installing dependencies
    $0 --watch              # Setup with watch mode enabled
    $0 --no-hooks --watch   # Setup with watch mode but no git hooks

ENVIRONMENT VARIABLES:
    INSTALL_DEPS            Install dependencies (true/false, default: true)
    SETUP_HOOKS             Setup git hooks (true/false, default: true)
    SETUP_WATCH             Enable watch mode (true/false, default: false)
    VERBOSE                 Enable verbose output (true/false, default: false)

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --no-deps)
                INSTALL_DEPS="false"
                shift
                ;;
            --no-hooks)
                SETUP_HOOKS="false"
                shift
                ;;
            --watch)
                SETUP_WATCH="true"
                shift
                ;;
            -v|--verbose)
                VERBOSE="true"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Check if running in git repository
check_git_repo() {
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_error "Not in a git repository. Git hooks setup will be skipped."
        SETUP_HOOKS="false"
    fi
}

# Install system dependencies
install_dependencies() {
    if [[ "$INSTALL_DEPS" != "true" ]]; then
        log_info "Skipping dependency installation"
        return 0
    fi

    log_info "Installing and validating dependencies..."

    # Check for package managers
    local has_brew=false
    local has_apt=false
    
    if command -v brew >/dev/null 2>&1; then
        has_brew=true
        log_debug "Found Homebrew package manager"
    fi
    
    if command -v apt-get >/dev/null 2>&1; then
        has_apt=true
        log_debug "Found APT package manager"
    fi

    # Install Terraform
    if ! command -v terraform >/dev/null 2>&1; then
        log_info "Installing Terraform..."
        if $has_brew; then
            brew tap hashicorp/tap
            brew install hashicorp/tap/terraform
        elif $has_apt; then
            wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
            echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
            sudo apt update && sudo apt install terraform
        else
            log_warn "Please install Terraform manually: https://www.terraform.io/downloads.html"
        fi
    else
        log_success "Terraform already installed: $(terraform version | head -n1)"
    fi

    # Install OPA
    if ! command -v opa >/dev/null 2>&1; then
        log_info "Installing Open Policy Agent (OPA)..."
        if $has_brew; then
            brew install opa
        elif $has_apt; then
            curl -L -o opa https://openpolicyagent.org/downloads/v0.57.0/opa_linux_amd64_static
            chmod 755 ./opa
            sudo mv opa /usr/local/bin/
        else
            log_warn "Please install OPA manually: https://www.openpolicyagent.org/docs/latest/#running-opa"
        fi
    else
        log_success "OPA already installed: $(opa version)"
    fi

    # Install Conftest
    if ! command -v conftest >/dev/null 2>&1; then
        log_info "Installing Conftest..."
        if $has_brew; then
            brew install conftest
        elif $has_apt; then
            wget https://github.com/open-policy-agent/conftest/releases/download/v0.46.0/conftest_0.46.0_Linux_x86_64.tar.gz
            tar xzf conftest_0.46.0_Linux_x86_64.tar.gz
            sudo mv conftest /usr/local/bin/
            rm conftest_0.46.0_Linux_x86_64.tar.gz
        else
            log_warn "Please install Conftest manually: https://www.conftest.dev/install/"
        fi
    else
        log_success "Conftest already installed: $(conftest --version | head -n1)"
    fi

    # Install jq
    if ! command -v jq >/dev/null 2>&1; then
        log_info "Installing jq..."
        if $has_brew; then
            brew install jq
        elif $has_apt; then
            sudo apt-get update && sudo apt-get install -y jq
        else
            log_warn "Please install jq manually: https://stedolan.github.io/jq/download/"
        fi
    else
        log_success "jq already installed: $(jq --version)"
    fi

    # Install optional development tools
    install_optional_tools
}

# Install optional development tools
install_optional_tools() {
    log_info "Installing optional development tools..."

    # Install shellcheck for shell script linting
    if ! command -v shellcheck >/dev/null 2>&1; then
        log_info "Installing shellcheck..."
        if command -v brew >/dev/null 2>&1; then
            brew install shellcheck
        elif command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update && sudo apt-get install -y shellcheck
        else
            log_warn "shellcheck not installed - shell script linting will be skipped"
        fi
    else
        log_success "shellcheck already installed: $(shellcheck --version | head -n1)"
    fi

    # Install fswatch for file watching (if watch mode requested)
    if [[ "$SETUP_WATCH" == "true" ]] && ! command -v fswatch >/dev/null 2>&1; then
        log_info "Installing fswatch for watch mode..."
        if command -v brew >/dev/null 2>&1; then
            brew install fswatch
        elif command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update && sudo apt-get install -y fswatch
        else
            log_warn "fswatch not installed - watch mode may not work properly"
        fi
    fi
}

# Create development directories
create_dev_directories() {
    log_info "Creating development directories..."

    # Create reports directory
    mkdir -p "$PROJECT_ROOT/reports"
    log_debug "Created reports directory"

    # Create .git/hooks directory if it doesn't exist
    if [[ "$SETUP_HOOKS" == "true" ]]; then
        mkdir -p "$PROJECT_ROOT/.git/hooks"
        log_debug "Created git hooks directory"
    fi

    # Create development configuration directory
    mkdir -p "$PROJECT_ROOT/.dev"
    log_debug "Created development configuration directory"
}

# Setup pre-commit hooks
setup_git_hooks() {
    if [[ "$SETUP_HOOKS" != "true" ]]; then
        log_info "Skipping git hooks setup"
        return 0
    fi

    log_info "Setting up git pre-commit hooks..."

    # Create pre-commit hook
    cat > "$PROJECT_ROOT/.git/hooks/pre-commit" << 'EOF'
#!/bin/bash

# Multi-Cloud Security Policy - Pre-commit Hook
# Validates policies before commit

set -e

echo "🔍 Running pre-commit validation..."

# Get the project root
PROJECT_ROOT="$(git rev-parse --show-toplevel)"

# Check if we have any .rego files in the commit
if git diff --cached --name-only | grep -q '\.rego$'; then
    echo "📋 Validating Rego policies..."
    
    # Run policy validation
    if [ -f "$PROJECT_ROOT/scripts/validate-policies.sh" ]; then
        cd "$PROJECT_ROOT"
        ./scripts/validate-policies.sh -f json -o .dev/pre-commit-validation.json
        
        # Check for critical/high severity issues
        if [ -f .dev/pre-commit-validation.json ]; then
            errors=$(jq '[.violations[] | select(.severity == "CRITICAL" or .severity == "HIGH")] | length' .dev/pre-commit-validation.json 2>/dev/null || echo "0")
            if [ "$errors" -gt 0 ]; then
                echo "❌ Found $errors critical/high severity policy validation errors:"
                jq -r '.violations[] | select(.severity == "CRITICAL" or .severity == "HIGH") | "  \(.file):\(.line) - \(.message)"' .dev/pre-commit-validation.json
                echo ""
                echo "Please fix these issues before committing."
                exit 1
            fi
        fi
    else
        echo "⚠️  Policy validation script not found, skipping validation"
    fi
fi

# Check if we have any shell scripts in the commit
if git diff --cached --name-only | grep -q '\.sh$'; then
    echo "🐚 Validating shell scripts..."
    
    if command -v shellcheck >/dev/null 2>&1; then
        # Run shellcheck on modified shell scripts
        git diff --cached --name-only | grep '\.sh$' | while read -r script; do
            if [ -f "$script" ]; then
                echo "  Checking $script..."
                if ! shellcheck "$script"; then
                    echo "❌ Shell script validation failed for $script"
                    exit 1
                fi
            fi
        done
    else
        echo "⚠️  shellcheck not found, skipping shell script validation"
    fi
fi

# Check for potential secrets
echo "🔐 Scanning for potential secrets..."
if [ -f "$PROJECT_ROOT/scripts/scan-secrets.sh" ]; then
    cd "$PROJECT_ROOT"
    
    # Create a temporary directory for staged files
    temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT
    
    # Export staged files to temp directory
    git diff --cached --name-only | while read -r file; do
        if [ -f "$file" ]; then
            mkdir -p "$temp_dir/$(dirname "$file")"
            git show ":$file" > "$temp_dir/$file"
        fi
    done
    
    # Scan the staged files
    if ./scripts/scan-secrets.sh -d "$temp_dir" -o json >/dev/null 2>&1; then
        echo "✅ No secrets detected in staged files"
    else
        echo "❌ Potential secrets detected in staged files"
        echo "Please review and remove any hardcoded credentials before committing."
        exit 1
    fi
else
    echo "⚠️  Secret scanning script not found, skipping secret scan"
fi

echo "✅ Pre-commit validation passed!"
EOF

    # Make the hook executable
    chmod +x "$PROJECT_ROOT/.git/hooks/pre-commit"
    log_success "Pre-commit hook installed"

    # Create commit-msg hook for conventional commits
    cat > "$PROJECT_ROOT/.git/hooks/commit-msg" << 'EOF'
#!/bin/bash

# Multi-Cloud Security Policy - Commit Message Hook
# Validates commit message format

commit_regex='^(feat|fix|docs|style|refactor|test|chore|policy|security)(\(.+\))?: .{1,50}'

if ! grep -qE "$commit_regex" "$1"; then
    echo "❌ Invalid commit message format!"
    echo ""
    echo "Commit messages should follow the format:"
    echo "  type(scope): description"
    echo ""
    echo "Types: feat, fix, docs, style, refactor, test, chore, policy, security"
    echo "Example: feat(aws): add S3 encryption policy"
    echo "Example: fix(azure): correct RBAC policy syntax"
    echo ""
    exit 1
fi
EOF

    chmod +x "$PROJECT_ROOT/.git/hooks/commit-msg"
    log_success "Commit message hook installed"
}

# Create development configuration files
create_dev_config() {
    log_info "Creating development configuration..."

    # Create development environment file
    cat > "$PROJECT_ROOT/.dev/config.env" << EOF
# Multi-Cloud Security Policy - Development Configuration
# Source this file to set up development environment variables

# Default development settings
export ENVIRONMENT=development
export OUTPUT_FORMAT=both
export VERBOSE=true
export TERRAFORM_DIR=\${TERRAFORM_DIR:-\$PWD}

# Policy validation settings
export CHECK_IMPORTS=true
export CHECK_METADATA=true
export FAIL_FAST=false

# Secret scanning settings
export EXCLUDE_DIRS=".git,.terraform,node_modules,reports,.dev"
export EXCLUDE_FILES="*.log,*.tfplan,*.tfstate,*.tfstate.backup"

# Development paths
export PROJECT_ROOT="$PROJECT_ROOT"
export POLICIES_DIR="\$PROJECT_ROOT/policies"
export EXAMPLES_DIR="\$PROJECT_ROOT/examples"
export REPORTS_DIR="\$PROJECT_ROOT/reports"

# Tool versions (for consistency)
export TERRAFORM_VERSION="1.5.0"
export CONFTEST_VERSION="0.46.0"
export OPA_VERSION="0.57.0"

echo "🚀 Development environment configured"
echo "Project root: \$PROJECT_ROOT"
echo "Environment: \$ENVIRONMENT"
EOF

    # Create development aliases
    cat > "$PROJECT_ROOT/.dev/aliases.sh" << 'EOF'
#!/bin/bash

# Multi-Cloud Security Policy - Development Aliases
# Convenient shortcuts for development tasks

# Policy development
alias policy-validate='./scripts/validate-policies.sh -v'
alias policy-test='./scripts/test-policies.sh -v'
alias policy-format='find policies -name "*.rego" -exec opa fmt --write {} \;'

# Security scanning
alias scan-secrets='./scripts/scan-secrets.sh -v'
alias scan-full='./scripts/scan.sh -v -o both'

# Example testing
alias test-good='./scripts/test-policies.sh -t positive -v'
alias test-bad='./scripts/test-policies.sh -t negative -v'
alias test-examples='make test-examples'

# Quick development tasks
alias dev-check='policy-validate && scan-secrets'
alias dev-test='policy-test && test-examples'
alias dev-clean='make clean'

# Watch mode functions
watch-policies() {
    echo "👀 Watching for policy changes..."
    if command -v fswatch >/dev/null 2>&1; then
        fswatch -o policies/ | while read f; do
            echo "🔄 Policy change detected, running validation..."
            policy-validate
        done
    else
        echo "❌ fswatch not installed. Install with: brew install fswatch"
    fi
}

watch-examples() {
    echo "👀 Watching for example changes..."
    if command -v fswatch >/dev/null 2>&1; then
        fswatch -o examples/ | while read f; do
            echo "🔄 Example change detected, running tests..."
            test-examples
        done
    else
        echo "❌ fswatch not installed. Install with: brew install fswatch"
    fi
}

# Development workflow
dev-workflow() {
    echo "🚀 Starting development workflow..."
    echo "1. Validating policies..."
    policy-validate
    echo "2. Testing examples..."
    test-examples
    echo "3. Scanning for secrets..."
    scan-secrets
    echo "✅ Development workflow completed!"
}

echo "📝 Development aliases loaded:"
echo "  policy-validate  - Validate policy syntax"
echo "  policy-test      - Test policies"
echo "  policy-format    - Format policy files"
echo "  scan-secrets     - Scan for secrets"
echo "  scan-full        - Full security scan"
echo "  test-good        - Test good examples"
echo "  test-bad         - Test bad examples"
echo "  test-examples    - Test all examples"
echo "  dev-check        - Quick validation check"
echo "  dev-test         - Full development test"
echo "  dev-clean        - Clean generated files"
echo "  watch-policies   - Watch policy files for changes"
echo "  watch-examples   - Watch example files for changes"
echo "  dev-workflow     - Run complete development workflow"
EOF

    chmod +x "$PROJECT_ROOT/.dev/aliases.sh"
    log_success "Development configuration created"
}

# Setup watch mode
setup_watch_mode() {
    if [[ "$SETUP_WATCH" != "true" ]]; then
        log_info "Watch mode not requested"
        return 0
    fi

    log_info "Setting up watch mode for policy development..."

    # Create watch script
    cat > "$PROJECT_ROOT/.dev/watch.sh" << 'EOF'
#!/bin/bash

# Multi-Cloud Security Policy - Watch Mode
# Automatically runs validation when files change

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# Source development configuration
if [ -f .dev/config.env ]; then
    source .dev/config.env
fi

# Source development aliases
if [ -f .dev/aliases.sh ]; then
    source .dev/aliases.sh
fi

echo "🚀 Multi-Cloud Security Policy - Watch Mode"
echo "Project: $PROJECT_ROOT"
echo "Press Ctrl+C to stop watching"
echo ""

# Check if fswatch is available
if ! command -v fswatch >/dev/null 2>&1; then
    echo "❌ fswatch not found. Please install it:"
    echo "  macOS: brew install fswatch"
    echo "  Ubuntu: sudo apt-get install fswatch"
    exit 1
fi

# Function to run validation
run_validation() {
    echo "🔄 $(date '+%H:%M:%S') - Running validation..."
    
    # Run policy validation
    if ./scripts/validate-policies.sh -f json -o .dev/watch-validation.json >/dev/null 2>&1; then
        echo "✅ Policy validation passed"
    else
        echo "❌ Policy validation failed"
        if [ -f .dev/watch-validation.json ]; then
            jq -r '.violations[] | select(.severity == "CRITICAL" or .severity == "HIGH") | "  \(.file):\(.line) - \(.message)"' .dev/watch-validation.json
        fi
    fi
    
    echo ""
}

# Initial validation
run_validation

# Watch for changes
echo "👀 Watching for changes in policies/ and examples/..."
fswatch -r policies/ examples/ | while read f; do
    run_validation
done
EOF

    chmod +x "$PROJECT_ROOT/.dev/watch.sh"
    log_success "Watch mode script created at .dev/watch.sh"
    
    if command -v fswatch >/dev/null 2>&1; then
        log_info "To start watch mode, run: ./.dev/watch.sh"
    else
        log_warn "fswatch not installed - watch mode will not work until fswatch is installed"
    fi
}

# Create development documentation
create_dev_docs() {
    log_info "Creating development documentation..."

    cat > "$PROJECT_ROOT/.dev/README.md" << 'EOF'
# Development Environment

This directory contains development tools and configuration for the Multi-Cloud Security Policy system.

## Quick Start

1. **Setup development environment:**
   ```bash
   ./scripts/dev-setup.sh
   ```

2. **Load development configuration:**
   ```bash
   source .dev/config.env
   source .dev/aliases.sh
   ```

3. **Run development workflow:**
   ```bash
   dev-workflow
   ```

## Development Tools

### Configuration Files

- `config.env` - Environment variables for development
- `aliases.sh` - Convenient command aliases
- `watch.sh` - File watching for automatic validation

### Available Aliases

- `policy-validate` - Validate policy syntax and structure
- `policy-test` - Test policies against examples
- `policy-format` - Format policy files with OPA
- `scan-secrets` - Scan for hardcoded secrets
- `scan-full` - Run complete security scan
- `test-good` - Test good examples (should pass)
- `test-bad` - Test bad examples (should fail)
- `test-examples` - Test all examples
- `dev-check` - Quick validation and security check
- `dev-test` - Complete development test suite
- `dev-clean` - Clean generated files
- `watch-policies` - Watch policy files for changes
- `watch-examples` - Watch example files for changes
- `dev-workflow` - Run complete development workflow

### Watch Mode

Start watch mode to automatically validate changes:

```bash
./.dev/watch.sh
```

This will monitor `policies/` and `examples/` directories and run validation whenever files change.

### Git Hooks

Pre-commit hooks are automatically installed to:

- Validate Rego policy syntax
- Check shell scripts with shellcheck
- Scan for potential secrets
- Enforce commit message format

### Development Workflow

1. **Make changes** to policies or examples
2. **Run validation** with `dev-check`
3. **Test changes** with `dev-test`
4. **Commit changes** (hooks will run automatically)
5. **Push changes** for CI validation

### Troubleshooting

**Policy validation fails:**
- Check syntax with `opa fmt --diff policies/`
- Validate metadata format
- Ensure required imports are present

**Tests fail:**
- Check example Terraform syntax
- Verify policy logic matches expected behavior
- Review test output for specific failures

**Watch mode not working:**
- Install fswatch: `brew install fswatch` (macOS) or `sudo apt-get install fswatch` (Ubuntu)
- Check file permissions on `.dev/watch.sh`

**Git hooks not running:**
- Ensure hooks are executable: `chmod +x .git/hooks/*`
- Check git configuration: `git config core.hooksPath`

### IDE Integration

For VS Code, install these extensions:
- Open Policy Agent (OPA) extension for Rego syntax highlighting
- Terraform extension for .tf file support
- ShellCheck extension for shell script linting

### Performance Tips

- Use `FAIL_FAST=true` for faster feedback during development
- Run specific test types with `-t positive` or `-t negative`
- Use watch mode for continuous validation during policy development
EOF

    log_success "Development documentation created at .dev/README.md"
}

# Display setup summary
display_summary() {
    log_info "=== Development Environment Setup Complete ==="
    echo ""
    
    log_success "✅ Development directories created"
    if [[ "$INSTALL_DEPS" == "true" ]]; then
        log_success "✅ Dependencies installed and validated"
    fi
    if [[ "$SETUP_HOOKS" == "true" ]]; then
        log_success "✅ Git pre-commit hooks installed"
    fi
    log_success "✅ Development configuration created"
    log_success "✅ Development aliases and tools ready"
    if [[ "$SETUP_WATCH" == "true" ]]; then
        log_success "✅ Watch mode configured"
    fi
    log_success "✅ Development documentation created"
    
    echo ""
    log_info "🚀 Next Steps:"
    echo "  1. Load development environment:"
    echo "     source .dev/config.env && source .dev/aliases.sh"
    echo ""
    echo "  2. Run development workflow:"
    echo "     dev-workflow"
    echo ""
    if [[ "$SETUP_WATCH" == "true" ]]; then
        echo "  3. Start watch mode (optional):"
        echo "     ./.dev/watch.sh"
        echo ""
    fi
    echo "  4. Read development guide:"
    echo "     cat .dev/README.md"
    echo ""
    
    log_info "📚 Available commands:"
    echo "  make dev-setup    - Re-run this setup"
    echo "  make dev-test     - Run development tests"
    echo "  make dev-scan     - Run development scan"
    echo "  dev-workflow      - Complete development workflow"
    echo ""
}

# Main execution
main() {
    parse_args "$@"
    
    log_info "Starting Multi-Cloud Security Policy development setup"
    
    # Change to project root
    cd "$PROJECT_ROOT"
    
    # Check git repository
    check_git_repo
    
    # Create development directories
    create_dev_directories
    
    # Install dependencies
    install_dependencies
    
    # Setup git hooks
    setup_git_hooks
    
    # Create development configuration
    create_dev_config
    
    # Setup watch mode
    setup_watch_mode
    
    # Create development documentation
    create_dev_docs
    
    # Display summary
    display_summary
    
    log_success "Development environment setup completed successfully!"
}

# Run main function
main "$@"
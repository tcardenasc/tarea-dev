#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

# Check if argument is provided
if [ $# -eq 0 ]; then
    print_error "No GitHub URL provided"
    echo "Usage: $0 <github-url>"
    echo "Example: $0 https://github.com/username/repository"
    exit 1
fi

GITHUB_URL=$1

# Validate GitHub URL format
if [[ ! "$GITHUB_URL" =~ ^https://github\.com/[^/]+/[^/]+(.git)?$ ]]; then
    print_error "Invalid GitHub URL format"
    echo "Expected format: https://github.com/username/repository"
    exit 1
fi

# Extract repository name and username from URL
REPO_NAME=$(basename "$GITHUB_URL" .git)
# Extract username from URL (e.g., from https://github.com/username/repo)
GITHUB_USERNAME=$(echo "$GITHUB_URL" | sed -E 's|https://github\.com/([^/]+)/.*|\1|')
print_info "Repository: $REPO_NAME (by $GITHUB_USERNAME)"

# Store the original directory where the script was called from
ORIGINAL_DIR="$(pwd)"

# Create a cloned-repos folder if it doesn't exist
REPOS_DIR="$ORIGINAL_DIR/cloned-repos"
if [ ! -d "$REPOS_DIR" ]; then
    mkdir -p "$REPOS_DIR"
    print_info "Created directory: $REPOS_DIR"
fi

# Function to return to original directory and exit
cleanup_and_exit() {
    cd "$ORIGINAL_DIR" 2>/dev/null
    exit $1
}

# Check if git is installed
if ! command -v git &> /dev/null; then
    print_error "git is not installed. Please install git first."
    cleanup_and_exit 1
fi

# Change to repos directory
cd "$REPOS_DIR" || exit 1

# Create user directory if it doesn't exist
USER_DIR="$GITHUB_USERNAME"
if [ ! -d "$USER_DIR" ]; then
    mkdir -p "$USER_DIR"
    print_info "Created user directory: $USER_DIR"
fi

# Change to user directory
cd "$USER_DIR" || exit 1

# Check if repository already exists
if [ -d "$REPO_NAME" ]; then
    print_info "Repository already exists. Skipping clone."
    print_step "Using existing repository at: $REPOS_DIR/$USER_DIR/$REPO_NAME"
else
    # Clone the repository
    print_step "Cloning repository into $USER_DIR/$REPO_NAME..."
    if git clone "$GITHUB_URL" "$REPO_NAME"; then
        print_success "Repository cloned successfully"
    else
    print_error "Failed to clone repository"
    cleanup_and_exit 1
    fi
fi

# Change to repository directory
cd "$REPO_NAME" || exit 1

# Function to find files recursively
find_file() {
    local filename=$1
    find . -name "$filename" -type f 2>/dev/null | head -1
}

# Detect project type
print_step "Detecting project type..."

PACKAGE_JSON=$(find_file "package.json")
MAIN_PY=$(find_file "main.py")
PROJECT_TYPE=""
PROJECT_DIR=""

# Check if both Python and TypeScript versions exist
if [ -n "$PACKAGE_JSON" ] && [ -n "$MAIN_PY" ]; then
    print_info "Both Python and TypeScript versions found. Checking git history..."
    
    # Get the directories
    TS_DIR=$(dirname "$PACKAGE_JSON")
    PY_DIR=$(dirname "$MAIN_PY")
    
    # Check latest commits in each directory
    print_step "Analyzing recent commits to determine which version was modified..."
    
    # Get the latest commit timestamp for TypeScript files
    TS_LATEST=$(git log -1 --format="%at" -- "$TS_DIR" 2>/dev/null || echo "0")
    
    # Get the latest commit timestamp for Python files
    PY_LATEST=$(git log -1 --format="%at" -- "$PY_DIR" 2>/dev/null || echo "0")
    
    # Show the last commits for each
    echo ""
    echo "Latest TypeScript changes:"
    git log -1 --oneline -- "$TS_DIR" 2>/dev/null || echo "  No commits found"
    echo ""
    echo "Latest Python changes:"
    git log -1 --oneline -- "$PY_DIR" 2>/dev/null || echo "  No commits found"
    echo ""
    
    # Compare timestamps
    if [ "$TS_LATEST" -gt "$PY_LATEST" ]; then
        PROJECT_TYPE="nodejs"
        PROJECT_DIR="$TS_DIR"
        print_info "TypeScript version has more recent changes. Using TypeScript."
    elif [ "$PY_LATEST" -gt "$TS_LATEST" ]; then
        PROJECT_TYPE="python"
        PROJECT_DIR="$PY_DIR"
        print_info "Python version has more recent changes. Using Python."
    else
        # If timestamps are equal or both are 0, check which has actual implementation
        print_info "No clear recent changes. Checking for implementation..."
        
        # Check if Python has actual implementation (not just template)
        if grep -q "return 0" "$PY_DIR/main.py" 2>/dev/null; then
            PY_IMPLEMENTED=false
        else
            PY_IMPLEMENTED=true
        fi
        
        # Check if TypeScript has actual implementation
        if grep -q "return 0" "$TS_DIR/main.ts" 2>/dev/null; then
            TS_IMPLEMENTED=false
        else
            TS_IMPLEMENTED=true
        fi
        
        if [ "$PY_IMPLEMENTED" = true ] && [ "$TS_IMPLEMENTED" = false ]; then
            PROJECT_TYPE="python"
            PROJECT_DIR="$PY_DIR"
            print_info "Python version appears to be implemented. Using Python."
        elif [ "$TS_IMPLEMENTED" = true ] && [ "$PY_IMPLEMENTED" = false ]; then
            PROJECT_TYPE="nodejs"
            PROJECT_DIR="$TS_DIR"
            print_info "TypeScript version appears to be implemented. Using TypeScript."
        else
            # Default to Python if both or neither are implemented
            PROJECT_TYPE="python"
            PROJECT_DIR="$PY_DIR"
            print_info "Both versions exist. Defaulting to Python (no npm required)."
        fi
    fi
elif [ -n "$PACKAGE_JSON" ]; then
    PROJECT_TYPE="nodejs"
    PROJECT_DIR=$(dirname "$PACKAGE_JSON")
    print_info "Detected Node.js/TypeScript project in: $PROJECT_DIR"
elif [ -n "$MAIN_PY" ]; then
    PROJECT_TYPE="python"
    PROJECT_DIR=$(dirname "$MAIN_PY")
    print_info "Detected Python project in: $PROJECT_DIR"
else
    print_error "Could not detect project type. No package.json or main.py found."
    cleanup_and_exit 1
fi

print_step "Looking for internal/test_cases.json..."

# First check if internal/test_cases.json exists in the original directory structure
INTERNAL_TEST_CASES=""
if [ -f "$ORIGINAL_DIR/internal/test_cases.json" ]; then
    INTERNAL_TEST_CASES="$ORIGINAL_DIR/internal/test_cases.json"
elif [ -f "$ORIGINAL_DIR/junior/internal/test_cases.json" ]; then
    INTERNAL_TEST_CASES="$ORIGINAL_DIR/junior/internal/test_cases.json"
else
    # If not found in original directory, look in the cloned repository
    INTERNAL_TEST_CASES=$(find . -name "test_cases.json" -path "*/internal/*" -type f 2>/dev/null | head -1)
    
    if [ -z "$INTERNAL_TEST_CASES" ]; then
        # Try alternative pattern
        INTERNAL_TEST_CASES=$(find . -path "*/internal/test_cases.json" -type f 2>/dev/null | head -1)
    fi
fi

if [ -z "$INTERNAL_TEST_CASES" ] || [ ! -f "$INTERNAL_TEST_CASES" ]; then
    print_error "Could not find internal/test_cases.json. Please ensure it exists in:"
    echo "  - $ORIGINAL_DIR/internal/test_cases.json"
    echo "  - $ORIGINAL_DIR/junior/internal/test_cases.json"
    echo "  - Or in the cloned repository"
    cleanup_and_exit 1
fi

print_info "Found internal test cases at: $INTERNAL_TEST_CASES"

# Find and update test_cases.json in project directory
print_step "Updating test_cases.json..."
TEST_CASES_FILE="$PROJECT_DIR/test_cases.json"

if [ -f "$TEST_CASES_FILE" ]; then
    cp "$INTERNAL_TEST_CASES" "$TEST_CASES_FILE"
    print_success "Updated test_cases.json with internal test cases"
else
    print_error "Could not find test_cases.json in project directory: $PROJECT_DIR"
    cleanup_and_exit 1
fi

# Change to project directory
cd "$PROJECT_DIR" || exit 1

# Install dependencies and run project based on type
if [ "$PROJECT_TYPE" = "nodejs" ]; then
    # Check if npm is installed
    if ! command -v npm &> /dev/null; then
        print_error "npm is not installed. Please install Node.js and npm first."
        cleanup_and_exit 1
    fi
    
    print_step "Installing npm dependencies..."
    if npm install; then
        print_success "Dependencies installed successfully"
    else
        print_error "Failed to install dependencies"
        cleanup_and_exit 1
    fi
    
    print_step "Running project with 'npm run start'..."
    echo ""
    npm run start
    
elif [ "$PROJECT_TYPE" = "python" ]; then
    # Check if python3 is installed
    if ! command -v python3 &> /dev/null; then
        print_error "python3 is not installed. Please install Python 3 first."
        cleanup_and_exit 1
    fi
    
    print_step "Running project with 'python3 main.py'..."
    echo ""
    python3 main.py
fi

echo ""
print_success "Script execution completed!"
print_info "The cloned repository is available at: $(pwd)"

# Return to the original directory
cd "$ORIGINAL_DIR" || cleanup_and_exit 1

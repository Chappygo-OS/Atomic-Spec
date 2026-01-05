#!/usr/bin/env bash
# Initialize a new project with Custom Speckit (Atomic Traceability Model)
#
# Usage:
#   ./init-project.sh /path/to/new/project
#   ./init-project.sh /path/to/new/project --ai claude

set -e

# Get script directory (where Custom Speckit lives)
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
TARGET_PATH=""
AI_AGENT="claude"

while [[ $# -gt 0 ]]; do
    case $1 in
        --ai)
            AI_AGENT="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 <target-path> [--ai <agent>]"
            echo ""
            echo "Arguments:"
            echo "  target-path    Path to initialize the new project"
            echo "  --ai <agent>   AI agent to use (claude, gemini, copilot, cursor, windsurf)"
            echo ""
            echo "Example:"
            echo "  $0 ~/projects/my-app --ai claude"
            exit 0
            ;;
        *)
            TARGET_PATH="$1"
            shift
            ;;
    esac
done

if [[ -z "$TARGET_PATH" ]]; then
    echo "ERROR: Target path is required"
    echo "Usage: $0 <target-path> [--ai <agent>]"
    exit 1
fi

echo "🚀 Initializing Custom Speckit (Atomic Traceability Model)"
echo "   Source: $SOURCE_DIR"
echo "   Target: $TARGET_PATH"
echo ""

# Create target directory if it doesn't exist
if [[ ! -d "$TARGET_PATH" ]]; then
    echo "📁 Creating directory: $TARGET_PATH"
    mkdir -p "$TARGET_PATH"
fi

# Initialize git if not already a repo
if [[ ! -d "$TARGET_PATH/.git" ]]; then
    echo "📦 Initializing git repository..."
    (cd "$TARGET_PATH" && git init)
fi

# Copy framework directories
for dir in ".specify" "templates" "memory" "scripts"; do
    if [[ -d "$SOURCE_DIR/$dir" ]]; then
        echo "📋 Copying $dir..."
        rm -rf "$TARGET_PATH/$dir"
        cp -r "$SOURCE_DIR/$dir" "$TARGET_PATH/$dir"
    fi
done

# Set up agent-specific commands based on selected AI agent
# For Claude: Create .claude/commands/ with speckit.* prefixed commands
# For others: Copy from existing agent directories if they exist

if [[ "$AI_AGENT" == "claude" ]]; then
    echo "🤖 Setting up Claude Code commands..."
    mkdir -p "$TARGET_PATH/.claude/commands"

    # Copy command files with speckit. prefix
    for cmd in specify plan tasks implement analyze checklist clarify constitution taskstoissues; do
        if [[ -f "$SOURCE_DIR/templates/commands/$cmd.md" ]]; then
            cp "$SOURCE_DIR/templates/commands/$cmd.md" "$TARGET_PATH/.claude/commands/speckit.$cmd.md"
        fi
    done
else
    # For other agents, copy from existing agent directories if they exist
    declare -A agent_dirs=(
        ["gemini"]=".gemini"
        ["copilot"]=".github"
        ["cursor"]=".cursor"
        ["windsurf"]=".windsurf"
    )

    agent_dir="${agent_dirs[$AI_AGENT]}"
    if [[ -n "$agent_dir" && -d "$SOURCE_DIR/$agent_dir" ]]; then
        echo "🤖 Copying $AI_AGENT agent configuration..."
        rm -rf "$TARGET_PATH/$agent_dir"
        cp -r "$SOURCE_DIR/$agent_dir" "$TARGET_PATH/$agent_dir"
    fi
fi

# Create specs directory
if [[ ! -d "$TARGET_PATH/specs" ]]; then
    echo "📁 Creating specs directory..."
    mkdir -p "$TARGET_PATH/specs"
fi

# Create a basic .gitignore if it doesn't exist
if [[ ! -f "$TARGET_PATH/.gitignore" ]]; then
    echo "📝 Creating .gitignore..."
    cat > "$TARGET_PATH/.gitignore" << 'EOF'
# Dependencies
node_modules/
vendor/
.venv/
venv/

# Build outputs
dist/
build/
*.egg-info/

# Environment
.env
.env.local
.env.*.local

# IDE
.idea/
.vscode/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Logs
*.log
logs/
EOF
fi

echo ""
echo "✅ Custom Speckit initialized successfully!"
echo ""
echo "📋 Next steps:"
echo "   1. cd \"$TARGET_PATH\""
echo "   2. git checkout -b 001-your-feature-name"
echo "   3. Run: /speckit.specify \"Your feature description\""
echo ""
echo "📚 Available commands:"
echo "   /speckit.specify  - Create feature specification"
echo "   /speckit.plan     - Create implementation plan"
echo "   /speckit.tasks    - Generate atomic task files"
echo "   /speckit.implement - Execute with Context Pinning"
echo ""

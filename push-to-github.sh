#!/bin/bash

set -e

echo "================================================"
echo "OpenLLMetry SideCar - Push to GitHub"
echo "================================================"
echo ""

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "Error: git is not installed"
    echo "Please install git: https://git-scm.com/downloads"
    exit 1
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not a git repository"
    echo ""
    read -p "Initialize git repository? [y/N]: " init_git
    
    if [[ $init_git =~ ^[Yy]$ ]]; then
        echo ""
        echo "Initializing git repository..."
        git init
        echo "✓ Git repository initialized"
        echo ""
    else
        echo "Exiting..."
        exit 1
    fi
fi

# Check for uncommitted changes
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    HAS_CHANGES=true
else
    HAS_CHANGES=false
fi

# Check for untracked files
if [ -n "$(git ls-files --others --exclude-standard)" ]; then
    HAS_UNTRACKED=true
else
    HAS_UNTRACKED=false
fi

# Show status
echo "Repository Status:"
echo "================================================"
git status --short
echo ""

if [ "$HAS_CHANGES" = false ] && [ "$HAS_UNTRACKED" = false ]; then
    echo "No changes to commit"
    echo ""
    read -p "Push to remote anyway? [y/N]: " force_push
    
    if [[ ! $force_push =~ ^[Yy]$ ]]; then
        echo "Exiting..."
        exit 0
    fi
else
    # Stage changes
    echo "Files to be committed:"
    echo "================================================"
    
    if [ "$HAS_CHANGES" = true ]; then
        echo ""
        echo "Modified files:"
        git diff --name-only
    fi
    
    if [ "$HAS_UNTRACKED" = true ]; then
        echo ""
        echo "Untracked files:"
        git ls-files --others --exclude-standard
    fi
    
    echo ""
    read -p "Stage all changes? [Y/n]: " stage_all
    
    if [[ ! $stage_all =~ ^[Nn]$ ]]; then
        echo ""
        echo "Staging all changes..."
        git add .
        echo "✓ Changes staged"
    else
        echo ""
        echo "Please stage your changes manually with:"
        echo "  git add <files>"
        exit 0
    fi
    
    # Commit changes
    echo ""
    echo "Commit Message:"
    echo "================================================"
    echo ""
    echo "Enter commit message (or press Enter for default):"
    read -p "> " commit_message
    
    if [ -z "$commit_message" ]; then
        commit_message="Update OpenLLMetry SideCar project

- Updated documentation with deployment guide
- Added mermaid diagrams for architecture and flows
- Added utility scripts for deployment management"
    fi
    
    echo ""
    echo "Committing changes..."
    git commit -m "$commit_message"
    echo "✓ Changes committed"
fi

# Check for remote
echo ""
echo "Checking remote repository..."
if ! git remote get-url origin > /dev/null 2>&1; then
    echo ""
    echo "No remote repository configured"
    echo ""
    read -p "Enter GitHub repository URL (e.g., https://github.com/user/repo.git): " remote_url
    
    if [ -z "$remote_url" ]; then
        echo "Error: No remote URL provided"
        exit 1
    fi
    
    echo ""
    echo "Adding remote repository..."
    git remote add origin "$remote_url"
    echo "✓ Remote repository added"
else
    REMOTE_URL=$(git remote get-url origin)
    echo "✓ Remote repository: $REMOTE_URL"
fi

# Get current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "✓ Current branch: $CURRENT_BRANCH"

# Check if branch exists on remote
echo ""
echo "Checking remote branch..."
if git ls-remote --exit-code --heads origin "$CURRENT_BRANCH" > /dev/null 2>&1; then
    echo "✓ Branch exists on remote"
    BRANCH_EXISTS=true
else
    echo "! Branch does not exist on remote (will be created)"
    BRANCH_EXISTS=false
fi

# Push to remote
echo ""
echo "================================================"
echo "Ready to push to GitHub"
echo "================================================"
echo ""
echo "Remote:  $(git remote get-url origin)"
echo "Branch:  $CURRENT_BRANCH"
echo ""

if [ "$BRANCH_EXISTS" = true ]; then
    read -p "Push changes? [Y/n]: " do_push
else
    read -p "Create and push new branch? [Y/n]: " do_push
fi

if [[ $do_push =~ ^[Nn]$ ]]; then
    echo "Push cancelled"
    exit 0
fi

echo ""
echo "Pushing to GitHub..."

if [ "$BRANCH_EXISTS" = true ]; then
    # Regular push
    if git push origin "$CURRENT_BRANCH"; then
        echo ""
        echo "✓ Successfully pushed to GitHub"
    else
        echo ""
        echo "Push failed. You may need to pull changes first:"
        echo "  git pull origin $CURRENT_BRANCH"
        echo ""
        read -p "Force push? (WARNING: This will overwrite remote changes) [y/N]: " force_push
        
        if [[ $force_push =~ ^[Yy]$ ]]; then
            echo ""
            echo "Force pushing..."
            git push --force origin "$CURRENT_BRANCH"
            echo "✓ Force pushed to GitHub"
        else
            echo "Push cancelled"
            exit 1
        fi
    fi
else
    # First push of new branch
    git push -u origin "$CURRENT_BRANCH"
    echo ""
    echo "✓ Successfully pushed new branch to GitHub"
fi

echo ""
echo "================================================"
echo "Push Complete!"
echo "================================================"
echo ""
echo "View your repository at:"
echo "  $(git remote get-url origin | sed 's/\.git$//')"
echo ""
echo "Recent commits:"
git log --oneline -5
echo ""

# Made with Bob

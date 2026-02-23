#!/bin/bash

# ✅ Check and display current working directory
echo "📂 Current working directory: $(pwd)"

# Check if inside a git repo
if [ ! -d .git ]; then
  echo "❌ Not inside a Git repository."
  exit 1
fi

# Prompt for commit message if not provided
if [ -z "$1" ]; then
  read -p "Enter commit message: " COMMIT_MESSAGE
else
  COMMIT_MESSAGE="$1"
fi

# Use provided branch or current branch
if [ -z "$2" ]; then
  BRANCH=$(git rev-parse --abbrev-ref HEAD)
else
  BRANCH="$2"
  # Create the branch locally if it doesn't exist
  if ! git rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
    git checkout -b "$BRANCH"
  else
    git checkout "$BRANCH"
  fi
fi

git add .
git commit -m "$COMMIT_MESSAGE"
git push origin "$BRANCH"
echo "✅ Changes committed and pushed to branch '$BRANCH'."
#!/usr/bin/env bash

# create-project-tag.sh
# Generic helper to create an annotated Git tag and (optionally) a GitHub/GitLab Release
# Usage:
#   create-project-tag.sh [--dry-run] [--no-release] \
#     --project <path> [--branch <branch>] --tag <tag> --notes <file> [--title <title>]
# Short flags: -p, -b, -t, -n

set -euo pipefail

# Colors and icons for nice output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
SUCCESS_ICON="✅"
ERROR_ICON="❌"
WARNING_ICON="⚠️"
INFO_ICON="ℹ️"

print_success() { echo -e "${GREEN}${SUCCESS_ICON} $1${NC}"; }
print_error()   { echo -e "${RED}${ERROR_ICON} $1${NC}"; }
print_warning() { echo -e "${YELLOW}${WARNING_ICON} $1${NC}"; }
print_info()    { echo -e "${BLUE}${INFO_ICON} $1${NC}"; }

usage() {
  cat <<EOF
Usage: $0 [--dry-run] [--no-release] [--provider <github|gitlab>] [--gitlab] \
  --project <path> [--branch <branch>] --tag <tag> --notes <file> [--title <title>]

Options:
  -p, --project     Path to the git repository (defaults to current directory if omitted)
  -b, --branch      Branch name to tag (default: current HEAD)
  -t, --tag         Tag name to create (e.g., v1.2.3)
  -n, --notes       Path to a text file with release/tag notes
      --title       Optional Release title (defaults to tag or first line of notes)
      --dry-run     Preview actions without making changes
      --no-release  Skip creating a Release (only create and push tag)
      --provider    Release provider: 'github' (default) or 'gitlab'
      --gitlab      Shortcut for --provider gitlab
  -h, --help        Show this help
EOF
}

PROJECT_DIR=""
BRANCH_NAME=""
TAG_NAME=""
NOTES_FILE=""
RELEASE_TITLE=""
DRY_RUN=false
CREATE_RELEASE=true
PROVIDER="github"
TARGET_COMMIT=""

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--project)
      if [[ -z "${2-}" || "${2-}" == -* ]]; then print_error "Option $1 requires a value"; usage; exit 1; fi
      PROJECT_DIR="$2"; shift 2;;
    -b|--branch)
      if [[ -z "${2-}" || "${2-}" == -* ]]; then print_error "Option $1 requires a value"; usage; exit 1; fi
      BRANCH_NAME="$2"; shift 2;;
    -t|--tag)
      if [[ -z "${2-}" || "${2-}" == -* ]]; then print_error "Option $1 requires a value"; usage; exit 1; fi
      TAG_NAME="$2"; shift 2;;
    -n|--notes)
      if [[ -z "${2-}" || "${2-}" == -* ]]; then print_error "Option $1 requires a value"; usage; exit 1; fi
      NOTES_FILE="$2"; shift 2;;
    --title)
      if [[ -z "${2-}" || "${2-}" == -* ]]; then print_error "Option $1 requires a value"; usage; exit 1; fi
      RELEASE_TITLE="$2"; shift 2;;
    --provider)
      if [[ -z "${2-}" || "${2-}" == -* ]]; then print_error "Option $1 requires a value"; usage; exit 1; fi
      PROVIDER="$2"; shift 2;;
    --gitlab)
      PROVIDER="gitlab"; shift;;
    --dry-run)
      DRY_RUN=true; shift;;
    --no-release)
      CREATE_RELEASE=false; shift;;
    -h|--help)
      usage; exit 0;;
    *)
      print_error "Unknown argument: $1"; usage; exit 1;;
  esac
done

# Normalise provider
case "${PROVIDER}" in
  github|gitlab) ;;
  *) print_error "Invalid provider '${PROVIDER}'. Use 'github' or 'gitlab'."; exit 1;;
esac

# Defaults
if [[ -z "${PROJECT_DIR}" ]]; then
  PROJECT_DIR="$(pwd)"
fi

# Validate required
if [[ -z "${TAG_NAME}" || -z "${NOTES_FILE}" ]]; then
  print_error "Missing required options."
  usage
  exit 1
fi

print_info "Project: ${PROJECT_DIR}"
print_info "Tag: ${TAG_NAME}"
print_info "Notes file: ${NOTES_FILE}"
print_info "Release provider: ${PROVIDER}"
print_info "Release: $([[ "$CREATE_RELEASE" == true ]] && echo "enabled" || echo "disabled")"
$DRY_RUN && print_warning "DRY RUN MODE: No changes will be made"

# Check directory exists and is a git repo
if [[ ! -d "${PROJECT_DIR}" ]]; then
  print_error "Project directory '${PROJECT_DIR}' does not exist!"; exit 1
fi

cd "${PROJECT_DIR}" || { print_error "Failed to enter '${PROJECT_DIR}'"; exit 1; }

if [[ ! -d .git ]]; then
  print_error "'${PROJECT_DIR}' is not a git repository!"; exit 1
fi

# Ensure remote 'origin' exists
if ! git remote get-url origin >/dev/null 2>&1; then
  print_error "No 'origin' remote configured for this repo."; exit 1
fi

# Determine owner/repo from origin URL (works for SSH and HTTPS)
ORIGIN_URL="$(git remote get-url origin)"
REMOTE_HOST=""
REMOTE_PATH=""
if [[ "$ORIGIN_URL" =~ ^git@([^:]+):(.+)$ ]]; then
  REMOTE_HOST="${BASH_REMATCH[1]}"
  REMOTE_PATH="${BASH_REMATCH[2]}"
elif [[ "$ORIGIN_URL" =~ ^https?://([^/]+)/(.+)$ ]]; then
  REMOTE_HOST="${BASH_REMATCH[1]}"
  REMOTE_PATH="${BASH_REMATCH[2]}"
else
  print_warning "Could not parse remote URL: ${ORIGIN_URL}"
fi
OWNER_REPO="${REMOTE_PATH%.git}"

# Resolve target commit from branch (if provided) or use HEAD
TARGET_COMMIT="HEAD"
TARGET_DESC="HEAD"
if [[ -n "${BRANCH_NAME}" ]]; then
  if git show-ref --verify --quiet "refs/heads/${BRANCH_NAME}"; then
    TARGET_COMMIT="$(git rev-parse "${BRANCH_NAME}")"
    TARGET_DESC="branch ${BRANCH_NAME}"
  elif git show-ref --verify --quiet "refs/remotes/origin/${BRANCH_NAME}"; then
    TARGET_COMMIT="$(git rev-parse "origin/${BRANCH_NAME}")"
    TARGET_DESC="origin/${BRANCH_NAME}"
  else
    print_info "Fetching branch '${BRANCH_NAME}' from origin (if it exists)..."
    if git fetch --quiet origin "${BRANCH_NAME}" 2>/dev/null; then
      if git show-ref --verify --quiet "refs/remotes/origin/${BRANCH_NAME}"; then
        TARGET_COMMIT="$(git rev-parse "origin/${BRANCH_NAME}")"
        TARGET_DESC="origin/${BRANCH_NAME}"
      else
        print_error "Branch '${BRANCH_NAME}' not found locally or on origin"; exit 1
      fi
    else
      print_error "Failed to fetch branch '${BRANCH_NAME}' from origin"; exit 1
    fi
  fi
else
  TARGET_COMMIT="$(git rev-parse HEAD)"
  CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'detached')"
  if [[ "${CURRENT_BRANCH}" == "HEAD" || "${CURRENT_BRANCH}" == "detached" ]]; then
    TARGET_DESC="detached HEAD"
  else
    TARGET_DESC="branch ${CURRENT_BRANCH}"
  fi
fi

print_info "Target: ${TARGET_DESC} @ $(git rev-parse --short "${TARGET_COMMIT}")"

# Notes file checks
if [[ ! -f "${NOTES_FILE}" ]]; then
  print_error "Notes file '${NOTES_FILE}' does not exist!"; exit 1
fi
if [[ ! -r "${NOTES_FILE}" ]]; then
  print_error "Notes file '${NOTES_FILE}' is not readable!"; exit 1
fi
if [[ ! -s "${NOTES_FILE}" ]]; then
  print_error "Notes file '${NOTES_FILE}' is empty!"; exit 1
fi

# Try to ensure it's text
if command -v file >/dev/null 2>&1; then
  if ! file "${NOTES_FILE}" | grep -qi "text"; then
    print_warning "Notes file does not appear to be text; continuing anyway."
  fi
fi

# Clean working tree check (warn if dirty)
if ! git diff-index --quiet HEAD --; then
  print_warning "Working tree has uncommitted changes. Tagging selected commit anyway."
fi

# Check tag existence locally and remotely (do not exit; make idempotent)
TAG_EXISTS_LOCAL=false
TAG_EXISTS_REMOTE=false
if git rev-parse -q --verify "refs/tags/${TAG_NAME}" >/dev/null; then
  TAG_EXISTS_LOCAL=true
fi
if git ls-remote --tags origin | grep -q "refs/tags/${TAG_NAME}$"; then
  TAG_EXISTS_REMOTE=true
fi

if [[ "${TAG_EXISTS_LOCAL}" == true ]]; then
  print_warning "Tag '${TAG_NAME}' already exists locally; will not re-create."
fi
if [[ "${TAG_EXISTS_REMOTE}" == true ]]; then
  print_warning "Tag '${TAG_NAME}' already exists on remote; will not push."
fi

# Determine default title
if [[ -z "${RELEASE_TITLE}" ]]; then
  RELEASE_TITLE="${TAG_NAME}"
  # If notes first line is non-empty, use it
  FIRST_LINE="$(head -n1 "${NOTES_FILE}" | tr -d '\r')"
  if [[ -n "${FIRST_LINE}" ]]; then
    RELEASE_TITLE="${FIRST_LINE}"
  fi
fi

# Show preview of notes in dry-run
if [[ "${DRY_RUN}" == true ]]; then
  print_info "Notes preview:"
  echo -e "${BLUE}┌─────────────────────────────────────────────────────────────${NC}"
  while IFS= read -r line; do
    echo -e "${BLUE}│${NC} $line"
  done < "${NOTES_FILE}"
  echo -e "${BLUE}└─────────────────────────────────────────────────────────────${NC}"
fi

if [[ "${DRY_RUN}" == true ]]; then
  if [[ "${TAG_EXISTS_LOCAL}" == false ]]; then
    print_warning "DRY RUN: Would run -> git tag -a '${TAG_NAME}' '${TARGET_COMMIT}' -F '${NOTES_FILE}'"
  else
    print_info "Skipping tag creation (exists locally)"
  fi
  if [[ "${TAG_EXISTS_REMOTE}" == false ]]; then
    print_warning "DRY RUN: Would run -> git push origin 'refs/tags/${TAG_NAME}'"
  else
    print_info "Skipping push (exists on remote)"
  fi
else
  if [[ "${TAG_EXISTS_LOCAL}" == false ]]; then
    print_info "Creating annotated tag '${TAG_NAME}' on $(git rev-parse --short "${TARGET_COMMIT}")"
    if git tag -a "${TAG_NAME}" "${TARGET_COMMIT}" -F "${NOTES_FILE}"; then
      print_success "Created tag '${TAG_NAME}'"
    else
      print_error "Failed to create tag '${TAG_NAME}'"; exit 1
    fi
  else
    print_info "Tag exists locally; skipping creation"
  fi

  if [[ "${TAG_EXISTS_REMOTE}" == false ]]; then
    if git push origin "refs/tags/${TAG_NAME}"; then
      print_success "Pushed tag '${TAG_NAME}' to origin"
    else
      print_error "Failed to push tag '${TAG_NAME}' to origin"; exit 1
    fi
  else
    print_info "Tag exists on origin; skipping push"
  fi
fi

# Create Release (optional)
if [[ "${CREATE_RELEASE}" == true ]]; then
  case "${PROVIDER}" in
    github)
      if ! command -v gh >/dev/null 2>&1; then
        print_warning "'gh' CLI not found; skipping GitHub Release."
        exit 0
      fi
      if ! gh auth status >/dev/null 2>&1; then
        print_warning "'gh' not authenticated; run 'gh auth login' and create the release manually or re-run."
        exit 0
      fi
print_info "Creating GitHub Release '${TAG_NAME}' (title: '${RELEASE_TITLE}')"
      if [[ "${DRY_RUN}" == true ]]; then
        print_warning "DRY RUN: Would run -> gh release create '${TAG_NAME}' -F '${NOTES_FILE}' --title '${RELEASE_TITLE}' --verify-tag -R '${OWNER_REPO}'"
      else
        if gh release create "${TAG_NAME}" -F "${NOTES_FILE}" --title "${RELEASE_TITLE}" --verify-tag -R "${OWNER_REPO}"; then
          print_success "GitHub Release '${TAG_NAME}' created"
        else
          print_warning "Failed to create GitHub Release. The tag was pushed successfully; create the release manually if needed."
        fi
      fi
      ;;
    gitlab)
      if ! command -v glab >/dev/null 2>&1; then
        print_warning "'glab' CLI not found; skipping GitLab Release."
        exit 0
      fi
      if ! glab auth status >/dev/null 2>&1; then
        print_warning "'glab' not authenticated; run 'glab auth login' and create the release manually or re-run."
        exit 0
      fi
print_info "Creating GitLab Release '${TAG_NAME}' (title: '${RELEASE_TITLE}')"
      if [[ "${DRY_RUN}" == true ]]; then
        print_warning "DRY RUN: Would run -> glab release create '${TAG_NAME}' --notes-file '${NOTES_FILE}' --name '${RELEASE_TITLE}' -R '${OWNER_REPO}'"
      else
        if glab release create "${TAG_NAME}" --notes-file "${NOTES_FILE}" --name "${RELEASE_TITLE}" -R "${OWNER_REPO}"; then
          print_success "GitLab Release '${TAG_NAME}' created"
        else
          print_warning "Failed to create GitLab Release. The tag was pushed successfully; create the release manually if needed."
        fi
      fi
      ;;
    *)
      print_error "Unknown provider '${PROVIDER}'"; exit 1;;
  esac
else
  print_info "Skipping Release creation (per --no-release)"
fi

print_success "Done."

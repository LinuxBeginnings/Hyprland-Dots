#!/usr/bin/env bash
# ==================================================
# create-project-tag.sh
# Generic helper to create an annotated Git tag and (optionally) a GitHub/GitLab Release
#
# Usage:
#   create-project-tag.sh [--dry-run] [--no-release] [--provider <github|gitlab>] \
#     --project <path> [--branch <branch>] --tag <tag> --notes <file> [--title <title>]
# ==================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Output Styling, Colors & Icons (TTY and NO_COLOR aware)
# ------------------------------------------------------------------------------
setup_colors() {
  if [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-}" != "dumb" ]]; then
    C_RED=$'\e[0;31m'
    C_GREEN=$'\e[0;32m'
    C_YELLOW=$'\e[1;33m'
    C_BLUE=$'\e[0;34m'
    C_CYAN=$'\e[0;36m'
    C_BOLD=$'\e[1m'
    C_DIM=$'\e[2m'
    C_RESET=$'\e[0m'
    ICON_SUCCESS="✅"
    ICON_ERROR="❌"
    ICON_WARN="⚠️ "
    ICON_INFO="ℹ️ "
    ICON_TAG="🏷️ "
  else
    C_RED=''
    C_GREEN=''
    C_YELLOW=''
    C_BLUE=''
    C_CYAN=''
    C_BOLD=''
    C_DIM=''
    C_RESET=''
    ICON_SUCCESS="[OK]"
    ICON_ERROR="[ERROR]"
    ICON_WARN="[WARN]"
    ICON_INFO="[INFO]"
    ICON_TAG="[TAG]"
  fi
}
setup_colors

log_info()    { printf "%b %s\n" "${C_BLUE}${ICON_INFO}${C_RESET}" "$*"; }
log_success() { printf "%b %s\n" "${C_GREEN}${ICON_SUCCESS}${C_RESET}" "$*"; }
log_warn()    { printf "%b %s\n" "${C_YELLOW}${ICON_WARN}${C_RESET}" "$*"; }
log_error()   { printf "%b %s\n" "${C_RED}${ICON_ERROR}${C_RESET}" "$*" >&2; }
log_step()    { printf "%b %s\n" "${C_CYAN}${ICON_TAG}${C_RESET}" "$*"; }

# ------------------------------------------------------------------------------
# Help & Usage
# ------------------------------------------------------------------------------
usage() {
  cat <<EOF
${C_BOLD}Usage:${C_RESET}
  $0 [options] --tag <tag> --notes <file>

${C_BOLD}Options:${C_RESET}
  -p, --project <dir>    Path to repository (default: current directory)
  -b, --branch <branch>  Branch or ref to tag (default: current HEAD)
  -t, --tag <tag>        Tag name to create (e.g. v1.2.3) [Required]
  -n, --notes <file>     Path to text/markdown release notes [Required]
      --title <title>    Release title (default: extracted from notes or tag)
      --dry-run          Preview actions without committing or pushing
      --no-release       Skip GitHub/GitLab release creation (tag only)
      --provider <name>  Release forge: 'github' (default) or 'gitlab'
      --gitlab           Shortcut for --provider gitlab
  -h, --help             Show this help message
EOF
}

# ------------------------------------------------------------------------------
# Argument Parsing
# ------------------------------------------------------------------------------
PROJECT_DIR=""
BRANCH_NAME=""
TAG_NAME=""
NOTES_FILE=""
RELEASE_TITLE=""
DRY_RUN=false
CREATE_RELEASE=true
PROVIDER="github"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -p|--project)
      [[ -z "${2-}" || "${2-}" == -* ]] && { log_error "Option $1 requires a path"; usage; exit 1; }
      PROJECT_DIR="$2"; shift 2;;
    -b|--branch)
      [[ -z "${2-}" || "${2-}" == -* ]] && { log_error "Option $1 requires a branch name"; usage; exit 1; }
      BRANCH_NAME="$2"; shift 2;;
    -t|--tag)
      [[ -z "${2-}" || "${2-}" == -* ]] && { log_error "Option $1 requires a tag name"; usage; exit 1; }
      TAG_NAME="$2"; shift 2;;
    -n|--notes)
      [[ -z "${2-}" || "${2-}" == -* ]] && { log_error "Option $1 requires a file path"; usage; exit 1; }
      NOTES_FILE="$2"; shift 2;;
    --title)
      [[ -z "${2-}" || "${2-}" == -* ]] && { log_error "Option $1 requires a title"; usage; exit 1; }
      RELEASE_TITLE="$2"; shift 2;;
    --provider)
      [[ -z "${2-}" || "${2-}" == -* ]] && { log_error "Option $1 requires a provider ('github' or 'gitlab')"; usage; exit 1; }
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
      log_error "Unknown argument: $1"; usage; exit 1;;
  esac
done

case "${PROVIDER}" in
  github|gitlab) ;;
  *) log_error "Invalid provider '${PROVIDER}'. Allowed: 'github', 'gitlab'"; exit 1;;
esac

# ------------------------------------------------------------------------------
# Path Normalization & Pre-flight Checks (BEFORE cd)
# ------------------------------------------------------------------------------
if [[ -z "${TAG_NAME}" || -z "${NOTES_FILE}" ]]; then
  log_error "Missing required options: --tag and --notes are required."
  usage
  exit 1
fi

# Resolve NOTES_FILE to absolute path before changing directory
if [[ ! -f "${NOTES_FILE}" ]]; then
  log_error "Notes file '${NOTES_FILE}' does not exist!"
  exit 1
fi
if [[ ! -r "${NOTES_FILE}" ]]; then
  log_error "Notes file '${NOTES_FILE}' is not readable!"
  exit 1
fi
if [[ ! -s "${NOTES_FILE}" ]]; then
  log_error "Notes file '${NOTES_FILE}' is empty!"
  exit 1
fi

if command -v realpath >/dev/null 2>&1; then
  NOTES_FILE="$(realpath "${NOTES_FILE}")"
else
  NOTES_FILE="$(cd "$(dirname "${NOTES_FILE}")" && pwd)/$(basename "${NOTES_FILE}")"
fi

# Resolve project directory
PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
if [[ ! -d "${PROJECT_DIR}" ]]; then
  log_error "Project directory '${PROJECT_DIR}' does not exist!"
  exit 1
fi

cd "${PROJECT_DIR}" || { log_error "Failed to enter '${PROJECT_DIR}'"; exit 1; }

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  log_error "'${PROJECT_DIR}' is not a valid Git repository worktree!"
  exit 1
fi

# ------------------------------------------------------------------------------
# Git Context & Remote Resolution
# ------------------------------------------------------------------------------
if ! git remote get-url origin >/dev/null 2>&1; then
  log_error "No 'origin' remote configured in this repository."
  exit 1
fi

ORIGIN_URL="$(git remote get-url origin)"
OWNER_REPO=""

# Robust URL parsing: handles git@, ssh://git@, and https://
if [[ "$ORIGIN_URL" =~ ^(https?|ssh)://([^@]+@)?([^/:]+)(:[0-9]+)?/(.+)$ ]]; then
  REMOTE_PATH="${BASH_REMATCH[5]}"
  OWNER_REPO="${REMOTE_PATH%.git}"
elif [[ "$ORIGIN_URL" =~ ^git@([^:]+):(.+)$ ]]; then
  REMOTE_PATH="${BASH_REMATCH[2]}"
  OWNER_REPO="${REMOTE_PATH%.git}"
fi
# Strip any trailing slashes
OWNER_REPO="${OWNER_REPO%/}"

# Target commit resolution
TARGET_COMMIT="HEAD"
TARGET_DESC="HEAD"

if [[ -n "${BRANCH_NAME}" ]]; then
  if git show-ref --verify --quiet "refs/heads/${BRANCH_NAME}"; then
    TARGET_COMMIT="$(git rev-parse "${BRANCH_NAME}")"
    TARGET_DESC="local branch '${BRANCH_NAME}'"
  elif git show-ref --verify --quiet "refs/remotes/origin/${BRANCH_NAME}"; then
    TARGET_COMMIT="$(git rev-parse "origin/${BRANCH_NAME}")"
    TARGET_DESC="origin/${BRANCH_NAME}"
  else
    log_info "Branch '${BRANCH_NAME}' not local; fetching from origin..."
    if git fetch --quiet origin "${BRANCH_NAME}" 2>/dev/null && \
       git show-ref --verify --quiet "refs/remotes/origin/${BRANCH_NAME}"; then
      TARGET_COMMIT="$(git rev-parse "origin/${BRANCH_NAME}")"
      TARGET_DESC="origin/${BRANCH_NAME}"
    else
      log_error "Branch '${BRANCH_NAME}' not found locally or on origin."
      exit 1
    fi
  fi
else
  TARGET_COMMIT="$(git rev-parse HEAD)"
  CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'detached')"
  if [[ "${CURRENT_BRANCH}" == "HEAD" || "${CURRENT_BRANCH}" == "detached" ]]; then
    TARGET_DESC="detached HEAD"
  else
    TARGET_DESC="branch '${CURRENT_BRANCH}'"
  fi
fi

TARGET_SHORT="$(git rev-parse --short "${TARGET_COMMIT}")"

# Derive release title if omitted (strip markdown headers like '#')
if [[ -z "${RELEASE_TITLE}" ]]; then
  FIRST_NON_EMPTY="$(grep -v '^[[:space:]]*$' "${NOTES_FILE}" | head -n1 | tr -d '\r' || true)"
  # Clean leading markdown headers (#, ##), bullets, and spaces
  CLEAN_TITLE="$(printf '%s' "${FIRST_NON_EMPTY}" | sed -E 's/^[#* -]+//; s/[[:space:]]+$//')"
  RELEASE_TITLE="${CLEAN_TITLE:-$TAG_NAME}"
fi

# ------------------------------------------------------------------------------
# Banner & Pre-Flight Information
# ------------------------------------------------------------------------------
printf "\n%b%s%b\n" "${C_BOLD}" "── Release & Tag Workflow ──" "${C_RESET}"
log_info "Repository:    ${C_BOLD}${PROJECT_DIR}${C_RESET} (${OWNER_REPO:-unparsed})"
log_info "Target Ref:    ${TARGET_DESC} @ ${C_CYAN}${TARGET_SHORT}${C_RESET}"
log_info "Tag Name:      ${C_BOLD}${TAG_NAME}${C_RESET}"
log_info "Release Title: ${RELEASE_TITLE}"
log_info "Forge Release: $([[ "$CREATE_RELEASE" == true ]] && printf '%s (%s)' 'enabled' "$PROVIDER" || printf '%s' 'disabled')"

if [[ "$DRY_RUN" == true ]]; then
  log_warn "DRY RUN MODE ENABLED: No tags will be created or pushed."
fi

# Warn on uncommitted changes
if ! git diff-index --quiet HEAD --; then
  log_warn "Working tree has uncommitted modifications. Tagging commit ${TARGET_SHORT} anyway."
fi

# ------------------------------------------------------------------------------
# Tag Existence Checks (Fast remote probe)
# ------------------------------------------------------------------------------
TAG_EXISTS_LOCAL=false
TAG_EXISTS_REMOTE=false

if git rev-parse -q --verify "refs/tags/${TAG_NAME}" >/dev/null; then
  TAG_EXISTS_LOCAL=true
  log_warn "Tag '${TAG_NAME}' already exists locally."
fi

# Fast exact remote lookup without fetching all refs
if git ls-remote --exit-code origin "refs/tags/${TAG_NAME}" >/dev/null 2>&1; then
  TAG_EXISTS_REMOTE=true
  log_warn "Tag '${TAG_NAME}' already exists on remote 'origin'."
fi

# Show notes preview in dry-run
if [[ "${DRY_RUN}" == true ]]; then
  printf "\n%b%s%b\n" "${C_DIM}" "── Notes Preview ──" "${C_RESET}"
  sed "s/^/${C_BLUE}│${C_RESET} /" "${NOTES_FILE}"
  printf "%b%s%b\n\n" "${C_DIM}" "───────────────────" "${C_RESET}"
fi

# ------------------------------------------------------------------------------
# Tag Execution & Push
# ------------------------------------------------------------------------------
if [[ "${DRY_RUN}" == true ]]; then
  if [[ "${TAG_EXISTS_LOCAL}" == false ]]; then
    log_info "Would run: git tag -a '${TAG_NAME}' '${TARGET_COMMIT}' -F '${NOTES_FILE}'"
  fi
  if [[ "${TAG_EXISTS_REMOTE}" == false ]]; then
    log_info "Would run: git push origin 'refs/tags/${TAG_NAME}'"
  fi
else
  # Create local tag
  if [[ "${TAG_EXISTS_LOCAL}" == false ]]; then
    log_step "Creating annotated tag '${TAG_NAME}' on ${TARGET_SHORT}..."
    if git tag -a "${TAG_NAME}" "${TARGET_COMMIT}" -F "${NOTES_FILE}"; then
      log_success "Created local tag '${TAG_NAME}'"
    else
      log_error "Failed to create annotated tag '${TAG_NAME}'"
      exit 1
    fi
  else
    log_info "Tag exists locally; skipping tag creation."
  fi

  # Push tag
  if [[ "${TAG_EXISTS_REMOTE}" == false ]]; then
    log_step "Pushing tag '${TAG_NAME}' to remote 'origin'..."
    if git push origin "refs/tags/${TAG_NAME}"; then
      log_success "Pushed tag '${TAG_NAME}' to origin"
    else
      log_error "Failed to push tag '${TAG_NAME}' to origin"
      exit 1
    fi
  else
    log_info "Tag exists on origin; skipping push."
  fi
fi

# ------------------------------------------------------------------------------
# Release Creation (GitHub / GitLab)
# ------------------------------------------------------------------------------
RELEASE_URL=""

if [[ "${CREATE_RELEASE}" == true ]]; then
  case "${PROVIDER}" in
    github)
      if ! command -v gh >/dev/null 2>&1; then
        log_warn "'gh' CLI is not installed. Skipped GitHub Release creation."
      elif ! gh auth status >/dev/null 2>&1; then
        log_warn "'gh' is not authenticated. Run 'gh auth login' to create release."
      else
        GH_ARGS=("${TAG_NAME}" -F "${NOTES_FILE}" --title "${RELEASE_TITLE}" --verify-tag)
        [[ -n "${OWNER_REPO}" ]] && GH_ARGS+=(-R "${OWNER_REPO}")

        if [[ "${DRY_RUN}" == true ]]; then
          log_info "Would run: gh release create ${GH_ARGS[*]}"
        else
          log_step "Creating GitHub release '${TAG_NAME}'..."
          if RELEASE_URL=$(gh release create "${GH_ARGS[@]}"); then
            log_success "GitHub Release created successfully!"
          else
            log_warn "Failed to create GitHub Release. Tag was pushed successfully."
          fi
        fi
      fi
      ;;

    gitlab)
      if ! command -v glab >/dev/null 2>&1; then
        log_warn "'glab' CLI is not installed. Skipped GitLab Release creation."
      elif ! glab auth status >/dev/null 2>&1; then
        log_warn "'glab' is not authenticated. Run 'glab auth login' to create release."
      else
        GLAB_ARGS=("${TAG_NAME}" --notes-file "${NOTES_FILE}" --name "${RELEASE_TITLE}")
        [[ -n "${OWNER_REPO}" ]] && GLAB_ARGS+=(-R "${OWNER_REPO}")

        if [[ "${DRY_RUN}" == true ]]; then
          log_info "Would run: glab release create ${GLAB_ARGS[*]}"
        else
          log_step "Creating GitLab release '${TAG_NAME}'..."
          if RELEASE_URL=$(glab release create "${GLAB_ARGS[@]}"); then
            log_success "GitLab Release created successfully!"
          else
            log_warn "Failed to create GitLab Release. Tag was pushed successfully."
          fi
        fi
      fi
      ;;
  esac
fi

# ------------------------------------------------------------------------------
# Summary Output
# ------------------------------------------------------------------------------
printf "\n%b%s%b\n" "${C_GREEN}${C_BOLD}" "🎉 Release Workflow Complete" "${C_RESET}"
printf "  • Tag:     %b%s%b (%s)\n" "${C_BOLD}" "${TAG_NAME}" "${C_RESET}" "${TARGET_SHORT}"
if [[ -n "${RELEASE_URL}" ]]; then
  printf "  • Release: %b%s%b\n" "${C_CYAN}" "${RELEASE_URL}" "${C_RESET}"
fi
printf "\n"

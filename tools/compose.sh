#!/bin/bash
# Composes a stack for a given environment

shopt -s nullglob # Enable nullglob option

help() {
  # Display help
  echo "Syntax: ./compose.sh [environment].[stack].[item] [action]"
  echo
  echo "Examples:"
  echo "./compose.sh prod up"
  echo "./compose.sh prod.blogging up"
  echo "./compose.sh prod.blogging.ghost up"
}

log() {
  # logs colorful messages

  local level="$1"
  local message="$2"
  local color_code
  local color_reset="\033[0m"
  local tabs=""

  case "$level" in
  "error")
    color_code="\033[91;1m" # Bright Red color
    ;;
  "warn")
    color_code="\033[93;1m" # Bright Yellow color
    ;;
  "info")
    color_code="\033[92;1m" # Bright Green color
    ;;
  "debug")
    color_code="\033[96;1m" # Bright Cyan color
    ;;
  "trace")
    color_code="\033[94;1m" # Bright Blue color
    ;;
  *)
    color_code="\033[91;1m"
    echo -e "${color_code}\033[1mCOMPOSE.sh [ERROR]${color_reset}${color_code}${tabs} Invalid log level: ${level}${color_reset}"
    exit 1
    ;;
  esac

  local prefix=$(echo "$level" | tr '[:lower:]' '[:upper:]')

  # Calculate tabs based on the length of the prefix
  local prefix_length=${#prefix}
  local max_tabs=2
  local total_tabs=$((max_tabs - (prefix_length / 4)))

  # Add tabs to align the messages
  for ((i = 0; i < total_tabs; i++)); do
    tabs+="\t"
  done

  local log_level=${LOG_LEVEL:-info}

  case "$log_level" in
  "error")
    if [ "$level" != "error" ]; then
      return
    fi
    ;;
  "warn")
    if [ "$level" != "error" ] && [ "$level" != "warn" ]; then
      return
    fi
    ;;
  "info")
    if [ "$level" != "error" ] && [ "$level" != "warn" ] && [ "$level" != "info" ]; then
      return
    fi
    ;;
  "debug")
    if [ "$level" != "error" ] && [ "$level" != "warn" ] && [ "$level" != "info" ] && [ "$level" != "debug" ]; then
      return
    fi
    ;;
  "trace")
    # Log all levels in trace mode
    ;;
  *)
    color_code="\033[91;1m"
    echo -e "${color_code}\033[1mCOMPOSE.sh [ERROR]${color_reset}${color_code}${tabs} Invalid log level: ${log_level}${color_reset}"
    exit 1
    ;;
  esac

  echo -e "${color_code}\033[1mCOMPOSE.sh [${prefix}]${color_reset}${color_code}${tabs} ${message}${color_reset}"
}

check_arguments() {
  # validates for correct arguments
  log "trace" "Starting check_arguments()..."
  log "trace" "Argument 1=$1"
  log "trace" "Argument 2=$2"

  if [ -z "$2" ]; then
    log "error" "Action not supplied (ex. up, down, etc)"
    help
    exit 1
  else
    TARGET_ACTION=$2
  fi

  IFS='.' read -r TARGET_ENVIRONMENT TARGET_STACK TARGET_ITEM <<<"$1"

  if [ -z "$TARGET_ENVIRONMENT" ]; then
    log "error" "Environment not supplied (ex. prod, dev)"
    help
    exit 1
  fi

  if [ -z "$TARGET_STACK" ] && [ ! -z "$TARGET_ITEM" ]; then
    log "error" "Must supply stack when supplying item"
    help
    exit 1
  fi
}

start_parsing() {
  log "trace" "Starting start_parsing()..."

  # determines what to parse

  if [ -z "$TARGET_STACK" ] && [ -z "$TARGET_ITEM" ]; then
    log "debug" "Parsing '$TARGET_ACTION' '$TARGET_ENVIRONMENT'..."
    parse_environment "$REPO_PATH/environments/$TARGET_ENVIRONMENT"
  fi

  if [ ! -z "$TARGET_STACK" ] && [ -z "$TARGET_ITEM" ]; then
    log "debug" "Parsing '$TARGET_ACTION' '$TARGET_ENVIRONMENT.$TARGET_STACK'..."
    parse_stack "$REPO_PATH/environments/$TARGET_ENVIRONMENT/$TARGET_STACK"
  fi

  if [ ! -z "$TARGET_STACK" ] && [ ! -z "$TARGET_ITEM" ]; then
    log "debug" "Parsing '$TARGET_ACTION '$TARGET_ENVIRONMENT.$TARGET_STACK.$TARGET_ITEM'..."

    stack_path="$REPO_PATH/environments/$TARGET_ENVIRONMENT/$TARGET_STACK"

    prep_compose
    parse_item "$stack_path" "$TARGET_ITEM"
    build_env $stack_path
    compose "$REPO_PATH/environments/$TARGET_ENVIRONMENT/$TARGET_STACK" "$TARGET_ENVIRONMENT.$TARGET_STACK.$TARGET_ITEM"
    cleanup
  fi
}

check_dir() {
  log "trace" "Starting check_dir()..."
  log "trace" "Argument 1=$1"
  log "trace" "Argument 2=$2"

  if [ ! -d "$1" ]; then
    log "error" "'$2' does not exist."
    exit 1
  fi
}

check_file() {
  log "trace" "Starting check_file()..."
  log "trace" "Argument 1=$1"
  log "trace" "Argument 2=$2"

  if [ ! -f "$1" ]; then
    log "error" "'$2' does not exist."
    exit 1
  fi
}

parse_environment() {
  log "trace" "Starting parse_environment()..."
  log "trace" "Argument 1=$1"

  # parse every stack in an environment
  environment_path=$1

  environment_name=${environment_path##*/}

  check_dir $environment_path $environment_name

  stacks_txt_path=$environment_path/stacks.txt
  if [ -s "$stacks_txt_path" ] && [ -f "$stacks_txt_path" ]; then
    log "debug" "Parsing stacks listed in stacks.txt..."
    for stack_name in $(cat $stacks_txt_path); do
      parse_stack $environment_path/$stack_name
    done
  else
    log "debug" "Parsing all stacks..."
    for folder in "$environment_path"/*/; do
      stack_name=$(basename "$folder")
      parse_stack $environment_path/$stack_name
    done
  fi

}

parse_stack() {
  log "trace" "Starting parse_stack()..."
  log "trace" "Argument 1=$1"

  # parse every item in a stack
  stack_path=$1

  prep_compose

  stack_name=${stack_path##*/}
  path_without_stack=${stack_path%/*}
  environment_name=${path_without_stack##*/}

  check_dir $stack_path "$environment_name/$stack_name"

  # loop through yaml files to process each item
  yml_count=0
  for yaml_file in $stack_path/*.yml; do
    ((yml_count++))
    path_without_extension=${yaml_file%.yml}
    item_name=${path_without_extension##*/}
    parse_item "$stack_path" "$item_name"
  done

  if [ "$yml_count" -gt 0 ]; then
    build_env $stack_path
    compose "$stack_path" "$environment_name.$stack_name"
  else
    log "info" "Skipping $environment_name.$stack_name (no yml files found)..."
  fi

  cleanup
}

parse_item() {
  log "trace" "Starting parse_item()..."
  log "trace" "Argument 1=$1"
  log "trace" "Argument 2=$2"

  # parse an item
  stack_path=$1
  item_name=$2
  stack_name=${1##*/}
  path_without_stack=${1%/*}
  environment_name=${path_without_stack##*/}
  log "trace" "stack_name=$stack_name"
  log "trace" "environment_name=$environment_name"

  # docker-compose file
  compose_path=$stack_path/$item_name.yml
  check_file $compose_path "$environment_name/$stack_name/$item_name.yml"
  COMPOSE_COMMAND="$COMPOSE_COMMAND -f \"$compose_path\""

  # .env file
  env_path=$stack_path/$item_name.env
  if [[ -f "$env_path" ]]; then
    ENV_FILES="$ENV_FILES $env_path"
  fi

  # secrets.env file
  secrets_path=$stack_path/$item_name.secrets
  if [[ -f "$secrets_path" ]]; then
    SECRET_FILES="$SECRET_FILES $secrets_path"

    # create "secrets" example file (keys, no values) for github
    sed "s/=.*/=/" $secrets_path >$secrets_path.example
  fi
}

append_env() {
  # appends env if present

  log "trace" "Starting append_env()..."
  log "trace" "Argument 1=$1"

  env_path=$1/.env
  if [[ -f "$env_path" ]]; then
    log "trace" "Appending env file $env_path..."
    ENV_FILES="$ENV_FILES $env_path"
  else
    log "trace" "Skipping append for non-existent env file $env_path..."
  fi
}

build_env() {
  # build merged env file

  log "trace" "Starting build_env()..."

  stack_path=$1
  environment_path=$(readlink -f "$stack_path/../")
  environments_path=$(readlink -f "$environment_path/../")

  append_env $stack_path
  append_env $environment_path
  append_env $environments_path

  # merge env files with precedence
  sort -u -t '=' -k 1,1 $SECRET_FILES $ENV_FILES >$MERGED_ENV

  # Remove comments
  MERGED_ENV=$(echo "$MERGED_ENV" | sed '/^#/d')

  # special: replace variables with values
  while IFS= read -r line; do
    # Check if the line contains a variable assignment
    if [[ $line =~ ^([A-Za-z0-9_]+)= ]]; then
      # Extract the variable name (line_key) and value (line_value)
      line_key="${line%%=*}"
      line_value="${line#*=}"

      # Replace occurrences of "${line_key}" with the line_value
      sed -i -e "s/\${${line_key}}/${line_value}/g" "$MERGED_ENV"
    fi
  done <"$MERGED_ENV"

  file_contents=$(<$MERGED_ENV)
  log "debug" "Contents of merged.env:\n$file_contents"
}

prep_compose() {
  log "trace" "Starting prep_compose()..."

  COMPOSE_COMMAND="docker compose"
  ENV_FILES=""
  SECRET_FILES=""

  cleanup
}

cleanup() {
  log "trace" "Starting clean_up()..."

  MERGED_ENV=/tmp/merged.env
  rm $MERGED_ENV 2>/dev/null
}

compose() {
  log "trace" "Starting compose()..."

  # builds and runs the docker compose command
  COMPOSE_COMMAND_NO_ACTION="$COMPOSE_COMMAND --env-file \"$MERGED_ENV\""
  COMPOSE_COMMAND="$COMPOSE_COMMAND_NO_ACTION $TARGET_ACTION"
  [ "$TARGET_ACTION" = "up" ] && COMPOSE_COMMAND+=" -d"

  echo ""
  log "info" "Composing $TARGET_ACTION $2..."
  log "debug" "Compose command:\n$COMPOSE_COMMAND"

  # run compose command
  if [ "$TARGET_ACTION" = "rebuild" ]; then
    eval "$COMPOSE_COMMAND_NO_ACTION down"
    eval "$COMPOSE_COMMAND_NO_ACTION up -d"
  else
    eval $COMPOSE_COMMAND
  fi

  rm $FAKE_PATH 2>/dev/null
}

# main
LOG_LEVEL=debug

log "debug" "Starting..."

# set paths
SCRIPT_PATH=$(realpath "$0" | sed 's|\(.*\)/.*|\1|')
REPO_PATH=$(readlink -f "$SCRIPT_PATH/..")

check_arguments "$@"

start_parsing

echo ""
log "debug" "Complete"

shopt -u nullglob # Disable nullglob option
exit 0

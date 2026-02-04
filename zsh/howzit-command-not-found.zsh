# howzit command-not-found handler for zsh
#
# When an unknown command is entered, this handler will check to see
# if there is a howzit topic matching the command name. If so, it
# runs `howzit -r <command> [args...]`. Otherwise, it falls back to
# the standard "command not found" behavior.

command_not_found_handler() {
  local cmd="$1"
  shift

  # If a howzit topic matches the command name, run it instead
  if howzit --test-search "$cmd" >/dev/null 2>&1; then
    howzit -r "$cmd" "$@"
    return $?
  fi

  # Fall back to the default unknown-command message
  print "zsh: command not found: $cmd" >&2
  return 127
}


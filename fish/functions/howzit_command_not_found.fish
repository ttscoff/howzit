function fish_command_not_found --description "Use howzit topics for unknown commands when available"
    set cmd $argv[1]
    set args $argv[2..-1]

    # If a howzit topic matches the command name, run it instead
    if howzit --test-search $cmd >/dev/null 2>&1
        howzit -r $cmd $args
        return $status
    end

    # Fall back to the default unknown-command message
    echo "fish: Unknown command '$cmd'"
    return 127
end


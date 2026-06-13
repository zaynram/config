module elevate {
  # Run a command in an elevated Bash session.
  #
  @category shells
  export def "sudo bash" [
    --script (-s): path # Path to a bash script to invoke
    ...args: string # Joined as spaces and run as a command (if no script) else passed to script
  ]: oneof<nothing, list<string>> -> nothing {
    if $script != null {
      try {
        ^sudo bash $script ...$args
      } catch {
        throw "script invocation exited with errors" --data {
          script: $script
          args: ($args | str join ' ')
        }
      }
    } else {
      let content: string = (
        $in
        | default []
        | prepend '#!/usr/bin/env bash'
        | append ($args | str join ' ')
        | str join "\n"
      )
      let tmp: path = mktemp --suffix .sh
      try {
        $content | save --force $tmp
        ^sudo bash $tmp
      } catch {
        throw "command exited with errors" --data {
          command: ($args | str join ' ')
          tempfile: $tmp
        }
      } finally {
        rm --force $tmp
      }
    }
  }

  # Run a command or closure in an elevated Nushell session.
  #
  @category shells
  export def "sudo nu" [
    closure: closure # The closure to execute
    --prompt (-p) # Prompt the user for their password to elevate
  ]: nothing -> oneof<nothing, any> {
    if $prompt {
      ^sudo --prompt 'enter password: ' -- echo authenticated
    }
    ^sudo --preserve-env --non-interactive --stdin nu --config $nu.config-path --commands $'try (
      $closure | to nuon --serialize | from nuon
    ) catch { get --optional rendered | default "command completed with errors" }'
  }
}

overlay use elevate

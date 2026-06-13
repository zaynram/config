if (which __zoxide_zi | length) == 0 {
  let vendor: path = $nu.vendor-autoload-dirs | last | path join zoxide.nu
  if ($vendor | path exists) { ^$vendor } else {
    error make "zoxide vendor autoload script is missing"
  }
}
module zoxide {
  export alias zx = zoxide
  # Set the active working directory or interact with the zoxide database.
  #
  # If no arguments, the interactive panel will be shown.
  export def --env --wrapped dir [
    --interactive (-i) # Force interactive directory select
    ...rest: string # Arguments to pass to the underlying zoxide invocation
  ]: nothing -> oneof<nothing, string, list<string>> {
    let use_zi: bool = $interactive or ($rest | is-empty)
    if $use_zi { __zoxide_zi ...$rest } else { __zoxide_z ...$rest }
  }
}

overlay use zoxide

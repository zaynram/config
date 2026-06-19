# nu-lint-ignore-file: unhandled_external_error, pipe_spacing
module apt {
  use std null_device
  const NULL = '/dev/null'
  # Auto-elevating apt wrapper
  export alias sap = sudo apt-get
  # Install a system package using apt.
  export alias agi = sudo apt-get install --yes
  # Update and upgrade the system packages.
  export alias agu = try {
    sudo apt-get update --yes
    sudo apt-get upgrade --yes
  }
  # Run the automated cleanup scripts for apt
  export alias acl = try {
    sudo apt-get autoremove --yes
    sudo apt-get autoclean --yes
  }
  # Run the automated cleanup scripts for apt, optionally uninstalling packages first.
  export def arm [...names: string]: nothing -> string {
    if ($names | is-not-empty) { try { sudo apt-get remove --yes ...$names } }
    acl | collect { decode utf-8 }
  }
}

overlay use apt

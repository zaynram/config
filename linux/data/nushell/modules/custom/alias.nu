## alias.nu
module alias {
  export alias copy = win32yank.exe -i
  export alias paste = win32yank.exe -o --lf

  export alias pull = git pull
  export alias status = git status
  export alias push = git push
  export alias commit = git commit
  export alias clone = gh repo clone

  # Iterate over a sequence of elements with options for modifying the iteration mechanism.
  #
  # Note that `par-each` will run with `--keep-order` and `each` will run with `--flatten`.
  export def iterate [
    closure?: closure # Closure to execute during iteration
    --parallel (-p) # Use `par-each` for iteration
    --enumerate (-e) # Enumerate the items before iteration
    --index (-i) = true # Insert an index property into each item (default true; requires table input)
  ]: [
    oneof<table, list<record>> -> table
    list<any> -> list<any>
  ] {
    match ($in | describe --detailed).detailed_type? {
      _ if $enumerate => { enumerate }
      $t if $index and $t =~ table => { enumerate | par-each --keep-order {|x| select index | merge $x.item } }
      _ => { $in }
    } | if $closure == null {
      return $in
    } else if $parallel {
      par-each $closure --keep-order
    } else {
      each $closure --flatten
    }
  }

  export alias ll = ls --long
  export alias la = ls --all
  export alias lf = ls --full-paths
  export alias ld = ls --directory

  export alias curl = http get --raw
}

export use alias *

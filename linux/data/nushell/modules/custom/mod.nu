const ROOT: directory = path self .
const path = $ROOT | path join path.nu
const plugin = $ROOT | path join plugin.nu

export use $path
export use $plugin

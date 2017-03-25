# vim: set expandtab ts=2 sw=2:
function simp::classifier(String $scenario, Hash $scenario_map, Optional[Array] $overrides) {
  if ($overrides == undef) {
    $_overrides = []
  } else {
    $_overrides = $overrides
  }
  if has_key($scenario_map, $scenario) {
    $selected_classes = $_overrides + $scenario_map[$scenario]
  } else {
    # FIXME: should this be a fail?
    notify { "WARNING - Attempting to use an unknown SIMP scenario. Defaulting to 'none'": }
    $selected_classes = $_overrides
  }
  $classlist = simp::knockout($selected_classes)
  $classlist.each |$class| {
    include $class
  }
}

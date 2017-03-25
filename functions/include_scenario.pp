# simp::include_scenario()
#
# Includes the classes from the selected scenario, plus any additions from the
# the overrides parameter, and minus any overrides prefixed with `--`.
#
# @private
function simp::include_scenario(String $scenario, Hash[String, Array] $scenario_map, Optional[Array] $overrides) {
  $_overrides = $overrides ? {
    undef   => [],
    default => $overrides,
  }

  if $scenario_map.has_key($scenario) {
    $selected_classes = $scenario_map[$scenario] + $_overrides
  } else {
    fail("ERROR - Invalid scenario '${scenario}' for the given scenario map.")
  }

  include simp::knockout($selected_classes)
}
# vim: set expandtab ts=2 sw=2:

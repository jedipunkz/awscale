name "cpi"
description "base role for CPI server"
run_list(
  "recipe[apache2]",
  "recipe[apache2::mod_ssl]",
  "recipe[vhosts]"
)
override_attributes(
)

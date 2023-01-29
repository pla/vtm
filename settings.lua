data:extend({
  {
    type = "bool-setting",
    default_value = true,
    name = "vtm-showModgui",
    setting_type = "runtime-per-user",
    order = "a",
  },
  {
    type = "int-setting",
    name = "vtm-history-length",
    setting_type = "runtime-global",
    minimum_value = 10,
    maximum_value = 1000,
    default_value = 20,
    order = "a",
  },
  {
    type = "string-setting",
    name = "vtm-provider-names",
    setting_type = "runtime-global",
    default_value = "provider,mine,field,production",
    order = "b",
  },
  {
    type = "string-setting",
    name = "vtm-requester-names",
    setting_type = "runtime-global",
    default_value = "requester,delivery",
    order = "c",
  },
  {
    type = "string-setting",
    name = "vtm-depot-names",
    setting_type = "runtime-global",
    default_value = "depot,shuttle,unused",
    order = "d",
  },
  {
    type = "string-setting",
    name = "vtm-refuel-names",
    setting_type = "runtime-global",
    default_value = "refuel",
    order = "e",
  },
  {
    type = "bool-setting",
    name = "vtm-p-or-r-start",
    setting_type = "runtime-global",
    default_value = false,
    order = "f",
  },
  {
    type = "bool-setting",
    name = "vtm-dont-read-depot-stock",
    setting_type = "runtime-global",
    default_value = false,
    order = "g",
  },
  {
    type = "int-setting",
    name = "vtm-limit-auto-refresh",
    setting_type = "runtime-global",
    minimum_value = 0,
    maximum_value = 1000,
    default_value = 30,
    order = "h",
  },
})

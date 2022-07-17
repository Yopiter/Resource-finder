data:extend({
  {
    type = "shortcut",
    name = "resource-finder-button",
    action = "lua",
    order = "m[find-res]",
    style = "default",
    icon = {
      filename = "__resource-finder__/graphics/button-32-black.png",
      priority = "extra-high-no-scale",
      size = 32,
      -- scale = 0.5,
      flags = {"gui-icon"}
    },
    small_icon = {
      filename = "__resource-finder__/graphics/button-24-black.png",
      priority = "extra-high-no-scale",
      size = 24,
      -- scale = 0.5,
      flags = {"gui-icon"}
    }
  }
})

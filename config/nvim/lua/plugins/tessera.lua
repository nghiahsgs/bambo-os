-- Tessera: charcoal background, the same blue, orange and green as the desktop.
return {
  {
    "folke/tokyonight.nvim",
    opts = {
      style = "night",
      on_colors = function(c)
        c.bg = "#101012"
        c.bg_dark = "#101012"
        c.bg_float = "#161618"
        c.bg_sidebar = "#101012"
        c.bg_statusline = "#161618"
        c.bg_popup = "#161618"
        c.border = "#2a2a2e"
        c.fg = "#f4f4f5"
        c.comment = "#8e8e96"
        c.blue = "#5b8def"
        c.orange = "#ff8a4c"
        c.green = "#3ecf8e"
      end,
    },
  },
  { "LazyVim/LazyVim", opts = { colorscheme = "tokyonight" } },
}

return {
  "3rd/image.nvim",
  build = false,
  ft = { "markdown", "mdx" },
  opts = {
    backend = "kitty",
    integrations = {
      markdown = {
        enabled = true,
        clear_in_insert_mode = false,
        download_remote_images = true,
        only_render_image_at_cursor = false,
        filetypes = { "markdown", "mdx" },
      },
    },
    max_width = 100,
    max_height = 40,
    max_width_window_percentage = 60,
    max_height_window_percentage = 40,
    window_overlap_clear_enabled = true,
    window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs", "" },
  },
}

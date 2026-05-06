return {
  "HakonHarnes/img-clip.nvim",
  event = "BufEnter *.md",
  opts = {
    default = {
      dir_path = "assets",
      file_name = "%Y%m%d%H%M%S",
      use_absolute_path = false,
      relative_to_current_file = true,
    },
  },
  keys = {
    { "<leader>ip", "<cmd>PasteImage<cr>", desc = "Paste image from clipboard" },
  },
}

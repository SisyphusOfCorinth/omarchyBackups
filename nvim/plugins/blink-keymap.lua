return {
  {
    "saghen/blink.cmp",
    opts = {
      keymap = {
        ["<CR>"] = { "fallback" },
        ["<Tab>"] = { "accept", "snippet_forward", "fallback" },
      },
    },
  },
}

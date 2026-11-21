if vim.g.loaded_groff_preview then
  return
end
vim.g.loaded_groff_preview = true

vim.api.nvim_create_user_command("GroffPreview", function(cmd)
  require("groff-preview").preview(cmd.args)
end, {
  nargs = "?",
  complete = function()
    return require("groff-preview").viewers
  end,
  desc = "Build groff to PDF and preview it (:GroffPreview [auto|pane|sumatra|system])",
})

-- After :GroffPreview, every save rebuilds the PDF; the viewer reloads it.
vim.api.nvim_create_autocmd("BufWritePost", {
  group = vim.api.nvim_create_augroup("GroffPreview", { clear = true }),
  callback = function(ev)
    if vim.b[ev.buf].groff_preview then
      require("groff-preview").build(vim.api.nvim_buf_get_name(ev.buf))
    end
  end,
})

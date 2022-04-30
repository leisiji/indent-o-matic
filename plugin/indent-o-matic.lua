local group = "indent_o_matic"

vim.api.nvim_create_augroup(group, { clear = true })
vim.api.nvim_create_autocmd({ "BufReadPost" }, { group = group, callback = require("indent-o-matic").detect })

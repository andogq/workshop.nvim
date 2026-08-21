vim.pack.add({ "https://github.com/nvim-lua/plenary.nvim" }, { confirm = false })

vim.opt.rtp:append(vim.fn.getcwd())

require("workshop").setup()

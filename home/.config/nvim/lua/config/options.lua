local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.encoding = "utf-8"
opt.fileencoding = "utf-8"
opt.termguicolors = true
opt.background = "dark"

opt.expandtab = true
opt.shiftwidth = 4
opt.tabstop = 4
opt.smarttab = true
opt.autoindent = true
opt.smartindent = true

opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true
opt.showmatch = true

opt.hidden = true
opt.autoread = true
opt.splitbelow = true
opt.splitright = true
opt.signcolumn = "yes"
opt.updatetime = 250
opt.timeoutlen = 400

opt.foldmethod = "syntax"
opt.foldenable = false

opt.swapfile = false
opt.backup = false
opt.writebackup = false
opt.undofile = true

opt.errorbells = false
opt.visualbell = true

vim.diagnostic.config({
	severity_sort = true,
	underline = true,
	virtual_text = { spacing = 2, source = "if_many" },
	float = { border = "rounded", source = true },
})

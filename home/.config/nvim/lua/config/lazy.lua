local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

-- Homebrew Git currently stalls on GitHub smart HTTP on this workstation.
-- Restrict the fallback to Neovim and Git only; other tools remain Brew-first.
local system_git_dir = "/usr/lib/git-core"
if vim.fn.executable(system_git_dir .. "/git") == 1 then
	vim.env.PATH = system_git_dir .. ":" .. (vim.env.PATH or "")
end

if not vim.uv.fs_stat(lazypath) then
	local result = vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"--branch=stable",
		"https://github.com/folke/lazy.nvim.git",
		lazypath,
	})
	if vim.v.shell_error ~= 0 then
		error("Failed to install lazy.nvim:\n" .. result)
	end
end

vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
	spec = { { import = "plugins" } },
	checker = { enabled = true, notify = false },
	change_detection = { notify = false },
	install = { colorscheme = { "gruvbox" } },
})

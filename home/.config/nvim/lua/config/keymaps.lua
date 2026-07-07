local map = vim.keymap.set

for _, keys in ipairs({ "jj", "jk", "kk", "kj" }) do
	map("i", keys, "<Esc>", { desc = "Leave insert mode" })
end

for _, key in ipairs({ "<Up>", "<Down>", "<Left>", "<Right>" }) do
	map({ "n", "i" }, key, "<Nop>")
end

map("n", "<C-h>", "<C-w>h", { desc = "Focus left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Focus lower window" })
map("n", "<C-k>", "<C-w>k", { desc = "Focus upper window" })
map("n", "<C-l>", "<C-w>l", { desc = "Focus right window" })

map("n", "<leader>n", function()
	vim.opt_local.number = not vim.opt_local.number:get()
	vim.opt_local.relativenumber = vim.opt_local.number:get()
end, { desc = "Toggle line numbers" })

map("n", "<leader>r", vim.lsp.buf.rename, { desc = "LSP rename" })
map("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "LSP code action" })
map("n", "K", vim.lsp.buf.hover, { desc = "LSP hover" })
map("n", "gd", vim.lsp.buf.definition, { desc = "LSP definition" })
map("n", "gr", vim.lsp.buf.references, { desc = "LSP references" })

-- Preserve the old command-line shortcut for writing a root-owned file. Sudo is
-- still visible and interactive; this does not bypass the password prompt.
map("c", "w!!", "w !sudo tee % >/dev/null", { remap = true, desc = "Write with sudo tee" })

vim.api.nvim_create_autocmd("FileType", {
	pattern = "go",
	callback = function(event)
		local opts = { buffer = event.buf, silent = true }
		map("n", "<leader>b", "<cmd>!go build ./...<cr>", vim.tbl_extend("force", opts, { desc = "Go build" }))
		map("n", "<leader>t", "<cmd>!go test ./...<cr>", vim.tbl_extend("force", opts, { desc = "Go test" }))
		map("n", "<leader>l", "<cmd>!golangci-lint run<cr>", vim.tbl_extend("force", opts, { desc = "Go lint" }))
		map("n", "<leader>v", "<cmd>!go vet ./...<cr>", vim.tbl_extend("force", opts, { desc = "Go vet" }))
	end,
})

local command_aliases = {
	E = { command = "edit", file = true },
	W = { command = "write", file = true },
	Wq = { command = "wq", file = true },
	WQ = { command = "wq", file = true },
	Wa = { command = "wall" },
	WA = { command = "wall" },
	Q = { command = "quit" },
	QA = { command = "qall" },
	Qa = { command = "qall" },
}

for alias, target in pairs(command_aliases) do
	local target_command = target.command
	local command_options = { bang = true, nargs = target.file and "?" or 0 }
	if target.file then
		command_options.complete = "file"
	end

	vim.api.nvim_create_user_command(alias, function(args)
		local bang = args.bang and "!" or ""
		local argument = args.args ~= "" and (" " .. args.args) or ""
		vim.cmd(target_command .. bang .. argument)
	end, command_options)
end

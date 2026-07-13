-- Avoid desktop clipboard shims while working remotely. Neovim's tmux
-- provider copies through `load-buffer -w` and pastes through `save-buffer`,
-- which keeps the tmux buffer and the outer terminal clipboard in sync.
if vim.env.TMUX and vim.fn.executable("tmux") == 1 then
	vim.g.clipboard = "tmux"
elseif vim.env.SSH_CONNECTION then
	-- Outside tmux, OSC 52 is the portable way to reach the local terminal's
	-- clipboard from a remote Neovim session.
	vim.g.clipboard = "osc52"
end

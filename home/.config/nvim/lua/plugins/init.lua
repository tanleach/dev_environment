return {
	{
		"ellisonleao/gruvbox.nvim",
		priority = 1000,
		config = function()
			require("gruvbox").setup({ contrast = "hard" })
			vim.cmd.colorscheme("gruvbox")
		end,
	},

	{
		"nvim-treesitter/nvim-treesitter",
		lazy = false,
		build = ":TSUpdate",
		config = function()
			local treesitter = require("nvim-treesitter")
			treesitter.setup({})
			treesitter.install({
				"bash",
				"go",
				"gomod",
				"gosum",
				"json",
				"lua",
				"markdown",
				"markdown_inline",
				"nix",
				"python",
				"toml",
				"yaml",
			})
			vim.api.nvim_create_autocmd("FileType", {
				pattern = { "bash", "go", "gomod", "json", "lua", "markdown", "nix", "python", "toml", "yaml" },
				callback = function()
					pcall(vim.treesitter.start)
				end,
			})
		end,
	},

	{
		"nvim-telescope/telescope.nvim",
		dependencies = { "nvim-lua/plenary.nvim" },
		config = function()
			local builtin = require("telescope.builtin")
			vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
			vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Live grep" })
			vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Buffers" })
			vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "Help tags" })
		end,
	},

	{
		"stevearc/oil.nvim",
		lazy = false,
		opts = { view_options = { show_hidden = true } },
		keys = {
			{ "<leader>e", "<cmd>Oil<cr>", desc = "File browser" },
		},
	},

	{ "lewis6991/gitsigns.nvim", opts = {} },
	{ "nvim-lualine/lualine.nvim", opts = { options = { theme = "gruvbox" } } },
	{
		"folke/which-key.nvim",
		lazy = false,
		opts = {},
	},

	{
		"saghen/blink.cmp",
		version = "1.*",
		dependencies = { "rafamadriz/friendly-snippets" },
		opts = {
			keymap = {
				preset = "default",
				["<Tab>"] = { "select_next", "fallback" },
				["<S-Tab>"] = { "select_prev", "fallback" },
			},
			appearance = { nerd_font_variant = "mono" },
			completion = { documentation = { auto_show = true } },
			sources = { default = { "lsp", "path", "snippets", "buffer" } },
			fuzzy = { implementation = "prefer_rust_with_warning" },
		},
	},

	{
		"neovim/nvim-lspconfig",
		dependencies = { "saghen/blink.cmp" },
		config = function()
			local capabilities = require("blink.cmp").get_lsp_capabilities()
			local servers = { "gopls", "basedpyright", "ruff", "nixd", "lua_ls" }
			for _, server in ipairs(servers) do
				vim.lsp.config(server, { capabilities = capabilities })
				vim.lsp.enable(server)
			end
		end,
	},

	{
		"stevearc/conform.nvim",
		opts = {
			formatters_by_ft = {
				go = { "goimports", "gofumpt" },
				lua = { "stylua" },
				nix = { "nixfmt" },
				python = { "ruff_format" },
				sh = { "shfmt" },
			},
			format_on_save = {
				timeout_ms = 1000,
				lsp_format = "fallback",
			},
		},
	},

	{
		"mfussenegger/nvim-dap",
		keys = {
			{
				"<leader>db",
				function()
					require("dap").toggle_breakpoint()
				end,
				desc = "Debug breakpoint",
			},
			{
				"<leader>dc",
				function()
					require("dap").continue()
				end,
				desc = "Debug continue",
			},
			{
				"<leader>di",
				function()
					require("dap").step_into()
				end,
				desc = "Debug step into",
			},
			{
				"<leader>do",
				function()
					require("dap").step_over()
				end,
				desc = "Debug step over",
			},
			{
				"<leader>du",
				function()
					require("dap").step_out()
				end,
				desc = "Debug step out",
			},
			{
				"<leader>dr",
				function()
					require("dap").repl.open()
				end,
				desc = "Debug REPL",
			},
		},
		config = function()
			vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
			vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticInfo" })
		end,
	},

	{
		"leoluz/nvim-dap-go",
		ft = "go",
		dependencies = { "mfussenegger/nvim-dap" },
		opts = {},
	},

	{
		"mfussenegger/nvim-dap-python",
		ft = "python",
		dependencies = { "mfussenegger/nvim-dap" },
		config = function()
			local uv_tool_dir = vim.env.UV_TOOL_DIR or vim.fn.expand("~/.local/share/uv/tools")
			local debugpy_python = uv_tool_dir .. "/debugpy/bin/python"
			if vim.fn.executable(debugpy_python) == 1 then
				require("dap-python").setup(debugpy_python)
			else
				vim.notify("debugpy uv tool is missing; run the declared Brewfile", vim.log.levels.WARN)
			end
		end,
	},
}

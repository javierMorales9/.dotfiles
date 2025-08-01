-- This file can be loaded by calling `lua require('plugins')` from your init.vim
require("lspconfig").lua_ls.setup({})

-- Only required if you have packer configured as `opt`
vim.cmd.packadd("packer.nvim")

return require("packer").startup(function(use)
	-- Packer can manage itself
	use("wbthomason/packer.nvim")

	use({
	"rose-pine/neovim",
	as = "rose-pine",
	config = function()
		vim.cmd("colorscheme rose-pine")
	end,
	})

	use({
		"nvim-telescope/telescope.nvim",
		tag = "0.1.2",
		-- or                            , branch = '0.1.x',
		requires = {
			{ "nvim-lua/plenary.nvim" },
			{ "nvim-telescope/telescope-live-grep-args.nvim" },
		},
	})
	use({ "smartpde/telescope-recent-files" })

	use({ "nvim-treesitter/nvim-treesitter", { run = ":TSUpdate" } })
	use("nvim-treesitter/playground")

	use({
	"Pocco81/auto-save.nvim",
	config = function()
		require("auto-save").setup({
			callbacks = {
				before_saving = ":Neoformat<CR>",
			},
		})
	end,
	})
	use("mhartington/formatter.nvim")

	use({
		"stevearc/aerial.nvim",
		config = function()
			require("aerial").setup()
		end,
	})

	use("junegunn/gv.vim")
	use("airblade/vim-gitgutter")
	use("tpope/vim-fugitive")
	use("mbbill/undotree")
	
	use("nvim-tree/nvim-tree.lua")
	use("nvim-tree/nvim-web-devicons")
	use("theprimeagen/harpoon")

	use("github/copilot.vim")

	use({
		"VonHeikemen/lsp-zero.nvim",
		branch = "v2.x",
		requires = {
			-- LSP Support
			{ "neovim/nvim-lspconfig" }, -- Required
			{
				"williamboman/mason.nvim",
				run = function()
					pcall(vim.cmd, "MasonUpdate")
				end,
			}, -- Optional
			{ "williamboman/mason-lspconfig.nvim" }, -- Optional

			-- Autocompletion
			{ "hrsh7th/nvim-cmp" }, -- Required
			{ "hrsh7th/cmp-nvim-lsp" }, -- Required
			{ "L3MON4D3/LuaSnip" }, -- Required
		},
	})

	--Debugging
	use({
		"mfussenegger/nvim-dap",
		opt = true,
		module = { "dap" },
		requires = {
			"theHamsta/nvim-dap-virtual-text",
			{ "rcarriga/nvim-dap-ui", module = "dapui" },
			"mfussenegger/nvim-dap-python",
			"nvim-telescope/telescope-dap.nvim",
			{ "leoluz/nvim-dap-go", module = "dap-go" },
			{ "jbyuki/one-small-step-for-vimkind", module = "osv" },
			{ "mxsdev/nvim-dap-vscode-js", module = { "dap-vscode-js" } },
			{
				"microsoft/vscode-js-debug",
				opt = true,
				run = "npm install --legacy-peer-deps && npx gulp vsDebugServerBundle && mv dist out",
			},
		},
		config = function()
			require("config.dap").setup()
		end,
		disable = false,
	})
end)

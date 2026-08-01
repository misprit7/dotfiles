return {
  'Equilibris/nx.nvim',
  dependencies = {
    'nvim-telescope/telescope.nvim',
  },
  opts = {
    -- Base command to run nx commands. Options: 'nx', 'npx nx', 'npm nx', 'yarn nx', 'pnpm nx'
    nx_cmd_root = 'nx',
  },
  keys = {
    { '<leader>nx', '<cmd>Telescope nx actions<cr>', desc = '[N]X actions' },
    { '<leader>ng', '<cmd>Telescope nx generators<cr>', desc = '[N]X [g]enerators' },
    { '<leader>nr', '<cmd>Telescope nx run_many<cr>', desc = '[N]X [r]un many' },
    { '<leader>na', '<cmd>Telescope nx affected<cr>', desc = '[N]X [a]ffected' },
  },
}

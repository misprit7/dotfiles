-- GitHub Copilot for inline autocomplete suggestions
-- Uses copilot.lua (pure Lua implementation) with blink.cmp integration
return {
  {
    'zbirenbaum/copilot.lua',
    cmd = 'Copilot',
    event = 'InsertEnter',
    config = function()
      require('copilot').setup {
        panel = {
          enabled = false,
        },
        suggestion = {
          enabled = true,
          auto_trigger = true,
          hide_during_completion = true,
          debounce = 75,
          keymap = {
            accept = '<Tab>',
            accept_word = '<M-w>',
            accept_line = '<M-e>',
            next = '<M-]>',
            prev = '<M-[>',
            dismiss = false,
          },
        },
        filetypes = {
          yaml = true,
          markdown = true,
          gitcommit = true,
          ['.'] = false,
        },
      }

      -- Toggle Copilot suggestions on/off with Ctrl-]
      vim.keymap.set('n', '<C-]>', function()
        require('copilot.suggestion').toggle_auto_trigger()
        local enabled = vim.b.copilot_suggestion_auto_trigger
        if enabled == nil then enabled = true end
        vim.notify('Copilot suggestions: ' .. (enabled and 'ON' or 'OFF'), vim.log.levels.INFO)
      end, { desc = 'Toggle Copilot suggestions' })
    end,
  },
  {
    'fang2hou/blink-copilot',
    dependencies = { 'zbirenbaum/copilot.lua' },
  },
}

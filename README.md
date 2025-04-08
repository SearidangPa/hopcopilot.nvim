# hopcopilot.nvim
Hop to the place you want in copilot suggestion. Inspired by folke's flash.nvim.

## Flow
* I see a copilot suggestion
* I only want to accept up until a certain point
* I press a trigger-key and a char that i want to hop to
* This plugin label all the places that has the char
* I input the label key to accept copilot suggestion up until then.


## Demo
https://github.com/user-attachments/assets/41f07a2c-090b-4d0b-9175-4a0058f985fe

It should also handle multiline suggestions. [demo](https://github.com/user-attachments/assets/7697bc8c-00cd-48ce-b281-8f549fd562c7). 



## How i set it up

```lua
return {
  'SearidangPa/copilot_hop.nvim',
  dependencies = {
    'github/copilot.vim',
  },
  config = function()
    local copilot_hop = require 'copilot_hop'
    copilot_hop.setup()
    vim.keymap.set('i', '<M-s>', copilot_hop.copilot_hop, { silent = true, desc = 'copilot_hop' })
    vim.keymap.set('i', '<D-s>', copilot_hop.copilot_hop, { silent = true, desc = 'copilot_hop' })
  end,
}
```


## Dependencies
* `github/copilot.vim`. 

local telescope = require('telescope')

-- Manually register the extension
package.loaded['telescope._extensions.worktree'] = {
  exports = {
    worktree = require('custom.telescope_worktree.worktree').create_worktree
  }
}

-- Register with Telescope
return telescope.register_extension(package.loaded['telescope._extensions.worktree'])

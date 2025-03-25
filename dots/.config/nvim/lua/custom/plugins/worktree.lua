local actions = require 'telescope.actions'
local action_state = require 'telescope.actions.state'
local pickers = require 'telescope.pickers'
local finders = require 'telescope.finders'
local conf = require('telescope.config').values

local M = {}

-- git worktree add --track -b <branch> <path> <remote>/<branch>
--
-- git worktree add --track -b astro ../portfolio-v2_astro origin/astro

M.create_worktree = function(opts)
  local handle = io.popen "git branch --all --format='%(refname:short)' 2>/dev/null"
  if not handle then
    print 'Failed to list git branches.'
    return
  end

  local branches = {}
  for branch in handle:lines() do
    table.insert(branches, branch)
  end
  handle:close()

  if #branches == 0 then
    print 'No branches found!'
    return
  end

  pickers
    .new(opts, {
      prompt_title = 'Select Branch for Worktree',
      finder = finders.new_table {
        results = branches,
      },

      sorter = conf.generic_sorter {},

      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          local new_brach_input = action_state.get_current_line() -- Get user input directly
          local branch = selection and selection[1] or new_brach_input

          -- closes the popup
          actions.close(prompt_bufnr)

          if branch then
            -- Get list of remotes
            local remotes = vim.fn.systemlist 'git remote'
            local remote_pattern = '^(' .. table.concat(remotes, '|') .. ')/(.+)$'

            local remote, branch_name = branch:match(remote_pattern)
            if not branch_name then
              branch_name = branch -- No remote, it's a local branch
            end

            -- Get the repo name
            local repo_name = vim.fn.fnamemodify(vim.fn.getcwd(), ':t')

            -- Sanitize the branch name (remove special characters, replace `/` with `_`)
            local safe_branch = branch_name:gsub('[^%w-_]', '_'):gsub('/', '_')

            local default_path = '../' .. repo_name .. '_' .. safe_branch

            -- Prompt the user for a path, defaulting to reponame_branchname
            local user_input = vim.fn.input('Worktree path: ', default_path, 'file')

            -- Use user input if provided, else default to reponame_branchname
            local path = user_input ~= '' and user_input or default_path

            if path ~= '' then
              -- git_worktree_command = 'git worktree add --track -b ' .. branch_name .. ' ' .. path .. ' ' .. branch
              --
              -- print(git_worktree_command)
              -- local git_worktree_command = {
              --   'git',
              --   'worktree',
              --   'add',
              --   '--track',
              --   '-b',
              --   branch_name,
              --   path,
              --   branch,
              -- }

              local function branch_exists_remotely(b)
                local cmd = { 'git', 'show-ref', 'refs/remotes/origin/' .. b }
                local result = vim.system(cmd):wait()
                return result.code == 0
              end

              local command
              if branch_exists_remotely(branch) then
                command = { 'git', 'worktree', 'add', '--track', '-b', branch_name, path, branch }
              else
                command = { 'git', 'worktree', 'add', '-b', branch_name, path }
              end
              local cwd = vim.fn.getcwd()

              vim.system(command, { cwd = cwd }, function(obj)
                vim.schedule(function()
                  if obj.code == 0 then
                    vim.notify('✅ Worktree created successfully at ' .. path, vim.log.levels.INFO)
                  else
                    vim.notify('❌ Error creating worktree: ' .. obj.stderr, vim.log.levels.ERROR)
                  end
                end)
              end)

              -- print('Created worktree at ' .. path .. ' for branch ' .. branch)
              -- print(git_worktree_command)
            else
              print 'Invalid path!'
            end
          end
        end)

        return true
      end,
    })
    :find()
end

M.create_worktree {}

return M

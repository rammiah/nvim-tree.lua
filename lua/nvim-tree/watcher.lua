local uv = vim.loop

local log = require "nvim-tree.log"
local utils = require "nvim-tree.utils"

local M = {}
local Watcher = {}
Watcher.__index = Watcher

-- TODO check for a Watcher with the same opts.absolute_path and return that
function Watcher.new(opts)
  if not M.enabled then
    return nil
  end
  log.line("watcher", "Watcher:new   '%s'", opts.absolute_path)

  local stat, _ = uv.fs_stat(opts.absolute_path)
  if not stat or stat.type ~= "directory" then
    return nil
  end

  local watcher = setmetatable({
    _opts = opts,
  }, Watcher)

  return watcher:start()
end

function Watcher:start()
  log.line("watcher", "Watcher:start '%s'", self._opts.absolute_path)

  local rc, name

  self._p, _, name = uv.new_fs_poll()
  if not self._p then
    utils.warn(string.format("Could not initialize an fs_poll watcher for path %s : %s", self._opts.absolute_path, name))
    return nil
  end

  local poll_cb = vim.schedule_wrap(function(err, _, _)
    if err then
      log.line("watcher", "poll_cb for %s fail : %s", self._opts.absolute_path, err)
    else
      self._opts.on_event(self._opts.absolute_path)
    end
  end)

  -- TODO option for interval ms
  rc, _, name = uv.fs_poll_start(self._p, self._opts.absolute_path, 1, poll_cb)
  if rc ~= 0 then
    utils.warn(string.format("Could not start the fs_poll watcher for path %s : %s", self._opts.absolute_path, name))
    return nil
  end

  return self
end

function Watcher:stop()
  log.line("watcher", "Watcher:stop  '%s'", self._opts.absolute_path)
  if self._p then
    local rc, _, name = uv.fs_poll_stop(self._p)
    if rc ~= 0 then
      utils.warn(string.format("Could not stop the fs_poll watcher for path %s : %s", self._opts.absolute_path, name))
    end
    self._p = nil
  end
end

function Watcher:restart()
  self:stop()
  return self:start()
end

function M.setup(opts)
  M.enabled = opts.experimental_watchers
end

M.Watcher = Watcher

return M
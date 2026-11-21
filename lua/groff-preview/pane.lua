-- Opens bin/groff-preview-pane in a split next to Neovim:
--   WezTerm           sharp (iTerm2 image protocol), mouse scroll/zoom
--   Windows Terminal  sixel (WSL), lower resolution
--   tmux              sixel, lower resolution
-- Focus goes back to Neovim; the viewer closes when this Neovim exits and
-- reloads by itself whenever the PDF changes.

local M = {}

local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")
M.helper = root .. "/bin/groff-preview-pane"

local function first_executable(candidates)
  for _, exe in ipairs(candidates) do
    if exe and exe ~= "" and vim.fn.executable(exe) == 1 then
      return exe
    end
  end
end

local function wezterm_exe(config)
  local candidates = { config.wezterm or "", "wezterm" }
  if vim.fn.has("wsl") == 1 then
    vim.list_extend(candidates, vim.fn.glob("/mnt/c/Users/*/AppData/Local/Programs/WezTerm/wezterm.exe", true, true))
    table.insert(candidates, "/mnt/c/Program Files/WezTerm/wezterm.exe")
    table.insert(candidates, "wezterm.exe")
  end
  return first_executable(candidates)
end

--- Which split this terminal supports: "wezterm", "wt", "tmux" or nil.
function M.kind(config)
  if vim.env.TMUX then
    return "tmux"
  end
  if vim.env.TERM_PROGRAM == "WezTerm" and wezterm_exe(config) then
    return "wezterm"
  end
  if vim.env.WT_SESSION and vim.fn.executable("wt.exe") == 1 then
    return "wt"
  end
end

-- The viewer writes /tmp/groff-preview-pane-<uid>/<sha256 of path>.pid.
local function viewer_running(file)
  local real = vim.uv.fs_realpath(file) or file
  local pidfile = string.format("/tmp/groff-preview-pane-%d/%s.pid", vim.uv.getuid(), vim.fn.sha256(real))
  local f = io.open(pidfile, "r")
  if not f then
    return false
  end
  local pid = tonumber(f:read("*l") or "")
  f:close()
  return pid ~= nil and vim.uv.kill(pid, 0) == 0
end

-- Command that runs the viewer. A Windows terminal (wezterm.exe / wt.exe)
-- has to start it through wsl.exe.
local function viewer_cmd(file, via_wsl)
  local cmd = { M.helper, "--owner", tostring(vim.fn.getpid()), file }
  if via_wsl then
    local distro = vim.env.WSL_DISTRO_NAME or "Ubuntu"
    return vim.list_extend({ "wsl.exe", "-d", distro, "--cd", "~", "-e" }, cmd)
  end
  return cmd
end

--- Open (or keep) the viewer for `file`.
--- @param file string
--- @param config table plugin config (pane_size, pane_position, wezterm)
--- @return boolean opened false when no supported split is available
function M.open(file, config)
  local kind = M.kind(config)
  if not kind then
    return false
  end
  if viewer_running(file) then
    return true
  end
  local size = config.pane_size or 40
  local bottom = config.pane_position == "bottom"

  if kind == "wezterm" then
    local exe = wezterm_exe(config)
    local cmd = { exe, "cli", "split-pane", bottom and "--bottom" or "--right", "--percent", tostring(size), "--" }
    vim.list_extend(cmd, viewer_cmd(file, exe:match("%.exe$") ~= nil))
    vim.fn.jobstart(cmd, {
      on_exit = function()
        vim.fn.jobstart({ exe, "cli", "activate-pane-direction", bottom and "Up" or "Left" })
      end,
    })
  elseif kind == "wt" then
    local cmd = { "wt.exe", "-w", "0", "split-pane", bottom and "-H" or "-V", "--size", string.format("%.2f", size / 100) }
    vim.list_extend(cmd, viewer_cmd(file, true))
    vim.list_extend(cmd, { ";", "move-focus", bottom and "up" or "left" })
    vim.fn.jobstart(cmd, { detach = true })
  else
    local shell_cmd = table.concat(vim.tbl_map(vim.fn.shellescape, viewer_cmd(file, false)), " ")
    local out = vim.fn.system({ "tmux", "split-window", bottom and "-v" or "-h", "-d", "-l", size .. "%", shell_cmd })
    if vim.v.shell_error ~= 0 then
      vim.notify("[groff] tmux split-window failed: " .. out, vim.log.levels.WARN)
    end
  end
  return true
end

return M

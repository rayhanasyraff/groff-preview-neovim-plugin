-- Groff live preview: :GroffPreview builds file.pdf and opens it; every later
-- :w rebuilds the PDF and the viewer reloads it (keeping your page and zoom).
-- .mom -> pdfmom (two passes: TOC, bookmarks, refs); .me/.mm -> groff -me/-mm;
-- anything else -> groff -ms.
-- -P-e embeds all fonts in the PDF; -k UTF-8 input; -t -e -p = tbl, eqn, pic.

local M = {}

local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h:h")
local tile_ps1 = root .. "/scripts/sumatra-tile.ps1"

M.viewers = { "auto", "pane", "sumatra", "system" }

M.config = {
  -- "auto": pane in WezTerm, else SumatraPDF if found, else a pane split
  -- (Windows Terminal / tmux), else the system PDF viewer.
  viewer = "auto",
  -- SumatraPDF: share of the screen width kept for the terminal.
  ratio = 0.55,
  -- Pane viewer: size in percent and "right" or "bottom".
  pane_size = 40,
  pane_position = "right",
  -- Paths; nil = auto-detect.
  sumatra = nil,
  wezterm = nil,
  -- Build command per extension; "$1" = source, "$2" = output PDF.
  commands = {
    mom = 'pdfmom -k -t -e -p -P-e "$1" > "$2"',
    me = 'groff -me -k -t -e -p -Tpdf -P-e "$1" > "$2"',
    mm = 'groff -mm -k -t -e -p -Tpdf -P-e "$1" > "$2"',
    default = 'groff -ms -k -t -e -p -Tpdf -P-e "$1" > "$2"',
  },
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

-- Settings from vim.g (groff_preview_viewer / _ratio) override setup().
local function cfg(key)
  local g = vim.g["groff_preview_" .. key]
  if g ~= nil then
    return g
  end
  return M.config[key]
end

local function build_cmd(src)
  local ext = src:match("%.([^./]+)$") or ""
  return M.config.commands[ext] or M.config.commands.default
end

function M.build(src, on_done)
  local pdf = src:gsub("%.[^./]+$", "") .. ".pdf"
  local tmp = pdf .. ".tmp"
  vim.system({ "sh", "-c", build_cmd(src) .. ' && mv -f "$2" "$3"', "sh", src, tmp, pdf }, { text = true },
    vim.schedule_wrap(function(r)
      if r.code ~= 0 then
        os.remove(tmp)
        vim.notify("groff failed:\n" .. (r.stderr or ""), vim.log.levels.ERROR)
      elseif on_done then
        on_done(pdf)
      end
    end))
end

local function first_executable(candidates)
  for _, exe in ipairs(candidates) do
    if exe and exe ~= "" and vim.fn.executable(exe) == 1 then
      return exe
    end
  end
end

local function sumatra_exe()
  if vim.fn.has("wsl") == 0 and vim.fn.has("win32") == 0 then
    return nil
  end
  local candidates = { M.config.sumatra or "", "SumatraPDF.exe" }
  vim.list_extend(candidates, vim.fn.glob("/mnt/c/Users/*/AppData/Local/SumatraPDF/SumatraPDF.exe", true, true))
  table.insert(candidates, "/mnt/c/Program Files/SumatraPDF/SumatraPDF.exe")
  return first_executable(candidates)
end

local function pwsh()
  return first_executable({ "/mnt/c/Program Files/PowerShell/7/pwsh.exe", "pwsh.exe", "powershell.exe" })
end

local function winpath(p)
  return vim.trim(vim.fn.system({ "wslpath", "-w", p }))
end

local function open_sumatra(pdf, exe)
  local ps = pwsh()
  if ps then
    -- Open Sumatra and tile it beside this terminal window, focus back here.
    vim.fn.jobstart({ ps, "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
      "-File", winpath(tile_ps1), "-Pdf", winpath(pdf), "-Sumatra", winpath(exe),
      "-Ratio", tostring(cfg("ratio")) }, { detach = true })
  else
    vim.fn.jobstart({ "setsid", exe, "-reuse-instance", winpath(pdf) }, { detach = true })
  end
end

local function open_system(pdf)
  local ok, err = pcall(vim.ui.open, pdf)
  if not ok then
    vim.notify("[groff] could not open " .. pdf .. ": " .. tostring(err), vim.log.levels.ERROR)
  end
end

local function resolve_viewer(choice)
  choice = (choice and choice ~= "") and choice or cfg("viewer")
  if choice ~= "auto" then
    return choice
  end
  local pane = require("groff-preview.pane")
  local kind = pane.kind(M.config)
  if kind == "wezterm" then
    return "pane"
  end
  if sumatra_exe() then
    return "sumatra"
  end
  return kind and "pane" or "system"
end

function M.open(pdf, viewer)
  if viewer == "pane" then
    if require("groff-preview.pane").open(pdf, M.config) then
      return
    end
    vim.notify("[groff] no split available (needs WezTerm, Windows Terminal or tmux); using the system viewer",
      vim.log.levels.WARN)
    return open_system(pdf)
  end
  if viewer == "sumatra" then
    local exe = sumatra_exe()
    if exe then
      return open_sumatra(pdf, exe)
    end
    vim.notify("[groff] SumatraPDF not found; using the system viewer", vim.log.levels.WARN)
  end
  open_system(pdf)
end

--- :GroffPreview [auto|pane|sumatra|system]
function M.preview(choice)
  local viewer = resolve_viewer(vim.trim(choice or ""))
  if not vim.tbl_contains(M.viewers, viewer) or viewer == "auto" then
    vim.notify("[groff] unknown viewer '" .. viewer .. "' (use " .. table.concat(M.viewers, ", ") .. ")",
      vim.log.levels.ERROR)
    return
  end
  local src = vim.api.nvim_buf_get_name(0)
  if src == "" then
    vim.notify("[groff] save the buffer to a file first", vim.log.levels.ERROR)
    return
  end
  if vim.bo.modified then
    vim.cmd("write")
  end
  vim.b.groff_preview = true
  M.build(src, function(pdf)
    M.open(pdf, viewer)
  end)
end

return M

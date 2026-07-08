local List = require("pandoc.List")

local function has_class(element, class)
  for _, value in ipairs(element.classes or {}) do
    if value == class then
      return true
    end
  end

  return false
end

local function is_space(inline)
  return inline.t == "Space" or inline.t == "SoftBreak" or inline.t == "LineBreak"
end

local function trim_text(text)
  return text:gsub("^%s+", ""):gsub("%s+$", "")
end

local function escape_rtf(text)
  return text:gsub("\\", "\\\\"):gsub("{", "\\{"):gsub("}", "\\}")
end

local function trim_inlines(inlines)
  local trimmed = List:new(inlines)

  while #trimmed > 0 and is_space(trimmed[1]) do
    trimmed:remove(1)
  end

  while #trimmed > 0 and is_space(trimmed[#trimmed]) do
    trimmed:remove(#trimmed)
  end

  if #trimmed > 0 and trimmed[1].t == "Str" then
    trimmed[1].text = trim_text(trimmed[1].text)
    if trimmed[1].text == "" then
      trimmed:remove(1)
    end
  end

  if #trimmed > 0 and trimmed[#trimmed].t == "Str" then
    trimmed[#trimmed].text = trim_text(trimmed[#trimmed].text)
    if trimmed[#trimmed].text == "" then
      trimmed:remove(#trimmed)
    end
  end

  return trimmed
end

local function is_pipe(inline)
  return (inline.t == "Math" and inline.text == "|") or (inline.t == "Str" and inline.text == "|")
end

local function stringify_plain(inlines)
  return trim_text(pandoc.utils.stringify(inlines))
end

local function raw_inline(inline)
  if inline.t == "Space" or inline.t == "SoftBreak" then
    return " "
  end

  if inline.t == "Str" then
    return escape_rtf(inline.text)
  end

  if inline.t == "Math" then
    return escape_rtf(inline.text)
  end

  if inline.t == "Link" then
    local label = escape_rtf(stringify_plain(inline.content))
    local target = escape_rtf(inline.target)
    return '{\\field{\\*\\fldinst{HYPERLINK "' .. target .. '"}}{\\fldrslt{\\ul ' .. label .. "}}}"
  end

  if inline.content then
    local text = ""
    for _, child in ipairs(inline.content) do
      text = text .. raw_inline(child)
    end
    return text
  end

  return escape_rtf(pandoc.utils.stringify(inline))
end

local function raw_segment(inlines)
  local segment = ""

  for _, inline in ipairs(trim_inlines(inlines)) do
    segment = segment .. raw_inline(inline)
  end

  return trim_text(segment:gsub("%s+", " "))
end

local function contact_line(inlines)
  local segments = List:new()
  local current = List:new()

  for _, inline in ipairs(inlines) do
    if is_pipe(inline) then
      local segment = raw_segment(current)
      if segment ~= "" then
        segments:insert(segment)
      end
      current = List:new()
    else
      current:insert(inline)
    end
  end

  local segment = raw_segment(current)
  if segment ~= "" then
    segments:insert(segment)
  end

  return table.concat(segments, " | ")
end

local function split_heading_lines(inlines)
  local lines = List:new()
  local current = List:new()

  for _, inline in ipairs(inlines) do
    if inline.t == "LineBreak" then
      lines:insert(current)
      current = List:new()
    else
      current:insert(inline)
    end
  end

  lines:insert(current)
  return lines
end

local function is_resume_heading(div)
  if not has_class(div, "center") or #div.content ~= 1 or div.content[1].t ~= "Para" then
    return false
  end

  local lines = split_heading_lines(div.content[1].content)
  return #lines >= 3 and stringify_plain(lines[1]) == "Ryan Wallace"
end

local function resume_heading_blocks(div)
  local lines = split_heading_lines(div.content[1].content)
  local name = escape_rtf(stringify_plain(lines[1]))
  local blocks = List:new()

  blocks:insert(pandoc.RawBlock("rtf", "{\\pard \\qc \\f0 \\b \\fs36 " .. name .. "\\par}"))

  for index = 2, #lines do
    local line = contact_line(lines[index])
    if line ~= "" then
      blocks:insert(pandoc.RawBlock("rtf", "{\\pard \\qc \\f0 \\b0 \\fs24 " .. line .. "\\par}"))
    end
  end

  return blocks
end

local function blocks_to_inlines(blocks)
  local inlines = List:new()

  for _, block in ipairs(blocks) do
    if block.t == "Plain" or block.t == "Para" then
      inlines:extend(block.content)
    end
  end

  return trim_inlines(inlines)
end

local function table_rows(table)
  local rows = List:new()

  if table.head and table.head.rows then
    rows:extend(table.head.rows)
  end

  for _, body in ipairs(table.bodies or {}) do
    rows:extend(body.body or {})
  end

  if table.foot and table.foot.rows then
    rows:extend(table.foot.rows)
  end

  return rows
end

local function flatten_row(row)
  local row_inlines = List:new()

  for index, cell in ipairs(row.cells or {}) do
    local cell_inlines = blocks_to_inlines(cell.contents)
    if #cell_inlines > 0 then
      if #row_inlines > 0 then
        row_inlines:extend({ pandoc.Space(), pandoc.Str("|"), pandoc.Space() })
      end
      row_inlines:extend(cell_inlines)
    end
  end

  if #row_inlines == 0 then
    return nil
  end

  return pandoc.Plain(trim_inlines(row_inlines))
end

function Table(table)
  local blocks = List:new()

  for _, row in ipairs(table_rows(table)) do
    local block = flatten_row(row)
    if block then
      blocks:insert(block)
    end
  end

  return blocks
end

function Div(div)
  if is_resume_heading(div) then
    return resume_heading_blocks(div)
  end

  return div
end

function Para(para)
  return pandoc.Para(trim_inlines(para.content))
end

function Plain(plain)
  return pandoc.Plain(trim_inlines(plain.content))
end

function Span(span)
  span.content = trim_inlines(span.content)
  return span
end

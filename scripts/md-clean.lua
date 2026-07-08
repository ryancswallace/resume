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

local function split_heading_lines(inlines)
  local lines = List:new()
  local current = List:new()

  for _, inline in ipairs(inlines) do
    if inline.t == "LineBreak" then
      lines:insert(trim_inlines(current))
      current = List:new()
    else
      current:insert(inline)
    end
  end

  lines:insert(trim_inlines(current))
  return lines
end

local function stringify_plain(inlines)
  return trim_text(pandoc.utils.stringify(inlines))
end

local function markdown_link(link)
  local label = stringify_plain(link.content)
  return pandoc.RawInline("markdown", "[" .. label .. "](" .. link.target .. ")")
end

local function contact_line(inlines)
  local cleaned = List:new()

  for _, inline in ipairs(trim_inlines(inlines)) do
    if is_pipe(inline) then
      if #cleaned > 0 and not is_space(cleaned[#cleaned]) then
        cleaned:insert(pandoc.Space())
      end
      cleaned:insert(pandoc.Str("|"))
      cleaned:insert(pandoc.Space())
    elseif inline.t ~= "SoftBreak" then
      if inline.t == "Link" then
        cleaned:insert(markdown_link(inline))
      else
        cleaned:insert(inline)
      end
    end
  end

  return trim_inlines(cleaned)
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
  local blocks = List:new()

  blocks:insert(pandoc.Header(1, { pandoc.Str(stringify_plain(lines[1])) }))

  for index = 2, #lines do
    local line = contact_line(lines[index])
    if #line > 0 then
      blocks:insert(pandoc.Plain(line))
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

  for _, cell in ipairs(row.cells or {}) do
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

local function first_inline(block)
  if block and (block.t == "Plain" or block.t == "Para") then
    return trim_inlines(block.content)[1]
  end

  return nil
end

local function is_container_item(item)
  local first = first_inline(item[1])
  return first and first.t == "Strong"
end

local function is_title_item(item)
  local first = first_inline(item[1])
  return first and first.t == "Emph"
end

local function nest_title_items(items)
  local nested = List:new()
  local current_container = nil
  local current_role_list = nil

  for _, item in ipairs(items) do
    if is_container_item(item) then
      local container = List:new({ pandoc.Para(item[1].content) })
      local roles = List:new()

      if item[2] and (item[2].t == "Plain" or item[2].t == "Para") then
        local first_role = List:new({ item[2] })
        for index = 3, #item do
          first_role:insert(item[index])
        end
        roles:insert(first_role)
      else
        for index = 2, #item do
          container:insert(item[index])
        end
      end

      if #roles > 0 then
        local role_list = pandoc.BulletList(roles)
        container:insert(role_list)
        current_role_list = role_list
      else
        current_role_list = nil
      end

      nested:insert(container)
      current_container = container
    elseif current_container and current_role_list and is_title_item(item) then
      current_role_list.content:insert(item)
    else
      nested:insert(item)
      current_container = nil
      current_role_list = nil
    end
  end

  return nested
end

function Div(div)
  if is_resume_heading(div) then
    return resume_heading_blocks(div)
  end

  return div.content
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

function BulletList(list)
  local should_nest = false

  for _, item in ipairs(list.content) do
    if is_container_item(item) then
      should_nest = true
      break
    end
  end

  if should_nest then
    list.content = nest_title_items(list.content)
  end

  return list
end

function Math(math)
  if math.text == "|" then
    return pandoc.Str("|")
  end

  return math
end

function Header(header)
  if header.level == 1 then
    header.level = 2
  end

  return header
end

function SmallCaps(small_caps)
  return small_caps.content
end

function Underline(underline)
  return underline.content
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

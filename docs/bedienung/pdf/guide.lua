-- Pandoc filter for one page of the user guide (docs/bedienung/*.md).
--
-- The pages are converted one by one and joined into a single document.
-- So that headings and links still fit together, this filter
--   * prefixes every identifier with the page name (medien.md: "banner" -> "medien--banner"),
--   * gives the page's first heading the page name as identifier ("medien"),
--   * points links to other pages of the guide at those identifiers,
--   * points links to files outside the guide at GitHub (metadata repo_url),
--   * drops the "← Inhalt" link back to README.md,
--   * shifts headings down one level, so each page becomes a chapter (h1 is the guide's title).

local page = PANDOC_STATE.input_files[1]:match("([^/]+)%.md$")
local repo_url = "https://github.com/DerKleinePunk/carnine2/blob/main"
local guide_dir = "docs/bedienung"
local first_heading = true

local function page_id(name)
  return name:lower()
end

-- PDF viewers differ in how they match non-ASCII destination names,
-- so identifiers are kept to ASCII ("gerät" -> "geraet").
local umlauts = { ["ä"] = "ae", ["ö"] = "oe", ["ü"] = "ue", ["ß"] = "ss",
                  ["Ä"] = "ae", ["Ö"] = "oe", ["Ü"] = "ue" }

local function ascii(id)
  for from, to in pairs(umlauts) do
    id = id:gsub(from, to)
  end
  return (id:gsub("[^%w_.-]", ""))
end

local function anchor(name, id)
  if id == nil or id == "" then
    return page_id(name)
  end
  return page_id(name) .. "--" .. ascii(id)
end

-- Resolve "a/../b" in a path relative to the repository root.
local function normalize(path)
  local parts = {}
  for part in path:gmatch("[^/]+") do
    if part == ".." then
      table.remove(parts)
    elseif part ~= "." then
      table.insert(parts, part)
    end
  end
  return table.concat(parts, "/")
end

function Meta(meta)
  if meta.repo_url then
    repo_url = pandoc.utils.stringify(meta.repo_url)
  end
end

function Header(h)
  if first_heading then
    h.identifier = page_id(page)
    first_heading = false
  else
    h.identifier = anchor(page, h.identifier)
  end
  h.level = h.level + 1
  return h
end

function Link(link)
  local target = link.target
  if target:match("^%a[%w+.-]*:") then
    return nil -- http:, https:, mailto:
  end
  local file, frag = target:match("^([^#]*)#?(.*)$")
  if file == "" then
    link.target = "#" .. anchor(page, frag)
  elseif file:match("^[^/]+%.md$") then
    link.target = "#" .. anchor(file:gsub("%.md$", ""), frag)
  else
    link.target = repo_url .. "/" .. normalize(guide_dir .. "/" .. file)
    if frag ~= "" then
      link.target = link.target .. "#" .. frag
    end
  end
  return link
end

-- "← Inhalt" at the top of each page leads back to README.md on GitHub;
-- in the PDF the table of contents does that job.
function Para(para)
  local only = para.content[1]
  if #para.content == 1 and only.t == "Link" and only.target == "README.md"
      and pandoc.utils.stringify(only):match("^←") then
    return {}
  end
end

return {
  { Meta = Meta, Para = Para },
  { Header = Header, Link = Link },
}

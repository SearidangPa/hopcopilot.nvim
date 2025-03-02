local M = {}
local copilot_ns = vim.api.nvim_create_namespace("github-copilot")

---@class copilot_hop.Options
---@class matchInfo
---@field col number
---@field label string
---@field abs number

---@class matchesByRow
---@field number table<number, matchInfo> @class labels table<string, number>

--- === set up options ===
---@type copilot_hop.Options
local options = {
	labelHighlightGroup = "CopilotHopLabel",
}

--- Setup the plugin
---@param opts copilot_hop.Options
M.setup = function(opts)
	options = vim.tbl_deep_extend("force", options, opts or {})
	vim.api.nvim_set_hl(0, options.labelHighlightGroup, { fg = "#5097A4" })
end

-- === Jumping to a match ===

---@param labels table<string, number>
---@param ns number
---@param text string
local function jump_from_user_choice(labels, ns, text)
	local function split_into_lines(str)
		local lines = {}
		for line in (str .. "\n"):gmatch("(.-)\n") do -- This pattern captures each line including empty lines
			table.insert(lines, line)
		end
		return lines
	end
	local function put_lines_as_is(str)
		local lines = split_into_lines(str)
		vim.api.nvim_put(lines, "c", false, true)
	end

	local choice = vim.fn.nr2char(vim.fn.getchar())
	local pos = labels[choice]
	if pos then
		local partial = string.sub(text, 1, pos)
		put_lines_as_is(partial)
	end
	vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
end

-- === processing the suggestion text to find the matches ===

---@param text string
---@param char string
---@return table<number>
local parse_suggestion = function(text, char)
	local matches = {}
	local lower_text = string.lower(text)
	local lower_char = string.lower(char)
	local start = 1
	while true do
		local index = string.find(lower_text, lower_char, start, true)
		if not index then
			break
		end
		table.insert(matches, index)
		start = index + 1
	end
	return matches
end

---@param text string
---@param index number
---@return number, number
local function index_to_row_col(text, index)
	local row = 0
	local last_newline = 0
	for i = 1, index do
		if text:sub(i, i) == "\n" then
			row = row + 1
			last_newline = i
		end
	end
	local col = index - last_newline - 1 -- zero-indexed column
	return row, col
end

---@param text string
---@param matches table<number>
---@return table<string, number>, matchesByRow
local function transform_abs_match(text, matches)
	local function int_to_label(n)
		local allowed = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
		if n > #allowed then
			return "|"
		end
		return allowed:sub(n, n)
	end

	local labels = {}
	local matches_by_row = {}
	for i, abs_index in ipairs(matches) do
		local row, col = index_to_row_col(text, abs_index)
		if not matches_by_row[row] then
			matches_by_row[row] = {}
		end
		local label = int_to_label(i) -- Generate label using only a-z and A-Z.
		table.insert(matches_by_row[row], { col = col, label = label, abs = abs_index })
		labels[label] = abs_index
	end
	return labels, matches_by_row
end

---=== Building virtual lines for the jump ===

---@param text string
---@param matches_by_row matchesByRow
---@return table<string, string>, table<table<string, string>>
local function build_virtual_lines(text, matches_by_row)
	local lines = vim.split(text, "\n", { plain = true })
	local first_virtual_line = {}
	local virt_lines = {}

	for row, line_text in ipairs(lines) do
		local virt_line = {}
		local line_matches = matches_by_row[row - 1] or {} -- Adjust row to 0-indexed for our stored matches.
		table.sort(line_matches, function(a, b)
			return a.col < b.col
		end)

		local prev = 0
		for _, m in ipairs(line_matches) do
			if m.col > prev then
				table.insert(virt_line, { line_text:sub(prev + 1, m.col), "CopilotSuggestion" })
			end
			table.insert(virt_line, { m.label, options.labelHighlightGroup })
			prev = m.col + 1
		end
		if prev < #line_text then
			table.insert(virt_line, { line_text:sub(prev + 1), "CopilotSuggestion" })
		end

		if row == 1 then
			first_virtual_line = virt_line
		else
			table.insert(virt_lines, virt_line)
		end
	end

	return first_virtual_line, virt_lines
end

local function display_virtual_lines(ns, first_virtual_line, virt_lines)
	vim.api.nvim_buf_clear_namespace(0, copilot_ns, 0, -1)

	vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
	local start_line = vim.fn.line(".") - 1 -- current line (0-indexed)
	local start_col = vim.fn.col(".") - 1

	vim.api.nvim_buf_set_extmark(0, ns, start_line, start_col, {
		virt_text = first_virtual_line,
		virt_text_pos = "inline", -- places text right after the cursor
	})

	if #virt_lines > 0 then
		vim.api.nvim_buf_set_extmark(0, ns, start_line, start_col, {
			virt_lines = virt_lines,
		})
	end

	vim.cmd("redraw")
end

M.copilot_hop = function()
	local ns = vim.api.nvim_create_namespace("copilot_jump")
	local char = vim.fn.nr2char(vim.fn.getchar())
	local suggestion = vim.fn["copilot#GetDisplayedSuggestion"]()
	local text = suggestion.text
	assert(suggestion, "copilot#GetDisplayedSuggestion not found")
	assert(text, "suggestion text not found")

	local matches = parse_suggestion(text, char)
	if #matches == 0 then
		vim.api.nvim_out_write("No jump targets found\n")
		return
	elseif #matches == 1 then
		local partial = string.sub(text, 1, matches[1])
		vim.api.nvim_feedkeys(partial, "n", false)
	else
		local labels, matches_by_row = transform_abs_match(text, matches)
		local first_virt_line, virt_lines = build_virtual_lines(text, matches_by_row)

		vim.cmd([[Copilot disable]]) -- Disable copilot to prevent it from popping up again
		display_virtual_lines(ns, first_virt_line, virt_lines)
		jump_from_user_choice(labels, ns, text)
		vim.cmd([[Copilot enable]])
	end
end

return M

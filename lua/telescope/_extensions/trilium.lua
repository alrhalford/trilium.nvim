local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local trilium = require("trilium-api")

local M = {}

local typeMapping = {
	["text/html"] = { ft = "html", suffix = "html" },
	["text/x-markdown"] = { ft = "markdown", suffix = "md" },
}

local function open_note_in_buffer(note, token)
	local buf = vim.api.nvim_create_buf(true, false)
	local title = note.title or "Untitled"
	local content = note.content or ""
	local noteId = note.noteId
	local filetype = typeMapping[note.mime].ft
	local suffix = typeMapping[note.mime].suffix

	if not noteId then
		vim.notify("Note ID missing", vim.log.levels.ERROR)
		return
	end

	vim.api.nvim_buf_set_name(buf, noteId .. "." .. suffix)

	-- Set content
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
		"--- " .. title .. " ---",
		"",
		unpack(vim.split(content, "\n")),
	})

	vim.bo[buf].modified = false
	vim.bo[buf].buftype = ""
	vim.bo[buf].bufhidden = "hide"
	vim.bo[buf].swapfile = false
	vim.bo[buf].modifiable = true
	vim.bo[buf].filetype = filetype
	vim.bo[buf].readonly = false

	vim.b[buf].trilium_note_id = noteId
	vim.b[buf].trilium_token = token

	vim.api.nvim_create_autocmd("BufWriteCmd", {
		buffer = buf,
		callback = function()
			local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
			table.remove(lines, 1)
			table.remove(lines, 1)
			local content = table.concat(lines, "\n")

			local function callback(success)
				vim.schedule(function()
					if success then
						vim.notify("Note saved to Trilium.", vim.log.levels.INFO)
						vim.bo[buf].modified = false
					else
						vim.notify("Failed to save note.", vim.log.levels.ERROR)
					end
				end)
			end

			trilium.update_note(noteId, content, callback)
		end,
	})

	vim.api.nvim_set_current_buf(buf)
end

M.search = function()
	local entry_cache = {}
	local picker

	local function refresh_picker(prompt)
		trilium.live_search(prompt, function(results)
			entry_cache = vim.tbl_map(function(item)
				return {
					value = item,
					display = item.title,
					ordinal = item.title or item.noteId,
					mime = item.mime,
					noteId = item.noteId,
				}
			end, results or {})

			if picker then
				picker:refresh(
					finders.new_table({
						results = entry_cache,
						entry_maker = function(entry)
							return entry
						end,
					}),
					{ reset_prompt = false }
				)
			end
		end)
	end

	picker = pickers.new({}, {
		prompt_title = "Trilium Notes",
		finder = finders.new_table({
			results = entry_cache,
			entry_maker = function(entry)
				return entry
			end,
		}),
		sorter = conf.generic_sorter({}),
		attach_mappings = function(prompt_bufnr, map)
			actions.select_default:replace(function()
				actions.close(prompt_bufnr)
				local selection = action_state.get_selected_entry()
				if selection then
					trilium.fetch_note_contents(selection.value.noteId, function(note_content)
						local note = {
							content = note_content,
							title = selection.value.title,
							mime = selection.value.mime,
							noteId = selection.value.noteId,
						}
						open_note_in_buffer(note, ConnectionOptions.token)
					end)
				end
			end)
			return true
		end,
		on_input_filter_cb = function(prompt)
			if prompt ~= last_prompt then
				last_prompt = prompt
				refresh_picker(prompt)
			end
			return prompt
		end,
	})

	picker:find()
end

return require("telescope").register_extension({
	exports = {
		search = M.search,
	},
})

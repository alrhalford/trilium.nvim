local cmp = require("cmp")
local trilium = require("trilium-api")

local source = {}

source.new = function()
	return setmetatable({}, { __index = source })
end

source.get_trigger_characters = function()
	return { "@" }
end

source.complete = function(self, params, callback)
	local line = params.context.cursor_before_line
	if not line:match("@%w*$") then
		return callback()
	end

	local input = line:match(".*@(%w*)$")
	trilium.live_search(input, function(items)
		if type(items) ~= "table" then
			return callback({ items = {} })
		end
		callback({
			items = vim.tbl_map(function(item)
				return {
					label = item.title,
					insertText = item.title,
					kind = cmp.lsp.CompletionItemKind.Text,
				}
			end, items),
		})
	end)
end

return source

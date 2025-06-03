local Job = require("plenary.job")

local M = {}

M.live_search = function(prompt, connectionOptions, callback)
	local url = connectionOptions.baseURL .. "/etapi/notes?ancestordepth=lt4&limit=100&search=" .. prompt

	Job:new({
		command = "curl",
		args = {
			"-s",
			"-H", "Authorization: " .. connectionOptions.token,
			"-H", "Content-Type: application/json",
			url,
		},
		on_exit = function(j, return_val)
			if return_val ~= 0 then
				vim.schedule(function()
					vim.notify("API request failed: " .. url, vim.log.levels.ERROR)
				end)
				return
			end

			vim.schedule(function()
				local ok, data = pcall(vim.fn.json_decode, j:result())
				if not ok or type(data) ~= "table" then
					vim.notify("Failed to decode JSON", vim.log.levels.ERROR)
					return
				end
				callback(data.results)
			end)
		end,
	}):start()
end

M.fetch_note_contents = function(noteId, connectionOptions, callback)
	local url = connectionOptions.baseURL .. "/etapi/notes/" .. noteId .. "/content"
	Job:new({
		command = "curl",
		args = { "-s", "-H", "Content-Type: text/plain", "-H", "Authorization: " .. connectionOptions.token, url },
		on_exit = function(j, return_val)
			if return_val ~= 0 then
				vim.schedule(function()
					vim.notify("API request failed: " .. url, vim.log.levels.ERROR)
				end)
				return
			end

			local result = table.concat(j:result(), "\n")
			vim.schedule(function()
				callback(result)
			end)
		end,
	}):start()
end

M.update_note = function(noteId, content, connectionOptions, callback)
	local url = string.format("%s/etapi/notes/%s/content", connectionOptions.baseURL, noteId)
	Job:new({
		command = "curl",
		args = { "-s",
			"-X", "PUT",
			"-H", "Content-Type: text/plain",
			"-H", "Authorization: " .. connectionOptions.token,
			"-d", content, url
		},
		on_exit = function(j, return_val)
			if return_val ~= 0 then
				vim.schedule(function()
					vim.notify("API request failed: " .. url, vim.log.levels.ERROR)
					callback(false)
				end)
			end

			vim.schedule(function()
				vim.notify("API request succeeded: " .. url, vim.log.levels.ERROR)
				callback(true)
			end)
		end,
	}):start()
end

return M

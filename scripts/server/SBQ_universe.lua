
function init()
	local defaultConfig = {
		overrideSettings = {},
		invalidSettings = {}
	}
	root.setConfigurationPath("sbq", sb.jsonMerge(defaultConfig, root.getConfigurationPath("sbq") or {}))
end
function update(dt)

end
function uninit()

end

function acceptConnection(clientId)

end
function doDisconnection(clientId)

end

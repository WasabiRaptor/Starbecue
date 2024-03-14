local cdt = 0
function update()
	cdt = cdt + script.updateDt()
	if cdt >= _ENV.metagui.cfg.lifetime then
		pane.dismiss()
	end
end

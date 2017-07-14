local tableStyle =
{
	horizontal_spacing = 10,
	vertical_spacing = 10,
}

heliSelectionGui =
{
	prefix = "heli_heliSelectionGui_",

	new = function(p)
		obj = 
		{
			valid = true,
			player = p,

			guiElems = 
			{
				parent = p.gui.left,
			},

			curCamID = 0,
		}

		for k,v in pairs(heliSelectionGui) do
			obj[k] = v
		end

		obj:buildGui()

		return obj
	end,

	destroy = function(self)
		self.valid = false
	
		if self.guiElems.root then
			self.guiElems.root.destroy()
		end
	end,

	OnTick = function(self)
		self:updateCamPositions()
	end,

	OnGuiClick = function(self, e)
		local name = e.element.name

		if name:match("^" .. self.prefix .. "cam_%d+$") then
			self:OnCamClicked(e)
		
		elseif name == self.prefix .. "btn_toPlayer" then
			if self.selectedCam then
				if not global.heliControllers then global.heliControllers = {} end
				table.insert(global.heliControllers, heliController.new(self.player, self.selectedCam.heli, self.player.position))
			end
		elseif name == self.prefix .. "btn_stop" then
			if self.selectedCam and self.selectedCam.heliController then
				self.selectedCam.heliController:stopAndDestroy()
			end
		end
	end,

	OnHeliBuilt = function(self, heli)
		local flow, cam = self:buildCam(self.guiElems.camTable, self.curCamID, heli.baseEnt.position, 0.3, false, false)

		table.insert(self.guiElems.cams,
		{
			flow = flow,
			cam = cam,
			heli = heli,
			ID = self.curCamID,
		})

		self.curCamID = self.curCamID + 1
	end,

	OnHeliRemoved = function(self, heli)
		for i, curCam in ipairs(self.guiElems.cams) do
			if curCam.heli == heli then
				if curCam == self.selectedCam then
					self.selectedCam = nil
				end

				curCam.flow.destroy()
				table.remove(self.guiElems.cams, i)
				break
			end
		end
	end,

	OnHeliControllerCreated = function(self, controller)
		local cam = searchInTable(self.guiElems.cams, controller.heli, "heli")
		if cam then
			print("set")
			cam.heliController = controller
			self:setCamStatus(cam, cam == self.selectedCam, true)
		end
	end,

	OnHeliControllerDestroyed = function(self, controller)
		local cam = searchInTable(self.guiElems.cams, controller, "heliController")
		if cam then
			cam.heliController = nil
			self:setCamStatus(cam, cam == self.selectedCam, false)
		end
	end,

	OnCamClicked = function(self, e)
		local p = game.players[e.player_index]
		local camID = tonumber(e.element.name:match("%d+"))

		if e.button == defines.mouse_button_type.left then
			local cam = self.guiElems.cams[self:getCamIndexById(camID)]
			self:setCamStatus(cam, true, cam.heliController)

		elseif e.button == defines.mouse_button_type.right then
			local zoomMax = 1.26
			local zoomMin = 0.2
			local zoomDelta = 0.333

			if e.shift then
				e.element.zoom = e.element.zoom * (1 - zoomDelta)
				if e.element.zoom < zoomMin then
					e.element.zoom = zoomMax
				end
			else
				e.element.zoom = e.element.zoom * (1 + zoomDelta)
				if e.element.zoom > zoomMax then
					e.element.zoom = zoomMin
				end
			end
		end
	end,

	getCamIndexById = function(self, ID)
		for i, curCam in ipairs(self.guiElems.cams) do
			if curCam.ID == ID then return i end
		end
	end,

	updateCamPositions = function(self)
		for k, curCam in pairs(self.guiElems.cams) do
			curCam.cam.position = curCam.heli.baseEnt.position
		end
	end,

	setCamStatus = function(self, cam, isSelected, hasController)
		local flow = cam.flow

		local pos = cam.cam.position
		local zoom = cam.cam.zoom

		flow.clear()

		cam.cam = self:buildCamInner(flow, cam.ID, pos, zoom, isSelected, cam.heliController)

		if isSelected then
			if self.selectedCam and self.selectedCam ~= cam then
				self:setCamStatus(self.selectedCam, false, hasController)
			end
			self.selectedCam = cam
		else
			if self.selectedCam and self.selectedCam == cam then
				self.selectedCam = nil
			end
		end
	end,

	buildCamInner = function(self, parent, ID, position, zoom, isSelected, hasController)
		local camParent = parent
		local padding = 8
		local size = 210
		local camSize = size - padding

		if isSelected or hasController then
			local sprite = ""

			--if isSelected and hasController then
			--	sprite = "heli_gui_selectedControlled"
			if isSelected then
				sprite = "heli_gui_selected"
			--elseif hasController then
			--	sprite = "heli_gui_controlled"
			end

			camParent = camParent.add
			{
				type = "sprite",
				name = self.prefix .. "camBox_selected_" .. tostring(ID),
				sprite = sprite,
			}
			camParent.style.minimal_width = size
			camParent.style.minimal_height = size
			camParent.style.maximal_width = size
			camParent.style.maximal_height = size
		end

		--[[
		if hasController then
			camParent = camParent.add
			{
				type = "sprite",
				name = self.prefix .. "camBox_controlled_" .. tostring(ID),
				sprite = "heli_gui_controlled",
			}
			local pa = padding/4

			camParent.style.minimal_width = size - pa
			camParent.style.minimal_height = size - pa
			camParent.style.maximal_width = size - pa
			camParent.style.maximal_height = size - pa


			camParent.style.top_padding = pa
			camParent.style.left_padding = pa

			padding = padding - pa
		end
		]]

		local cam = camParent.add
		{
			type = "camera",
			name = self.prefix .. "cam_" .. tostring(ID),
			position = position,
			zoom = zoom,
		}
		cam.style.top_padding = padding
		cam.style.left_padding = padding

		cam.style.minimal_width = camSize
		cam.style.minimal_height = camSize

		if hasController then
			local label = cam.add
			{
				type = "label",
				caption = "  CONTROLLED",
			}

			label.style.font = "pixelated"
			label.style.font_color = {r = 1, g = 0, b = 0}
		end

		return cam
	end,

	buildCam = function(self, parent, ID, position, zoom, isSelected, hasController)
		local flow = parent.add
		{
			type = "flow",
			name = self.prefix .. "camFlow_" .. tostring(ID),
		}

		flow.style.minimal_width = 214
		flow.style.minimal_height = 214
		flow.style.maximal_width = 214
		flow.style.maximal_height = 214

		return flow, self:buildCamInner(flow, ID, position, zoom, isSelected, hasController)
	end,

	buildGui = function(self, selectedIndex)
		local p = self.player
		local els = self.guiElems

		els.root = els.parent.add
		{
			type = "frame",
			name = self.prefix .. "rootFrame",
			caption = "Helicopter remote control",
			style = "frame_style",
			direction = "vertical",
		}

		els.root.style.maximal_width = 1000
		els.root.style.maximal_height = 700

			els.buttonFlow = els.root.add
			{
				type = "flow",
				name = self.prefix .. "btnFlow",
			}
			els.buttonFlow.style.left_padding = 7

				els.btnToPlayer = els.buttonFlow.add
				{
					type = "sprite-button",
					name = self.prefix .. "btn_toPlayer",
					sprite = "heli_to_player",
					style = mod_gui.button_style,
				}

				els.btnToMap = els.buttonFlow.add
				{
					type = "sprite-button",
					name = self.prefix .. "btn_toMap",
					sprite = "heli_to_map",
					style = mod_gui.button_style,
				}

				els.btnToPad = els.buttonFlow.add
				{
					type = "sprite-button",
					name = self.prefix .. "btn_toPad",
					sprite = "heli_to_pad",
					style = mod_gui.button_style,
				}

				els.btnStop = els.buttonFlow.add
				{
					type = "sprite-button",
					name = self.prefix .. "btn_stop",
					sprite = "heli_stop",
					style = mod_gui.button_style,
				}

			els.scrollPane = els.root.add
			{
				type = "scroll-pane",
				name = self.prefix .. "scroller",
			}

			els.scrollPane.style.maximal_width = 1000
			els.scrollPane.style.maximal_height = 600

				els.camTable = els.scrollPane.add
				{
					type = "table",
					name = self.prefix .. "camTable",
					colspan = 4,
				}
				applyStyle(els.camTable, tableStyle)

					els.cams ={}
					self.curCamID = 0
					for k, curHeli in pairs(global.helis) do
						--if curHeli.baseEnt.passenger then printA(curHeli.baseEnt.passenger.player.name) end
						if curHeli.baseEnt.force == self.player.force and 
							(curHeli.baseEnt.passenger == nil or curHeli.hasRemoteController or
								(curHeli.baseEnt.passenger.player and curHeli.baseEnt.passenger.player.name == self.player.name)) then

							local controller = searchInTable(global.heliControllers, curHeli, "heli")
							local flow, cam = self:buildCam(els.camTable, self.curCamID, curHeli.baseEnt.position, 0.3, false, curHeli.hasRemoteController)

							table.insert(els.cams,
							{
								flow = flow,
								cam = cam,
								heli = curHeli,
								heliController = controller,
								ID = self.curCamID,
							})

							self.curCamID = self.curCamID + 1
						end
					end
	end,
}
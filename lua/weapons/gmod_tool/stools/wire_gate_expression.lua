--Written by Syranide, ported to GM13 by AndrewEathan

TOOL.Category = "Chips, Gates"
TOOL.Name = "Chip - Expression"
TOOL.Command = nil
TOOL.ConfigName = ""
TOOL.Tab = "Wire"
local wire_gate_expression_folder = ""
local tmppnl = nil
function StringExplode(sep, str)
	local lines = {}
	
	while str and str ~= "" do
		local pos = string.find(str, sep)
		if pos == nil then
			table.insert(lines, str)
			break
		end
		
		if pos > 1 then
			table.insert(lines, string.sub(str, 1, pos - 1))				
		else
			table.insert(lines, "")
		end
		
		str = string.sub(str, pos + 1)
	end
	
	return lines
end

function WireExpressionGetLines(player)
	local lines = {}
	local blank = 0
	for i = 1,60 do
		local line = player:GetInfo('wire_gate_expression_line' .. i)
		if line and line ~= "" then
			while blank > 0 do table.insert(lines, "") blank = blank - 1 end
			table.insert(lines, line)
		else
			blank = blank + 1
		end
	end
	return lines
end

function MakeWireGateExpressionParser(lines, inputs, outputs)
	local code = ""
	for _,line in ipairs(lines) do
		local pos = string.find(line, '#')
		if pos then line = string.sub(line, 0, pos - 1) end

		code = code .. line .. "\n"
	end
	return WireGateExpressionParser:New(code, inputs, outputs)
end

if CLIENT then
	--net.Start("createe1ent",true)
    language.Add("Tool.wire_gate_expression.name", "Expression Gate Tool (Wire)")
    language.Add("Tool.wire_gate_expression.desc", "Spawns an expression gate for use with the wire system.")
	TOOL.Information = {
		{ name = "left_0", stage = 0, text = "Primary: Create/Update Expression Gate" },
		{ name = "right_0", stage = 0, text = "Secondary: Load Expression Gate" },
		{ name = "reload_0", stage = 0, text = "Reload: Reset Variables" },
	}
    for _, info in pairs(TOOL.Information) do
		language.Add("Tool.wire_gate_expression." .. info.name, info.text)
	end
	language.Add("sboxlimit_wire_gate_expression", "You've hit expression gates limit!")
	language.Add("undone_wiregateexpression",      "Undone Wire Expression Gate")
	language.Add("#Hint_wire_gate_expression_saved","Succesfully saved file!")
	TOOL.Wire_ToolMenuIcon = "icon16/wrench.png"
end

if SERVER then
	CreateConVar('sbox_maxwire_gate_expressions', 20)
end

TOOL.ClientConVar["model"]     = "models/cheeze/wires/cpu.mdl"
TOOL.ClientConVar["filename"]  = ""
TOOL.ClientConVar["label"]     = ""
TOOL.ClientConVar["inputs"]    = ""
TOOL.ClientConVar["outputs"]   = ""
TOOL.ClientConVar["hintrev"]   = 0

for i = 1,60 do
	TOOL.ClientConVar["line" .. i] = ""
end

cleanup.Register("wire_gate_expressions")

function TOOL:LeftClick(trace)
	if trace.Entity:IsPlayer() then return false end
	--if CLIENT then return true end
	
	local player = self:GetOwner()
	
	local name = self:GetClientInfo("label")
	local inputs = self:GetClientInfo("inputs")
	local outputs = self:GetClientInfo("outputs")
	
	local lines = WireExpressionGetLines(player)
	
	if (trace.Entity:IsValid() && trace.Entity:GetClass() == "gmod_wire_expression" && trace.Entity.player == player) then
		local parser = VerifyWireGateExpression(player, lines, inputs, outputs)
		if !parser then return false end
		SetupWireGateExpression(trace.Entity, parser, name, lines, inputs, outputs)
		return true
	end
	
	if !self:GetSWEP():CheckLimit("wire_gate_expressions") then return false end
	if !util.IsValidModel(self:GetClientInfo("model")) then return false end
	if !util.IsValidProp(self:GetClientInfo("model")) then return false end
	function SetupWireGateExpression(entity, parser, name, lines, inputs, outputs)
		entity.GateName =    name
		entity.GateLines =   lines
		entity.GateInputs =  inputs
		entity.GateOutputs = outputs
		
		entity:Setup(name, parser)
	end
	
	function VerifyWireGateExpression(player, lines, inputs, outputs)
		local parser = MakeWireGateExpressionParser(lines, inputs, outputs)
		if !parser:GetError() then
			return parser
		else
			player:SendLua('wire_gate_expression_status = "' .. parser:GetError() .. '"')
			player:SendLua('WireGateExpressionRebuildCPanel()')
			player:SendLua('GAMEMODE:AddNotify("' .. parser:GetError() .. '", NOTIFY_ERROR, 7)')
			return
		end
	end
	function MakeWireGateExpression_lc(player, ang, pos, model, name, lines, inputs, outputs)
		if !player:CheckLimit("wire_gate_expressions") then return false end
		if CLIENT then return false end
		
		local parser = VerifyWireGateExpression(player, lines, inputs, outputs)
		if !parser then return false end
		
		
		local entity = ents.Create("gmod_wire_expression")
		if !entity:IsValid() then return false end
		
		entity:SetModel(model)
		entity:SetAngles(ang)
		entity:SetPos(pos)
		entity:Spawn()
		entity:SetPlayer(player)

		SetupWireGateExpression(entity, parser, name, lines, inputs, outputs)
		
		table.Merge(entity:GetTable(), { player = player })
		player:AddCount("wire_gate_expressions", entity)
		return entity
		
		--my shitty attempt at trying to fix the ents.Create error
		--since it's apparently a serverside function and not clientside
		--feel free to tell me if you know how to fix it 
		
		--okay i figured out that it runs on both client and server
		
		--[[net.WriteEntity(player)
		net.WriteAngle(ang)
		net.WriteVector(pos)
		net.WriteString(model)
		net.WriteString(name)
		net.WriteTable(lines)
		net.WriteString(inputs)
		net.WriteString(outputs)
		net.SendToServer()]]--
	end

	local Model = self:GetClientInfo("model")
	local Ang = trace.HitNormal:Angle()
	Ang.pitch = Ang.pitch + 90
	
	wire_gate = MakeWireGateExpression_lc(player, Ang, trace.HitPos, Model, name, lines, inputs, outputs)
	if !wire_gate then return true end
	
	--wire_gate:GetPhysicsObject():EnableMotion(false)
	wire_gate:SetPos(trace.HitPos - trace.HitNormal * wire_gate:OBBMins().z)
	local constraint = WireLib.Weld(wire_gate, trace.Entity, trace.PhysicsBone, true)
	
	undo.Create("WireGateExpression")
	undo.AddEntity(wire_gate)
	undo.SetPlayer(player)
	undo.AddEntity(constraint)
	undo.Finish()

	player:AddCleanup("wire_gate_expressions", wire_gate)

	return true
end

function TOOL:RightClick(trace)
	if trace.Entity:IsPlayer() then return false end
	if CLIENT then return true end

	local player = self:GetOwner()

	if (trace.Entity:IsValid() && trace.Entity:GetClass() == "gmod_wire_expression" && trace.Entity.player == player) then
		player:ConCommand('wire_gate_expression_filename ""')
		player:ConCommand('wire_gate_expression_label "' .. trace.Entity.GateName .. '"')
		player:ConCommand('wire_gate_expression_inputs "' .. trace.Entity.GateInputs .. '"')
		player:ConCommand('wire_gate_expression_outputs "' .. trace.Entity.GateOutputs .. '"')
		
		for i = 1,60 do
			local line = trace.Entity.GateLines[i]
			if (line and line ~= "") then
				player:SendLua('LocalPlayer():ConCommand("wire_gate_expression_line' .. i .. ' \\\"' .. line .. '\\\"")')
			else
				player:ConCommand('wire_gate_expression_line' .. i .. ' ""')
			end
		end
		
		player:SendLua('wire_gate_expression_filename = "(fetched expression)"')
		player:SendLua('wire_gate_expression_status = "Successfully fetched \\"' .. trace.Entity.GateName .. '\\""')
		player:SendLua('wire_gate_expression_label = "' .. trace.Entity.GateName .. '"')
		player:SendLua('wire_gate_expression_inputs = "' .. trace.Entity.GateInputs .. '"')
		player:SendLua('wire_gate_expression_outputs = "' .. trace.Entity.GateOutputs .. '"')
		player:SendLua('WireGateExpressionRebuildCPanel()')
		return true
	else
		return false
	end
end

function TOOL:Reload(trace)
	if trace.Entity:IsPlayer() then return false end
	if CLIENT then return true end

	local player = self:GetOwner()
	if (trace.Entity:IsValid() && trace.Entity:GetClass() == "gmod_wire_expression" && trace.Entity.player == player) then		
		trace.Entity:Reset()
		return true
	else
		return false
	end
end

function TOOL:UpdateGhostWireGateExpression(ent, player)
	if !ent or !ent:IsValid() then return end

	local trace = util.TraceLine(util.GetPlayerTrace(player, player:GetAimVector()))
	if !trace.Hit then return end

	if (trace.Entity && trace.Entity:GetClass() == "gmod_wire_expression" || trace.Entity:IsPlayer()) then
		ent:SetNoDraw(true)
	else 
		local Ang = trace.HitNormal:Angle()
		Ang.pitch = Ang.pitch + 90

		ent:SetPos(trace.HitPos - trace.HitNormal * ent:OBBMins().z)
		ent:SetAngles(Ang)
		ent:SetNoDraw(false)
	end
end

function TOOL:Think()
	if !self.GhostEntity || !self.GhostEntity:IsValid() || !self.GhostEntity:GetModel() || self.GhostEntity:GetModel() != self:GetClientInfo("model") then
		self:MakeGhostEntity(self:GetClientInfo("model"), Vector(0, 0, 0), Angle(0, 0, 0))
	end

	self:UpdateGhostWireGateExpression(self.GhostEntity, self:GetOwner())
end

function TOOL.BuildCPanel(panel)
	print("rebuilt")
	WireGateExpressionRebuildCPanel(panel)
	--WireGateExpressionDoRebuildCPanel(panel)
end

if SERVER then
	function SetupWireGateExpression(entity, parser, name, lines, inputs, outputs)
		entity.GateName =    name
		entity.GateLines =   lines
		entity.GateInputs =  inputs
		entity.GateOutputs = outputs
		
		entity:Setup(name, parser)
	end
	
	function VerifyWireGateExpression(player, lines, inputs, outputs)
		local parser = MakeWireGateExpressionParser(lines, inputs, outputs)
		if !parser:GetError() then
			return parser
		else
			player:SendLua('wire_gate_expression_status = "' .. parser:GetError() .. '"')
			player:SendLua('WireGateExpressionRebuildCPanel()')
			player:SendLua('GAMEMODE:AddNotify("' .. parser:GetError() .. '", NOTIFY_ERROR, 7)')
			return
		end
	end
	function MakeWireGateExpression(player, ang, pos, model, name, lines, inputs, outputs)
		if !player:CheckLimit("wire_gate_expressions") then return false end
		
		local parser = VerifyWireGateExpression(player, lines, inputs, outputs)
		if !parser then return false end
		
		local entity = ents.Create("gmod_wire_expression")
		if !entity:IsValid() then return false end
		
		entity:SetModel(model)
		entity:SetAngles(ang)
		entity:SetPos(pos)
		entity:Spawn()
		entity:SetPlayer(player)

		SetupWireGateExpression(entity, parser, name, lines, inputs, outputs)
		
		table.Merge(entity:GetTable(), { player = player })
		player:AddCount("wire_gate_expressions", entity)
		return entity
	end
	--[[util.AddNetworkString("createe1ent")
	net.Receive("createe1ent",function()
		print("Creating expression...")
		local plyent = net.ReadEntity()
		local angnet = net.ReadAngle()
		local posnet = net.ReadVector()
		local modelnet = net.ReadString()
		local namenet = net.ReadString()
		local linesnet = net.ReadTable()
		local inputsnet = net.ReadString()
		local outputsnet = net.ReadString()
		MakeWireGateExpression(plyent,angnet,posnet,modelnet,namenet,linesnet,inputsnet,outputsnet)
	end)]]--
	
	duplicator.RegisterEntityClass("gmod_wire_expression", MakeWireGateExpression, "Ang", "Pos", "Model", "GateName", "GateLines", "GateInputs", "GateOutputs")
end

if CLIENT then
	function WireGateExpressionUpdateFilelist()
		local fileindex, foldindex = 1, 1
		local filelist, filemap = {}, {}
		local foldlist, foldmap = {}, {}
		if !file.Exists("expression1/" .. wire_gate_expression_folder,"DATA") then
			print("Expression1 folder missing! Creating folder...")
			file.CreateDir("expression1")
		end
		if (file.Exists("expression1/" .. wire_gate_expression_folder,"DATA") && file.IsDir("expression1/","DATA")) then
		local files,directories = file.Find("expression1/" .. wire_gate_expression_folder .. "/*","DATA")
			for key,value in pairs(files) do
				if (file.IsDir("expression1/" .. wire_gate_expression_folder .. value,"DATA")) then
					foldlist[value] = { wire_gate_expression_folder_cl = foldindex }
					foldmap[foldindex] = value
					foldindex = foldindex + 1
				elseif (string.sub(value, -4) == ".txt") then
					filelist[string.sub(value, 1, -5)] = { wire_gate_expression_select_cl = fileindex }
					filemap[fileindex] = string.sub(value, 1, -5)
					fileindex = fileindex + 1
				end
			end
			for key,value in pairs(directories) do
				if (file.IsDir("expression1/" .. wire_gate_expression_folder .. value,"DATA")) then
					foldlist[value] = { wire_gate_expression_folder_cl = foldindex }
					foldmap[foldindex] = value
					foldindex = foldindex + 1
				elseif (string.sub(value, -4) == ".txt") then
					filelist[string.sub(value, 1, -5)] = { wire_gate_expression_select_cl = fileindex }
					filemap[fileindex] = string.sub(value, 1, -5)
					fileindex = fileindex + 1
				end
			end
		end
		
		wire_gate_expression_filelist = filelist
		wire_gate_expression_filemap = filemap
		wire_gate_expression_foldlist = foldlist
		wire_gate_expression_foldmap = foldmap
		WireGateExpressionRebuildCPanel()
	end

	function WireGateExpressionPanelFoldUp(player, command, args)
		local lasthit
		local pos = 1
		while pos <= string.len(wire_gate_expression_folder) do
			if string.sub(wire_gate_expression_folder, pos, pos) == "/" then lasthit = pos end
			pos = pos + 1
		end
		
		if lasthit and lasthit > 1 then
			wire_gate_expression_folder = string.sub(wire_gate_expression_folder, 1, lasthit - 1)
		else
			wire_gate_expression_folder = ""
		end
		
		print(wire_gate_expression_folder)
		
		WireGateExpressionUpdateFilelist()
	end

	concommand.Add("wire_gate_expression_foldup_cl", WireGateExpressionPanelFoldUp)

	function WireGateExpressionPanelFolder(player, command, args)
		wire_gate_expression_folder = wire_gate_expression_foldmap[tonumber(args[1])]
		if !wire_gate_expression_folder then wire_gate_expression_folder = "" end
		print(wire_gate_expression_folder)
		WireGateExpressionUpdateFilelist()
	end

	concommand.Add("wire_gate_expression_folder_cl", WireGateExpressionPanelFolder)

	function WireGateExpressionPanelValidate(player, command, args)
		local inputs = player:GetInfo("wire_gate_expression_inputs")
		local outputs = player:GetInfo("wire_gate_expression_outputs")
		local lines = WireExpressionGetLines(player)
		
		local parser = MakeWireGateExpressionParser(lines, inputs, outputs)
		local status = parser:GetError()

		if !status then status = "Successfully validated" end
		wire_gate_expression_status = status
		notification.AddLegacy(status,NOTIFY_GENERIC,3)
		
		WireGateExpressionRebuildCPanel()
	end

	concommand.Add("wire_gate_expression_validate_cl", WireGateExpressionPanelValidate)

	function WireGateExpressionLoad(filename)
		local player = LocalPlayer()

		print("expression1/" .. wire_gate_expression_folder .. "/" .. filename .. ".txt")
		local code
		if file.Exists("expression1/" .. wire_gate_expression_folder .. "/" .. filename .. ".txt","DATA") then
			code = file.Read("expression1/" .. wire_gate_expression_folder .. "/" .. filename .. ".txt","DATA")
			if code == nil then
				notification.AddLegacy("Could not load \"" .. filename .. "\"",NOTIFY_GENERIC,3)
				return
			end
		else
			notification.AddLegacy("Unable to find \"" .. filename .. "\"",NOTIFY_GENERIC,3)
			return
		end
		
		local lines = StringExplode("\n", code)
		
		wire_gate_expression_filename = filename
		player:ConCommand('wire_gate_expression_filename "' .. filename .. '"')
		
		if lines[1] and string.sub(lines[1], 1, 2) == "N@" then
			str = string.sub(table.remove(lines, 1), 3)
			player:ConCommand('wire_gate_expression_label "' .. str .. '"')
			wire_gate_expression_label = str
		else
			player:ConCommand('wire_gate_expression_label "' .. filename .. '"')
			wire_gate_expression_label = filename
		end
		
		if lines[1] and string.sub(lines[1], 1, 2) == "I@" then
			str = string.sub(table.remove(lines, 1), 3)
			player:ConCommand('wire_gate_expression_inputs "' ..str .. '"')
			wire_gate_expression_inputs = str
		else
			player:ConCommand('wire_gate_expression_inputs ""')
			wire_gate_expression_inputs = ""
		end
		
		if lines[1] and string.sub(lines[1], 1, 2) == "O@" then
			str = string.sub(table.remove(lines, 1), 3)
			player:ConCommand('wire_gate_expression_outputs "' .. str .. '"')
			wire_gate_expression_outputs = str
		else
			player:ConCommand('wire_gate_expression_outputs ""')
			wire_gate_expression_outputs = ""
		end
		
		for i,line in ipairs(lines) do
			player:ConCommand('wire_gate_expression_line' .. i .. ' "' .. line .. '"')
		end
		
		for i = #lines+1,60 do
			player:ConCommand('wire_gate_expression_line' .. i .. ' ""')
		end
	
		notification.AddLegacy("Successfully loaded \"" .. filename .. "\"",NOTIFY_GENERIC,3)
		WireGateExpressionRebuildCPanel()
	end

	function WireGateExpressionPanelLoad(player, command, args)
		if (!player:IsValid() or !player:IsPlayer()) then return end

		WireGateExpressionLoad(player:GetInfo('wire_gate_expression_filename'))
	end

	concommand.Add("wire_gate_expression_load_cl", WireGateExpressionPanelLoad)

	function WireGateExpressionPanelSave(player, command, args)
		print("saving!")
		local str = ""
		local name = player:GetInfo('wire_gate_expression_label')
		local inputs = player:GetInfo('wire_gate_expression_inputs')
		local outputs = player:GetInfo('wire_gate_expression_outputs')
		
		if name and name ~= "" then str = str .. "N@" .. name .. "\n" end		
		if inputs and inputs ~= "" then str = str .. "I@" .. inputs .. "\n" end
		if outputs and outputs ~= "" then str = str .. "O@" .. outputs .. "\n" end
		
		local lines = WireExpressionGetLines(player)
		for _,line in ipairs(lines) do str = str .. line .. "\n" end
		
		local filename = player:GetInfo('wire_gate_expression_filename')
		
		wire_gate_expression_filename = filename
		wire_gate_expression_label = name
		wire_gate_expression_inputs = inputs
		wire_gate_expression_outputs = outputs
		
		file.Write("expression1/"..filename .. ".txt", str)
		if file.Exists("expression1/" .. filename .. ".txt","DATA") then
			wire_gate_expression_status = "Successfully saved \"" .. filename .. "\""
			notification.AddLegacy("Successfully saved \"" .. filename .. "\"",NOTIFY_GENERIC,3)
		else
			wire_gate_expression_status = "Could not save \"" .. filename .. "\""
			notification.AddLegacy("Could not save \"" .. filename .. "\"",NOTIFY_GENERIC,3)
		end
		WireGateExpressionRebuildCPanel()
	end

	concommand.Add("wire_gate_expression_save_cl", WireGateExpressionPanelSave)

	function WireGateExpressionPanelDelete(player, command, args)
		local filename = player:GetInfo('wire_gate_expression_filename')
		if file.Exists("expression1/" .. filename .. ".txt","DATA") then
			file.Delete("expression1/" .. filename .. ".txt","DATA")
			if file.Exists("expression1/" .. filename .. ".txt","DATA") then
				wire_gate_expression_status = "Could not delete \"" .. filename .. "\""
				notification.AddLegacy("Could not delete \"" .. filename .. "\"",NOTIFY_GENERIC,3)
			else
				wire_gate_expression_status = "Successfully deleted \"" .. filename .. "\""
				notification.AddLegacy("Successfully deleted \"" .. filename .. "\"",NOTIFY_GENERIC,3)
			end
		else
			wire_gate_expression_status = "Unable to find \"" .. filename .. "\""
			notification.AddLegacy("Unable to find \"" .. filename .. "\"",NOTIFY_GENERIC,3)
		end
		
		WireGateExpressionRebuildCPanel()
	end

	concommand.Add("wire_gate_expression_delete_cl", WireGateExpressionPanelDelete)

	function WireGateExpressionPanelSelect(player, command, args)
		WireGateExpressionLoad(wire_gate_expression_filemap[tonumber(args[1])])
	end

	concommand.Add("wire_gate_expression_select_cl", WireGateExpressionPanelSelect)

	function WireGateExpressionPanelRefresh(player, command, args)
		WireGateExpressionUpdateFilelist()
		WireGateExpressionRebuildCPanel()
	end

	concommand.Add("wire_gate_expression_refresh_cl", WireGateExpressionPanelRefresh)

	function WireGateExpressionPanelProcess(player, command, args)
		local lines = {}
		for i = 1,60 do
			local line = player:GetInfo('wire_gate_expression_line' .. i)
			if line and line ~= "" then
				local split = StringExplode("\\", line)
				for _,value in ipairs(split) do
					table.insert(lines, value)
				end
			end
		end
		
		for i,line in ipairs(lines) do
			player:ConCommand('wire_gate_expression_line' .. i .. ' "' .. line .. '"')
		end
		
		for i = #lines+1,60 do
			player:ConCommand('wire_gate_expression_line' .. i .. ' ""')
		end
		
		WireGateExpressionRebuildCPanel()
	end

	concommand.Add("wire_gate_expression_process_cl", WireGateExpressionPanelProcess)

	function WireGateExpressionPanelEdit(player, command, args)
		wire_gate_expression_state = 1
		WireGateExpressionRebuildCPanel()
	end
	
	concommand.Add("wire_gate_expression_edit_cl", WireGateExpressionPanelEdit)

	function WireGateExpressionPanelBrowse(player, command, args)
		wire_gate_expression_state =   0
		wire_gate_expression_label =   player:GetInfo('wire_gate_expression_label')
		wire_gate_expression_inputs =  player:GetInfo('wire_gate_expression_inputs')
		wire_gate_expression_outputs = player:GetInfo('wire_gate_expression_outputs')
		
		WireGateExpressionRebuildCPanel()
	end

	concommand.Add("wire_gate_expression_browse_cl", WireGateExpressionPanelBrowse)

	function WireGateExpressionPanelNew(player, command, args)
		wire_gate_expression_state =    1
		wire_gate_expression_filename = ""
		wire_gate_expression_label =    ""
		wire_gate_expression_inputs =   ""
		wire_gate_expression_outputs =  ""
		wire_gate_expression_status =   "New expression created"
		notification.AddLegacy("New expression created",NOTIFY_GENERIC,3)
		
		player:ConCommand('wire_gate_expression_filename ""')
		player:ConCommand('wire_gate_expression_label ""')
		player:ConCommand('wire_gate_expression_inputs ""')
		player:ConCommand('wire_gate_expression_outputs ""')
		
		for i = 1,60 do
			player:ConCommand('wire_gate_expression_line' .. i .. ' ""')
		end
		WireGateExpressionRebuildCPanel()
	end

	concommand.Add("wire_gate_expression_new_cl", WireGateExpressionPanelNew)

	function WireGateExpressionRebuildCPanel(panel)
		if panel then
			WireGateExpressionDoRebuildCPanel(panel)
		else
			panel = controlpanel.Get("wire_gate_expression")
			if panel then
			    WireGateExpressionDoRebuildCPanel(panel)
			end

			panel = controlpanel.Get("wiretab_wire_gate_expression")
			if panel then
			    WireGateExpressionDoRebuildCPanel(panel)
			end
		end
	end
	
	function WireGateExpressionHide(player, command, args)
		wire_gate_expression_hintrev = 1
		player:ConCommand('wire_gate_expression_hintrev 1')
		WireGateExpressionRebuildCPanel();
	end

	concommand.Add("wire_gate_expression_hide_cl", WireGateExpressionHide)


	function WireGateExpressionDoRebuildCPanel(panel)
		if wire_gate_expression_state == nil then
			wire_gate_expression_state =      0
			wire_gate_expression_filename =   GetConVarString('wire_gate_expression_filename')
			wire_gate_expression_label =      GetConVarString('wire_gate_expression_label')
			wire_gate_expression_inputs =     GetConVarString('wire_gate_expression_inputs')
			wire_gate_expression_outputs =    GetConVarString('wire_gate_expression_outputs')
			wire_gate_expression_basefolder = "ExpressionGate"
			wire_gate_expression_folder =     ""
			wire_gate_expression_status =     "Previous expression resumed"
			wire_gate_expression_hintrev =    GetConVarNumber('wire_gate_expression_hintrev')
			WireGateExpressionUpdateFilelist()

			if !wire_gate_expression_filename then wire_gate_expression_filename = "" end
			if !wire_gate_expression_label    then wire_gate_expression_label =    "" end
			if !wire_gate_expression_inputs   then wire_gate_expression_inputs =   "" end
			if !wire_gate_expression_outputs  then wire_gate_expression_outputs =  "" end
			if !wire_gate_expression_status   then wire_gate_expression_status =   "" end
		end
	
		panel:Clear()
		
		panel:AddControl("Header", {
			Text = "#Tool_wire_gate_expression_name",
			Description = "Written by Syranide, me@syranide.com (And ported to GM13 by AndrewEathan!)"
		})

		ModelPlug_AddToCPanel(panel, "gate", "wire_gate_expression", "Model:", nil, "Model:")
		
		if wire_gate_expression_state == 0 then
			--[[
			local configs = {
				{ 1200, 7, 19 },
				{ 1080, 5, 17 },
				{ 1050, 5, 16 },
				{ 1024, 5, 15 },
				{  768, 3,  7 },
				{  720, 3,  5 },
				{  600, 3,  8 },
				{  480, 3,  5 },
			}
			--]]
			
			local configs = {
				{ 1200, 6, 12 },
				{ 1080, 4, 10 },
				{ 1050, 4, 9  },
				{ 1024, 4, 8 },
				{  768, 6,  12 },
				{  720, 5,  11 },
				{  600, 3,  8 },
				{  480, 3,  5 },
			}

			local config = { 0, 2, 4 }
			for _,v in ipairs(configs) do
				if ScrH() >= v[1] then config = v break end
			end


			panel:AddControl("Button", {
				Text = "New Expression...",
				Name = "New Expression...",
				Command = "wire_gate_expression_new_cl"
			})
			
			panel:AddControl("Label", {
				Label = "Location:",
				Text = "                 " .. wire_gate_expression_folder .. "/",
			})
			
			panel:AddControl("Button", {
				Text = "Parent Directory",
				Name = "Parent Directory",
				Command = "wire_gate_expression_foldup_cl"
			})
			
			panel:AddControl("ListBox", {
				Label = "Folders",
				Height = config[2] * 15 + 26,
				Options = wire_gate_expression_foldlist
			})
			
			panel:AddControl("ListBox", {
				Label = "Expressions",
				Height = config[3] * 15 + 26,
				Options = wire_gate_expression_filelist
			})
			
			panel:AddControl("Button", {
				Text = "Refresh",
				Name = "Refresh",
				Command = "wire_gate_expression_refresh_cl"
			})
			
			if wire_gate_expression_filename == "" then
				panel:AddControl("Label", {
					Label = "Filename:",
					Text = "                 " .. "(new expression)",
				})
			else
				panel:AddControl("Label", {
					Label = "Filename:",
					Text = "                 " .. wire_gate_expression_filename,
				})
			end
			
			panel:AddControl("Label", {
				Label = "Label:",
				Text = "                 " .. wire_gate_expression_label,
			})

			panel:AddControl("Label", {
				Label = "Inputs:",
				Text = "                 " .. wire_gate_expression_inputs,
			})
			
			panel:AddControl("Label", {
				Label = "Outputs:",
				Text = "                 " .. wire_gate_expression_outputs,
			})
			
			panel:AddControl("Button", {
				Text = "Edit Expression...",
				Name = "Edit Expression...",
				Command = "wire_gate_expression_edit_cl"
			})

			panel:AddControl("Label", {
				Text = "              Documentation available at wiremod.com"
			})
		
			panel:AddControl("Label", {
				Text = "               Written by Syranide, me@syranide.com (And ported by AndrewEathan!)"
			})
		elseif wire_gate_expression_state == 1 then
			panel:AddControl("Button", {
				Text = "Browse Expressions...",
				Name = "Browse Expressions...",
				Command = "wire_gate_expression_browse_cl"
			})
			
			panel:AddControl("TextBox", {
				Label = "Filename:",
				Command = "wire_gate_expression_filename",
				MaxLength = 100
			})
			
			panel:AddControl("Button", {
				Text = "Load",
				Name = "Load",
				Command = "wire_gate_expression_load_cl"
			})

			panel:AddControl("Button", {
				Text = "Save",
				Name = "Save",
				Command = "wire_gate_expression_save_cl"
			})
			
			panel:AddControl("Button", {
				Text = "Delete",
				Name = "Delete",
				Command = "wire_gate_expression_delete_cl"
			})

			panel:AddControl("Label", {
				Label = "Status:",
				Text = "             " .. wire_gate_expression_status,
			})
			
			panel:AddControl("Button", {
				Text = "Validate",
				Name = "Validate",
				Command = "wire_gate_expression_validate_cl"
			})
			
			if wire_gate_expression_hintrev < 1 then
				panel:AddControl("Label", {
					Text = "             New self-awareness functionality available"
				})
				
				panel:AddControl("Label", {
					Text = "           Check out the selfaware folder for examples"
				})
				
				panel:AddControl("Label", {
					Text = "              Documentation available at wiremod.com"
				})
				
				panel:AddControl("Button", {
					Text = "                  Click here to hide this notification!",
					Name = "Hide",
					Command = "wire_gate_expression_hide_cl"
				})
			end
			
			panel:AddControl("TextBox", {
				Label = "Label:",
				Command = "wire_gate_expression_label",
				MaxLength = 40
			})
			
			panel:AddControl("TextBox", {
				Label = "Inputs:",
				Command = "wire_gate_expression_inputs",
				MaxLength = 100
			})
			
			panel:AddControl("TextBox", {
				Label = "Outputs:",
				Command = "wire_gate_expression_outputs",
				MaxLength = 100
			})
			
			panel:AddControl("Button", {
				Text = "Process (split lines with a backslash \\ into multiple rows)",
				Name = "Process",
				Command = "wire_gate_expression_process_cl"
			})
			
			for i = 1,60 do
				panel:AddControl("TextBox", {
					Label = "Line " .. i .. ":",
					Command = "wire_gate_expression_line" .. i,
					MaxLength = 100
				})
			end

			panel:AddControl("Label", {
				Text = "              Documentation available at wiremod.com"
			})
		
			panel:AddControl("Label", {
				Text = "               Written by Syranide, me@syranide.com (And ported by AndrewEathan!)"
			})
		end
	end
end

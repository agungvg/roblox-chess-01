--!strict
-- PieceBuilder: builds a chess-piece character as a welded part Model.
-- Humanoid proportions (legs / torso / arms / head) with a distinct
-- silhouette per piece type: Pawn round helmet, Knight horse head,
-- Bishop mitre slit, Rook castle top, Queen coronet, King crown.
-- All parts are welded to the torso (PrimaryPart); the server tweens the
-- torso CFrame and the whole piece follows. Nothing teleports.

local PieceData = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("PieceData"))

local PieceBuilder = {}

local GOLD = Color3.fromRGB(212, 175, 55)
local DARK_METAL = Color3.fromRGB(45, 45, 55)

local function newPart(name: string, size: Vector3, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = true
	p.CastShadow = true
	if shape ~= nil then
		p.Shape = shape
	end
	return p
end

local function weldTo(part: Part, primary: Part, offset: CFrame)
	part.CFrame = primary.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = primary
	w.Part1 = part
	w.Parent = primary
	part.Parent = primary.Parent
end

-- Head top per type, built above the torso. `topY` is the torso-top height.
local function buildHeadTop(model: Model, primary: Part, pieceType: PieceData.PieceType, color: Color3, topY: number)
	if pieceType == "Pawn" then
		-- Small round helmet: a ball + brim disc (cylinder axis is X, so the
		-- brim is sized thin on X and rotated 90 deg about Z to lie flat).
		local helm = newPart("Helmet", Vector3.new(1.1, 1.1, 1.1), color, Enum.PartType.Ball)
		weldTo(helm, primary, CFrame.new(0, topY + 0.55, 0))
		local brim = newPart("Brim", Vector3.new(0.2, 1.5, 1.5), GOLD, Enum.PartType.Cylinder)
		weldTo(brim, primary, CFrame.new(0, topY + 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)))
	elseif pieceType == "Knight" then
		-- Horse head: upright skull block, forward snout, two ears, mane.
		local skull = newPart("HorseSkull", Vector3.new(0.9, 1.3, 0.9), color)
		weldTo(skull, primary, CFrame.new(0, topY + 0.6, 0))
		local snout = newPart("Snout", Vector3.new(0.6, 0.6, 1.2), color)
		weldTo(snout, primary, CFrame.new(0, topY + 0.35, 0.75))
		local earL = newPart("EarL", Vector3.new(0.25, 0.7, 0.25), color)
		weldTo(earL, primary, CFrame.new(-0.3, topY + 1.5, 0))
		local earR = newPart("EarR", Vector3.new(0.25, 0.7, 0.25), color)
		weldTo(earR, primary, CFrame.new(0.3, topY + 1.5, 0))
		local mane = newPart("Mane", Vector3.new(0.3, 1.2, 0.9), DARK_METAL)
		weldTo(mane, primary, CFrame.new(0, topY + 0.7, -0.55))
	elseif pieceType == "Bishop" then
		-- Mitre: tall pointed cap from two wedges + a dark slit.
		local capL = Instance.new("WedgePart")
		capL.Name = "MitreL"
		capL.Size = Vector3.new(1.0, 1.4, 0.9)
		capL.Color = color
		capL.Material = Enum.Material.SmoothPlastic
		capL.Anchored = false
		capL.CanCollide = false
		weldTo(capL, primary, CFrame.new(-0.25, topY + 0.7, 0))
		local capR = Instance.new("WedgePart")
		capR.Name = "MitreR"
		capR.Size = Vector3.new(1.0, 1.4, 0.9)
		capR.Color = color
		capR.Material = Enum.Material.SmoothPlastic
		capR.Anchored = false
		capR.CanCollide = false
		weldTo(capR, primary, CFrame.new(0.25, topY + 0.7, 0) * CFrame.Angles(0, math.rad(180), 0))
		local slit = newPart("Slit", Vector3.new(0.12, 0.9, 0.95), DARK_METAL)
		weldTo(slit, primary, CFrame.new(0, topY + 0.7, 0))
	elseif pieceType == "Rook" then
		-- Castle top: drum + four crenellation blocks.
		local drum = newPart("Battlement", Vector3.new(0.6, 1.5, 1.5), color, Enum.PartType.Cylinder)
		weldTo(drum, primary, CFrame.new(0, topY + 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)))
		for _, off in ipairs({ { -0.55, -0.55 }, { 0.55, -0.55 }, { -0.55, 0.55 }, { 0.55, 0.55 } }) do
			local block = newPart("Crenel", Vector3.new(0.4, 0.5, 0.4), color)
			weldTo(block, primary, CFrame.new(off[1], topY + 0.85, off[2]))
		end
	elseif pieceType == "Queen" then
		-- Coronet: crown band + five points + orb.
		local band = newPart("Coronet", Vector3.new(0.4, 1.3, 1.3), GOLD, Enum.PartType.Cylinder)
		weldTo(band, primary, CFrame.new(0, topY + 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)))
		for i = 0, 4 do
			local angle = (i / 5) * math.pi * 2
			local px = math.cos(angle) * 0.55
			local pz = math.sin(angle) * 0.55
			local point = newPart("CoronetPoint", Vector3.new(0.22, 0.6, 0.22), GOLD)
			weldTo(point, primary, CFrame.new(px, topY + 0.65, pz))
		end
		local orb = newPart("Orb", Vector3.new(0.5, 0.5, 0.5), GOLD, Enum.PartType.Ball)
		weldTo(orb, primary, CFrame.new(0, topY + 0.75, 0))
	else -- King
		-- Crown: taller band + five points + cross on top.
		local band = newPart("Crown", Vector3.new(0.5, 1.4, 1.4), GOLD, Enum.PartType.Cylinder)
		weldTo(band, primary, CFrame.new(0, topY + 0.25, 0) * CFrame.Angles(0, 0, math.rad(90)))
		for i = 0, 4 do
			local angle = (i / 5) * math.pi * 2
			local px = math.cos(angle) * 0.6
			local pz = math.sin(angle) * 0.6
			local point = newPart("CrownPoint", Vector3.new(0.24, 0.8, 0.24), GOLD)
			weldTo(point, primary, CFrame.new(px, topY + 0.85, pz))
		end
		local crossV = newPart("CrossV", Vector3.new(0.18, 0.7, 0.18), GOLD)
		weldTo(crossV, primary, CFrame.new(0, topY + 1.35, 0))
		local crossH = newPart("CrossH", Vector3.new(0.5, 0.18, 0.18), GOLD)
		weldTo(crossH, primary, CFrame.new(0, topY + 1.35, 0))
	end
end

-- Builds the model at `at` (a CFrame whose Y is the ground top). Returns the Model.
function PieceBuilder.buildPiece(
	pieceType: PieceData.PieceType,
	rarity: PieceData.RarityName,
	mutation: string,
	at: CFrame
): Model
	local info = PieceData.TYPES[pieceType]
	local rarityInfo = PieceData.rarityInfo(rarity)
	local color = rarityInfo.color
	if mutation == "Neon" then
		color = Color3.fromRGB(120, 255, 170)
	elseif mutation == "Gold-Plated" then
		color = GOLD
	end

	local model = Instance.new("Model")
	model.Name = PieceData.pieceName(pieceType, rarity)

	-- Torso is the PrimaryPart: everything welds to it.
	local torso = newPart("Torso", Vector3.new(1.7, info.height * 0.42, 1.0), color)
	torso.Anchored = true
	torso.CFrame = at * CFrame.new(0, info.height * 0.5, 0)
	torso.Parent = model
	model.PrimaryPart = torso

	-- Legs (humanoid proportion, not a floating chess base).
	local legL = newPart("LegL", Vector3.new(0.55, info.height * 0.22, 0.6), DARK_METAL)
	weldTo(legL, torso, CFrame.new(-0.4, -info.height * 0.32, 0))
	local legR = newPart("LegR", Vector3.new(0.55, info.height * 0.22, 0.6), DARK_METAL)
	weldTo(legR, torso, CFrame.new(0.4, -info.height * 0.32, 0))

	-- Arms at the torso sides.
	local armL = newPart("ArmL", Vector3.new(0.4, info.height * 0.3, 0.4), color)
	weldTo(armL, torso, CFrame.new(-1.05, 0, 0))
	local armR = newPart("ArmR", Vector3.new(0.4, info.height * 0.3, 0.4), color)
	weldTo(armR, torso, CFrame.new(1.05, 0, 0))

	-- Round base disc the piece stands on (cylinder axis is X: thin on X,
	-- rotated 90 deg about Z so the disc lies flat).
	local base = newPart("Base", Vector3.new(0.25, 2.0, 2.0), GOLD, Enum.PartType.Cylinder)
	weldTo(base, torso, CFrame.new(0, -info.height * 0.44, 0) * CFrame.Angles(0, 0, math.rad(90)))

	buildHeadTop(model, torso, pieceType, color, info.height * 0.21)

	-- Face: two eyes on the torso front so the piece reads as a character.
	local eyeL = newPart("EyeL", Vector3.new(0.16, 0.16, 0.1), Color3.fromRGB(20, 20, 20))
	weldTo(eyeL, torso, CFrame.new(-0.35, info.height * 0.1, 0.51))
	local eyeR = newPart("EyeR", Vector3.new(0.16, 0.16, 0.1), Color3.fromRGB(20, 20, 20))
	weldTo(eyeR, torso, CFrame.new(0.35, info.height * 0.1, 0.51))

	return model
end

-- Floating label above a parade / rival piece: name, rarity + mutation, $/s, BUY price.
function PieceBuilder.attachLabel(model: Model, lines: { string }, accent: Color3)
	local primary = model.PrimaryPart
	assert(primary ~= nil, "piece needs a PrimaryPart for its label")
	local gui = Instance.new("BillboardGui")
	gui.Name = "PieceLabel"
	gui.Size = UDim2.fromOffset(220, 22 + 20 * #lines)
	gui.StudsOffset = Vector3.new(0, 4.6, 0)
	gui.AlwaysOnTop = false
	gui.Parent = primary
	for i, text in ipairs(lines) do
		local label = Instance.new("TextLabel")
		label.Name = "Line" .. tostring(i)
		label.Size = UDim2.new(1, 0, 0, 20)
		label.Position = UDim2.new(0, 0, 0, (i - 1) * 20)
		label.BackgroundTransparency = 0.35
		label.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
		label.TextColor3 = if i == 1 then accent else Color3.fromRGB(255, 255, 255)
		label.TextScaled = true
		label.Font = Enum.Font.SourceSansBold
		label.Text = text
		label.Parent = gui
	end
end

-- Tween a whole piece model to a ground position at constant speed.
-- Knight pieces arc (up 2 studs mid-path). Returns the Tween.
function PieceBuilder.tweenPieceTo(
	model: Model,
	targetGround: Vector3,
	speed: number,
	pieceType: string
): Tween
	local primary = model.PrimaryPart
	assert(primary ~= nil, "piece needs a PrimaryPart to tween")
	local start = primary.CFrame.Position
	local info = PieceData.TYPES[pieceType :: PieceData.PieceType]
	local target = CFrame.new(targetGround + Vector3.new(0, info.height * 0.5, 0))
	local dist = (target.Position - start).Magnitude
	local duration = math.max(0.15, dist / speed)
	local ts = game:GetService("TweenService")
	if pieceType == "Knight" and dist > 4 then
		-- Two chained tweens through a raised midpoint: the L-jump arc.
		local mid = CFrame.new((start + target.Position) / 2 + Vector3.new(0, 2, 0))
		local up = ts:Create(primary, TweenInfo.new(duration / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = mid })
		local down = ts:Create(primary, TweenInfo.new(duration / 2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = target })
		up.Completed:Connect(function()
			down:Play()
		end)
		up:Play()
		return down
	end
	local tween = ts:Create(primary, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = target })
	tween:Play()
	return tween
end

return PieceBuilder

--[[
Bouncing DVD logo game.

Inspired by:
https://eieio.games/game-diary/game-6-get-the-dvd-logo-into-the-corner/
]]--

import "CoreLibs/graphics"
import "CoreLibs/sprites"

local gfx <const> = playdate.graphics

-- Seed the random number generator.
math.randomseed(playdate.getSecondsSinceEpoch())

-- Initialize sprites, setting initial locations to center of screen.
local tv = gfx.sprite.new(gfx.image.new("tv"))
local tv_width <const>, tv_height <const> = tv:getSize()
local tv_x = 200 - tv_width // 2
local tv_y = 120 - tv_height // 2
local TV_LEFT_BEZEL <const> = 20
local TV_RIGHT_BEZEL <const> = 20
local TV_TOP_BEZEL <const> = 20
local TV_BOTTOM_BEZEL <const> = 20
local SCORE_MARGIN <const> = 4
tv:setZIndex(2)
tv:setCenter(0, 0)
tv:add()

local dvd = gfx.sprite.new(gfx.image.new("dvd"))
local dvd_width <const>, dvd_height <const> = dvd:getSize()
local dvd_x = 200 - dvd_width // 2
local dvd_y = 120 - dvd_height // 2
local dvd_vx = 1
local dvd_vy = 1
dvd:setZIndex(3)
dvd:setCenter(0, 0)
dvd:setImageDrawMode(gfx.kDrawModeNXOR)
dvd:add()

local arrows = gfx.image.new("arrows")
local left_right = gfx.sprite.new(arrows)
left_right:setZIndex(1)
left_right:setCenter(0.5, 0.5)
left_right:add()

local up_down = gfx.sprite.new(arrows:rotatedImage(90))
up_down:setZIndex(1)
up_down:setCenter(0.5, 0.5)
up_down:add()

local score = 0
local time_left = 1
local crank_anchor_x = playdate.getCrankPosition() - tv_x
local crank_anchor_y = playdate.getCrankPosition() - tv_y
local hits = {}
local HIT_TIMER <const> = 20

-- If true, crank moves TV horizontally.
local move_horizontal = true

-- If true, draw left/right arrows to indicate horizontal movement.
-- If false, draw up/down arrows.
--
-- We need a separate state for this because reading buttonIsPressed before
-- calling gfx.sprite.update() doesn't seem do what we wanted, so we have
-- this separate variable that propagates the move_horizontal state that was
-- used in the previous frame.
local draw_horizontal = true

-- Compute new position based on absolute crank position.
--
-- We prefer operating on absolute crank positions instead of deltas since
-- it gives us better precision, and no loss of movement due to underflow.
local function update_crank_position(current_position, current_anchor, limit)
	local crank <const> = playdate.getCrankPosition()
	local new_position = crank - current_anchor
	if new_position < current_position - 180 then
		new_position += 360
	elseif new_position > current_position + 180 then
		new_position -= 360
	end

	if new_position < 0 then
		return 0, crank
	end
	if new_position > limit then
		return limit, crank - limit
	end
	return new_position, current_anchor
end

-- Update TV position based on absolute crank position.
--
-- Note that it's based on absolute crank position as opposed to crank
-- deltas.  This gives us better precision, and isn't prone to lost movements
-- due to underflows.
local function update_tv_position_using_crank()
	local crank <const> = playdate.getCrankPosition()
	if move_horizontal then
		tv_x, crank_anchor_x = update_crank_position(tv_x, crank_anchor_x, 400 - tv_width)
		crank_anchor_y = crank - tv_y
	else
		tv_y, crank_anchor_y = update_crank_position(tv_y, crank_anchor_y, 240 - tv_height)
		crank_anchor_x = crank - tv_x
	end
end

-- Update TV position based on D-Pad input.
local function update_tv_position_using_dpad()
	if playdate.buttonIsPressed(playdate.kButtonUp) then
		tv_y, crank_anchor_y = update_crank_position(tv_y, crank_anchor_y + 2, 240 - tv_height)
	end
	if playdate.buttonIsPressed(playdate.kButtonDown) then
		tv_y, crank_anchor_y = update_crank_position(tv_y, crank_anchor_y - 2, 240 - tv_height)
	end

	if playdate.buttonIsPressed(playdate.kButtonLeft) then
		tv_x, crank_anchor_x = update_crank_position(tv_x, crank_anchor_x + 2, 400 - tv_width)
	end
	if playdate.buttonIsPressed(playdate.kButtonRight) then
		tv_x, crank_anchor_x = update_crank_position(tv_x, crank_anchor_x - 2, 400 - tv_width)
	end
end

-- Check for hits against corners.
--
-- Note that not all the velocities are checked.  For example, once we have
-- established that the logo touched either the left or right sides, we do
-- not check the sign of dvd_vx to see if it made an actual bounce.  We
-- could have added that check, but by not doing it, we enable a strategy
-- where player can score multiple points by pushing the TV corner against
-- the DVD logo just as the two are about to come into contact.  This seem
-- to add bit more variety to the gameplay, so we have decided to keep it.
local function check_horizontal_hit()
	if dvd_vy < 0 and dvd_y <= tv_y + TV_TOP_BEZEL + SCORE_MARGIN then
		if dvd_x <= tv_x + TV_LEFT_BEZEL + SCORE_MARGIN then
			table.insert(hits, {tv_x + TV_LEFT_BEZEL, tv_y + TV_TOP_BEZEL, HIT_TIMER})
		else
			table.insert(hits, {tv_x + tv_width - TV_RIGHT_BEZEL, tv_y + TV_TOP_BEZEL, HIT_TIMER})
		end
		score += 1
	elseif dvd_vy > 0 and dvd_y + dvd_height >= tv_y + tv_height - TV_BOTTOM_BEZEL - SCORE_MARGIN then
		if dvd_x <= tv_x + TV_LEFT_BEZEL + SCORE_MARGIN then
			table.insert(hits, {tv_x + TV_LEFT_BEZEL, tv_y + tv_height - TV_BOTTOM_BEZEL, HIT_TIMER})
		else
			table.insert(hits, {tv_x + tv_width - TV_RIGHT_BEZEL, tv_y + tv_height - TV_BOTTOM_BEZEL, HIT_TIMER})
		end
		score += 1
	end
end

local function check_vertical_hit()
	if dvd_vx < 0 and dvd_x <= tv_x + TV_LEFT_BEZEL + SCORE_MARGIN then
		if dvd_y <= tv_y + TV_TOP_BEZEL + SCORE_MARGIN then
			table.insert(hits, {tv_x + TV_LEFT_BEZEL, tv_y + TV_TOP_BEZEL, HIT_TIMER})
		else
			table.insert(hits, {tv_x + TV_LEFT_BEZEL, tv_y + tv_height - TV_BOTTOM_BEZEL, HIT_TIMER})
		end
		score += 1
	elseif dvd_vx > 0 and dvd_x + dvd_width >= tv_x + tv_width - TV_RIGHT_BEZEL - SCORE_MARGIN then
		if dvd_y <= tv_y + TV_TOP_BEZEL + SCORE_MARGIN then
			table.insert(hits, {tv_x + tv_width - TV_RIGHT_BEZEL, tv_y + TV_TOP_BEZEL, HIT_TIMER})
		else
			table.insert(hits, {tv_x + tv_width - TV_RIGHT_BEZEL, tv_y + tv_height - TV_BOTTOM_BEZEL, HIT_TIMER})
		end
		score += 1
	end
end

-- Update DVD position based on TV position.
local function update_dvd_position()
	dvd_x += dvd_vx
	dvd_y += dvd_vy

	if dvd_x < tv_x + TV_LEFT_BEZEL then
		check_horizontal_hit()
		dvd_x = tv_x + TV_LEFT_BEZEL
		dvd_vx = math.random(1, 3)
	elseif dvd_x + dvd_width > tv_x + tv_width - TV_RIGHT_BEZEL then
		check_horizontal_hit()
		dvd_x = tv_x + tv_width - TV_RIGHT_BEZEL - dvd_width
		dvd_vx = math.random(-3, -1)
	end

	if dvd_y < tv_y + TV_TOP_BEZEL then
		check_vertical_hit()
		dvd_y = tv_y + TV_TOP_BEZEL
		dvd_vy = math.random(1, 3)
	elseif dvd_y + dvd_height > tv_y + tv_height - TV_BOTTOM_BEZEL then
		check_vertical_hit()
		dvd_y = tv_y + tv_height - TV_BOTTOM_BEZEL - dvd_height
		dvd_vy = math.random(-3, -1)
	end
end

-- Draw arrows based on current selected motion.
local function draw_arrows()
	if draw_horizontal then
		-- Draw left right arrows.  Prefer drawing at the bottom unless it
		-- would overlap with the TV.
		up_down:setVisible(false)
		left_right:setVisible(true)
		if tv_y + tv_height > 200 then
			left_right:moveTo(200, 20)
		else
			left_right:moveTo(200, 220)
		end
	else
		-- Draw up down arrows.  Prefer the side that's opposite of the TV's
		-- horizontal location.
		up_down:setVisible(true)
		left_right:setVisible(false)
		if tv_x + tv_width // 2 >= 200 then
			up_down:moveTo(20, 120)
		else
			up_down:moveTo(380, 120)
		end
	end
end

-- Update loop.
function playdate.update()
	gfx.clear()

	draw_arrows()
	update_dvd_position()
	tv:moveTo(tv_x, tv_y)
	dvd:moveTo(dvd_x, dvd_y)

	gfx.sprite.update()

	-- Draw last hit point.
	while #hits > 0 and hits[1][3] <= 0 do
		table.remove(hits, 1)
	end
	for i = 1, #hits do
		local entry = hits[i]
		gfx.setLineWidth(1)
		gfx.setColor(gfx.kColorXOR)
		gfx.drawCircleAtPoint(entry[1], entry[2], (HIT_TIMER - entry[3]) * 12 + 2)
		entry[3] -= 1
	end

	-- Draw score in the corner.
	-- Prefer drawing score on the left, unless it would overlap with TV.
	if tv_x < 90 and tv_y < 20 then
		gfx.drawText("Score: " .. score, 310, 2)
	else
		gfx.drawText("Score: " .. score, 2, 2)
	end

	-- Handle input.
	if playdate.buttonJustPressed(playdate.kButtonB) then
		-- Change movement direction when pressing B.
		move_horizontal = not move_horizontal
		draw_horizontal = move_horizontal
		update_tv_position_using_crank()
	else
		if playdate.buttonIsPressed(playdate.kButtonA) then
			-- Temporarily change movement direction when holding A.
			move_horizontal = not move_horizontal
			draw_horizontal = move_horizontal
			update_tv_position_using_crank()
			move_horizontal = not move_horizontal
		else
			-- Normal movement.
			draw_horizontal = move_horizontal
			update_tv_position_using_crank()
		end
	end
	update_tv_position_using_dpad()
end

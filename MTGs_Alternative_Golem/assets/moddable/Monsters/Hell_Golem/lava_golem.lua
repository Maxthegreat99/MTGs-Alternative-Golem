--[[
Copyright (c) 2020 Boris Marmontel

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

local MonsterFallState = require 'monster_fall_state'
local MonsterJumpState = require 'monster_jump_state'
local class = require 'middleclass'
local Monster = require 'monster_toolbox'
local Snapshot = require 'monster_snapshot_minimal'

local State = {
    Spawn = 0,
    Idle = 1,
    Wait = 2,
    Move = 3,
    GetHit = 4,
    Fall = 5,
    Getup = 6,
    Attack = 7,
    AttackGround = 8,
    Shoot = 9,
    Beam = 10,
    JumpStart = 11,
    JumpAir = 12,
    Die = 13
}

local Animations = {
    [State.Spawn] = "spawn",
    [State.Idle] = "idle",
    [State.Wait] = "idle",
    [State.Move] = "move",
    [State.GetHit] = "hit",
    [State.Fall] = "fall",
    [State.Getup] = "getup",
    [State.Attack] = "attack",
    [State.AttackGround] = "attack_ground",
    [State.Shoot] = "shoot",
    [State.Beam] = "shoot",
    [State.JumpStart] = "move",
    [State.JumpAir] = "move",
    [State.Die] = "die"
}

local RenderConfig = Monster.initRenderConfigAttackAlt(
    "monster_lava_golem",
    "pc_palette_monster_golem",
    State.Beam, true, 12, 12+5, false, "gfx2")
    
    
local rect = {
    Rect:new(0, 0, 44, 60),
    Rect:new(0, 0, 44*2, 60*2),
    Rect:new(0, 0, 44*3, 60*3)
}

local LavaGolemBrainAI = class('LavaGolemBrainAI')
local MonsterLavaGolem = class('MonsterLavaGolem')


local gravity = MonsterJumpState.gravity

function MonsterLavaGolem:initialize()
    Monster.initialize(self, State.Idle, rect[1])
    
    self.bullet_launched = false
    self.ground_timer = 0.0
    self.frame_pause = false
    self.angle = 0
    self.aimed = false
    self.ball_frame = 0.0
    self.gfx_frame = 0.0
    self.gfx = false
    self.render_ball = false
    self.render_beam = false
    self.target = nil
    self.warn_beam = false
    
    self.aim_time = 0.0
    self.aim_speed = 2.5
    self.aim_decce = 0.01
    
    self.jump_state = MonsterJumpState:new(
        State.Idle, State.JumpStart, State.JumpAir, 3.0,
        MonsterJumpState.twoFrameAnim(0,1))
    
    self.fall_state = MonsterFallState:new(
        State.Idle, State.GetHit, State.Fall, State.Getup,
        6,7,8, 1,2,4)
    self.prev_snap = Snapshot:new()
end

function MonsterLavaGolem:evCreate(entity, param)
    Monster.evCreate(self, entity, param, LavaGolemBrainAI)
    entity:enableLighting(true)
    --entity:makeBrainKeyboard()
end

function MonsterLavaGolem:updateBbox()
    self.rect = rect[self.size+1]
end

function MonsterLavaGolem:drawLife(entity)
    if(self.state ~= State.Spawn)
    then
        return entity:drawLife()
    end
    return false
end

function MonsterLavaGolem:playSound(entity, state)
    if(state == State.Attack) then
        entity:soundPlay("attack", entity.pos)
    elseif(state == State.AttackGround) then
        entity:soundPlay("lava", entity.pos)
	end
end

function MonsterLavaGolem:setState(entity, state)
    self.state = state
    self.aimed = false
    self.frame = 0.0
    self.ball_frame = 0.0
    self.bullet_launched = false
    self.frame_pause = false
    self:playSound(entity, state)
    self.gfx_frame = 0.0
    self.gfx = false
    self.render_ball = false
    self.render_beam = false
    self.target = nil
    self.warn_beam = false
    
    self.aim_time = 0.0
    self.aim_speed = 2.5
    self.aim_decce = 0.01
    
    if (state == State.Shoot or state == State.Beam) then
        if (self.scalex > 0) then
            self.angle = 0
        else
            self.angle = 180
        end
    end
end


function MonsterLavaGolem:magmaShoot(entity, target_entity, dt, inputs)

    if (self.frame < 7 or self.frame >= 16) then
        self.render_ball = false
        return
    else 
        self.render_ball = true
    end
    
    
    if (self.frame >= 7 and not self.bullet_launched and not self.aimed) then
        self.frame_pause = true
    end

    if (target_entity == nil and not entity:isPlayerControlable()) then
        self:setState(entity, State.Idle)
        self.frame_pause = false
    end
    
    if (entity:isPlayerControlable() and self.frame_pause) then
    
        if (inputs:check(InputKey.Action1)) then
            self.angle = self.angle + 2 * dt
        end
        
        if (inputs:check(InputKey.Action2)) then
            self.angle = self.angle - 2 * dt
        end
        
        if (inputs:check(InputKey.MouseLeft) and not self.bullet_launched) then
            self.frame_pause = false
            self.aimed = true
        end
    elseif(self.frame_pause) then
        local x1 = 0
        local y1 = 0
        
        if (self.scalex > 0) then
            x1 = entity:boundingBox().x1
            y1 = entity:boundingBox().y1
        else
            x1 = entity:boundingBox().x2
            y1 = entity:boundingBox().y1
        end
        
        x1 = x1 + 30 * self.scalex
        y1 = y1 + 14
    
        local x2 = target_entity:boundingBox():center().x
        local y2 = target_entity:boundingBox():center().y
        
        target_x = x2 - x1
        target_y = y2 - y1
        
        local d = math.sqrt(target_x * target_x + target_y * target_y)
        
        local th = math.asin(math.abs(target_y) / d) * (180/math.pi)
        
        local t_angle = -th
        if (target_x < 0 and target_y > 0) then
            t_angle = 180 + th
        elseif (target_x < 0 and target_y < 0) then
            t_angle = 180 - th
        elseif (target_x > 0 and target_y <0) then
            t_angle = th
        end
        if (self.scalex > 1) then
            t_angle = t_angle + 5
        else
            t_angle = t_angle - 5
        end
        
        if (self.angle < t_angle) then
            self.angle = self.angle + self.aim_speed * dt
        end 
        
        if (self.angle > t_angle) then
            self.angle = self.angle - self.aim_speed * dt
        end 
        
        if (math.abs(self.angle - t_angle) < 6.5) then
            self.angle = t_angle
        end
        self.aim_time = self.aim_time + 1 * dt
        
        if (self.aim_time > 80.0) then
            self.frame_pause = false
            self.aimed = true
        end
    end
    
    if (self.aimed and not self.frame_pause) then
        
        if(self.ball_frame >= 0.0 and self.ball_frame < 1.0)
        then
            self.ball_frame = self.ball_frame + 0.1 * dt
        else
            self.ball_frame = self.ball_frame + 0.2 * dt
        end
        
        if (self.ball_frame >= 9.0) then
            self.ball_frame = 8.0
        end
        
    end
    
    if (self.scalex > 0) then
        if (self.angle < -45) then
            self.angle = -45
        end
        if (self. angle > 80) then
            self.angle = 80
        end
    else
        if (self.angle == 0) then
            self.angle = 180
        end
    
        if (self.angle < 100) then
            self.angle = 100
        end
        if (self. angle > 225) then
            self.angle = 225
        end
    end
    if(self.frame >= 9.0 and not self.bullet_launched) then

        self:MakeMagmaBall(entity)
        entity:soundPlay("shoot", entity.pos)
    end
end



function MonsterLavaGolem:beamShoot(entity, target_entity, dt, inputs)

    if (self.frame < 7 or self.frame >= 16) then
        self.render_beam = false
        self.warn_beam = false
        return
    else 
        self.render_beam = true
    end
    
    if (not self.bullet_launched) then
        self.warn_beam = true
    end
    if (self.frame >= 7 and not self.bullet_launched and not self.aimed) then
        self.frame_pause = true
    end

    if (target_entity == nil and not entity:isPlayerControlable()) then
        self:setState(entity, State.Idle)
        self.frame_pause = false
    end
    
    if (entity:isPlayerControlable() and self.frame_pause) then
    
        if (inputs:check(InputKey.Action1)) then
            self.angle = self.angle + 2 * dt
        end
        
        if (inputs:check(InputKey.Action2)) then
            self.angle = self.angle - 2 * dt
        end
        
        if (inputs:check(InputKey.MouseLeft) and not self.bullet_launched) then
            self.frame_pause = false
            self.aimed = true
        end
    elseif (self.frame_pause) then
        local x1 = 0
        local y1 = 0
        
        if (self.scalex > 0) then
            x1 = entity:boundingBox().x1
            y1 = entity:boundingBox().y1
        else
            x1 = entity:boundingBox().x2
            y1 = entity:boundingBox().y1
        end
        
        x1 = x1 + 34 * self.scalex
        y1 = y1 + 14
    
        local x2 = target_entity:boundingBox():center().x
        local y2 = target_entity:boundingBox():center().y
        
        target_x = x2 - x1
        target_y = y2 - y1
        
        local d = math.sqrt(target_x * target_x + target_y * target_y)
        
        local th = math.asin(math.abs(target_y) / d) * (180/math.pi)
        
        local t_angle = -th
        if (target_x < 0 and target_y > 0) then
            t_angle = 180 + th
        elseif (target_x < 0 and target_y < 0) then
            t_angle = 180 - th
        elseif (target_x > 0 and target_y <0) then
            t_angle = th
        end
        
        local divider = 1
        
        if (math.abs(self.angle - t_angle) > 6) then
            divider = 2
        end
        
        if (self.angle < t_angle) then
            self.angle = self.angle + self.aim_speed / divider * dt
        end 
        
        if (self.angle > t_angle) then
            self.angle = self.angle - self.aim_speed / divider * dt
        end 
        
        self.aim_speed = self.aim_speed - self.aim_decce * dt
        
        if (self.aim_speed < 0) then
            self.aim_speed = 0
        end
        
        if (math.abs(self.angle - t_angle) < 3) then
            self.angle = t_angle
        end
        self.aim_time = self.aim_time + 1 * dt
        
        if (self.aim_time > 125.0) then
            self.frame_pause = false
            self.aimed = true
        end
    end
    
    if (self.aimed and not self.frame_pause) then
        
        if(self.ball_frame >= 0.0 and self.ball_frame < 1.0)
        then
            self.ball_frame = self.ball_frame + 0.1 * dt
        else
            self.ball_frame = self.ball_frame + 0.2 * dt
        end
        
        if (self.ball_frame >= 15.0) then
            self.ball_frame = 14.0
        end
        
        if (self.gfx) then
            self.gfx_frame = self.gfx_frame + 0.2 * dt
            if (self.gfx_frame > 4.0) then
                self.gfx = false
            end
        end
        
    end
    
    if (self.scalex > 0) then
        if (self.angle < -45) then
            self.angle = -45
        end
        if (self. angle > 80) then
            self.angle = 80
        end
    else
        if (self.angle == 0) then
            self.angle = 180
        end
    
        if (self.angle < 100) then
            self.angle = 100
        end
        if (self. angle > 225) then
            self.angle = 225
        end
    end
    
    if (self.ball_frame >= 4.0 and self.gfx == false and self.gfx_frame < 4.0) then
        self.gfx = true
    end
    if(self.ball_frame >= 3.5 and not self.bullet_launched) then
        self:MakeBeam(entity)
        entity:soundPlay("beam", entity.pos)
        self.warn_beam = false
    end
end

function MonsterLavaGolem:createMagma(entity)
    if(self.frame >= 4 and self.frame < 7 and not self.bullet_launched)
    then
        self.bullet_launched = true
        
        local box = entity:boundingBox()
        local wx = box:width()/2.0 + self.scalex * 40 * (self.size + 1)
        
        local dmg = entity:getAttackDamages(3):get(DamageType.Fire)
        local p = Vec2:new(entity.pos.x + wx, box.y2 - 1)
        
        pcCreateMagma(
            entity:getContext(), entity:targetType(),
            dmg, p, 6, 6, 3, self:facingx() > 0.0)
    end
end


function MonsterLavaGolem:MakeBeam(entity)
    self.bullet_launched = true

    local x = 0
    local y = 0
    
    if (self.scalex > 0) then
        x = entity:boundingBox().x1
        y = entity:boundingBox().y1
    else
        x = entity:boundingBox().x2
        y = entity:boundingBox().y1
    end

    x = x + 34 * self.scalex
    y = y + 14
    
    local d = 35
    local dx = d * math.sin((self.angle + 90) * (math.pi/180))
    local dy = d * math.cos((self.angle + 90) * (math.pi/180))
    
    x = x + dx
    y = y + dy
    
    local angle = math.floor(self.angle)
    local attrib = entity:makeBulletAttrib(
        pcEntryIdFromString("pc_bullet_laser_golem"),
        BulletDirectional:new(angle, 4):asMotion())
    attrib:setDamageCoef(
        entity:getAttackDamages(2):get(DamageType.Fire))
    
    entity:createBullet(attrib, Vec2:new(x, y))

end


function MonsterLavaGolem:MakeMagmaBall(entity) 

    local x = 0
    local y = 0
    
    if (self.scalex > 0) then
        x = entity:boundingBox().x1
        y = entity:boundingBox().y1
    else
        x = entity:boundingBox().x2
        y = entity:boundingBox().y1
    end

    x = x + 30 * self.scalex
    y = y + 8
    
    self.bullet_launched = true
    
    local d = 10
    local dx = d * math.cos(self.angle * (math.pi/180))
    local dy = d * math.sin(self.angle * (math.pi/180))
    
    x = x + dx
    y = y + dy
    
    local scale = (self.size + 1)
    
    local angle = math.floor(self.angle)
    
    local attrib = entity:makeBulletAttrib(
        pcEntryIdFromString("pc_bullet_magmaball"),
        BulletGravity:new(angle, 10, 0.25):asMotion())
    attrib:setDamageCoef(
        entity:getAttackDamages(2):get(DamageType.Fire))
    
    entity:createBullet(attrib, Vec2:new(x, y))
end

function MonsterLavaGolem:render(entity, r)
    Monster.render(self, entity, r, Animations, RenderConfig)
    
    if(not entity:alive() or self.state == State.GetHit) then
        return
    end
    local rarity = entity:attribs().rarity:color()
    local sprite = ""
    if (rarity == MonsterRarityColor.Normal) then
        sprite = ""
    elseif (rarity == MonsterRarityColor.Uncommon) then
        sprite = "1"        
    elseif(rarity == MonsterRarityColor.Rare) then
        sprite = "2"        
    elseif(rarity == MonsterRarityColor.Divine) then
        sprite = "3"
    elseif(rarity == MonsterRarityColor.Legendary) then
        sprite = "4"
    end
    
    if (self.render_ball) then
        
        local rs = RenderState:new(r, RendererLayer.Mid, "colored", "monster_lava_golem")
        
        local spr = rs:spriteIndex("ball" .. sprite)
        rs:enableColors(true)
        
        local s = 1

        rs:setColor4f(1,1,1,1)
        
        local img = math.floor(self.ball_frame)
        
        local x = 0
        local y = 0
        
        if (self.scalex > 0) then
            x = entity:boundingBox().x1
            y = entity:boundingBox().y1
        else
            x = entity:boundingBox().x2
            y = entity:boundingBox().y1
        end
        
        rs:drawExt(spr, img, Vec2:new(x + 30 * self.scalex, y + 14), s, s * self.scalex, self.angle)
    
    end 
    if (not self.render_beam) then
        return
    end
    local rs1 = RenderState:new(r, RendererLayer.Front, "colored", "monster_lava_golem")
    local rs2 = RenderState:new(r, RendererLayer.Mid, "colored", "monster_lava_golem")
    local rs3 = RenderState:new(r, RendererLayer.Mid, "colored", "monster_lava_golem")   
    
    local spr1 = rs1:spriteIndex("beam" .. sprite)
    rs1:enableColors(true)
    rs2:enableColors(true)
    rs3:enableColors(true)
    
    local s1 = 1

    rs2:setColor4f(1,1,1,1)
    
    local x1 = 0
    local y1 = 0
    
    if (self.scalex > 0) then
        x1 = entity:boundingBox().x1
        y1 = entity:boundingBox().y1
    else
        x1 = entity:boundingBox().x2
        y1 = entity:boundingBox().y1
    end
    
    local img1 = math.floor(self.ball_frame)
    
    if (self.gfx) then
        local d = 38
        
        local angle = self.angle + 180
        local dx = math.cos(angle * (math.pi/180))
        local dy = math.sin(angle * (math.pi/180))
        
        local x2 = x1 + 34 * self.scalex
        local y2 = y1 + 14
        
        x2 = x2 + dx
        y2 = y2 + dy
        
        local spr2 = rs1:spriteIndex("gfx3")
        
        local img2 = math.floor(self.gfx_frame)
        
        rs2:drawExt(spr2, img2, Vec2:new(x2,y2), s1, s1 * self.scalex, self.angle)

    end
    
    if (self.warn_beam) then
        rs3:setColor4f(0.45,0.45,0.45,0.45)
        
        local midSpr = rs1:spriteIndex("mid")
        local endSpr = rs1:spriteIndex("end")
        
        local x3 = 0
        local y3 = 0
        
        if (self.scalex > 0) then
            x3 = entity:boundingBox().x1
            y3 = entity:boundingBox().y1
        else
            x3 = entity:boundingBox().x2
            y3 = entity:boundingBox().y1
        end
        
        x3 = x3 + 34 * self.scalex
        y3 = y3 + 14
        
        x3 = x3 + math.sin((math.floor(self.angle) + 90)* math.pi / 180) * 35
        y3 = y3 + math.cos((math.floor(self.angle) + 90)* math.pi / 180) * 35
        
        local beam_length = 640
        
                
        local dx = math.sin((math.floor(self.angle) + 90)* math.pi / 180) * beam_length 
        local dy = math.cos((math.floor(self.angle) + 90)* math.pi / 180) * beam_length
        
        local x4 = x3 + dx 
        local y4 = y3 + dy
    
        
    
        local raycast = pcRaycastTest(
            entity:getWorld(), Vec2:new(x3, y3), Vec2:new(x4, y4), 2, false)
        
        target_x = x4 - x3
        target_y = y4 - y3
        
                
        if(raycast.collision) then
        
            target_x = raycast.vec.x
            target_y = raycast.vec.y
        end
        
        local d = math.sqrt(target_x * target_x + target_y * target_y)
        local i = 0
        
        while (i < d) do
            local x5 = x3 + math.sin((math.floor(self.angle) + 90) * math.pi / 180) * i 
            local y5 = y3 + math.cos((math.floor(self.angle) + 90) * math.pi / 180) * i
            
            rs3:drawExt(midSpr, 0, Vec2:new(x5,y5), s1, s1, math.floor(self.angle))
            i = i + 16
        end
        
        local x6 = x3 + math.sin((math.floor(self.angle) + 90) * math.pi / 180) * i 
        local y6 = y3 + math.cos((math.floor(self.angle) + 90) * math.pi / 180) * i
                    
        rs3:drawExt(endSpr, 0, Vec2:new(x6,y6), s1, s1, math.floor(self.angle))
    end

    rs1:setColor4f(1,1,1,1)
    rs1:drawExt(spr1, img1, Vec2:new(x1 + 34 * self.scalex,y1 + 14 ), s1, s1 * self.scalex, self.angle)
end

function MonsterLavaGolem:update(entity, dt)

    if(not entity:alive())
    then
        Monster.destroyOnAnimationEnd(self, entity, 24.0, 0.22, dt)
        entity:updateLandPhysics(
            dt, 0.34, Vec2:new(), Vec2:new(0.05,0.1), 4, true, false)
        return
    end
    
    -- netplay client update
    if(entity:remote()) then
        local prev_snap, last_snap = Monster.netplayClientUpdate2(self, entity)
        if(last_snap ~= nil) then
            if(Monster.stateChanged(self, prev_snap, last_snap)) then
                self:playSound(entity, self.state)
                self.bullet_launched = false
            end
            if(self:shouldInflictDamages(self.state, self.frame)) then
                local hitbox = self:hitbox(self.state, entity)
                if(self.state == State.Attack) then
                    local force = HitForce:new(Vec2:new(self.scalex, -0.4), ProjectionPower.Strong, 1, 1)
                    entity:inflictDamagesHitforce(self.state, 0, force)
                elseif(self.state == State.Shoot and self.bullet_launched == false and self.frame >= 9.0) then
                    self:MakeMagmaBall(entity) 
                    entity:soundPlay("shoot", entity.pos)
                elseif(self.state == State.Beam and self.bullet_launched == false and self.ball_frame >= 4.0) then
                    self:MakeBeam(entity)
                    entity:soundPlay("beam", entity.pos)
                elseif(self.state == State.AttackGround) then
                    self:createMagma(entity)
                end
            end
        end
        self.last_snap_prev = last_snap
        return
    end
    
    if(entity:isPetrified())
    then
        entity:updateLandPhysics(
            dt, 0.34, Vec2:new(), Vec2:new(0.05,0.1), 4, true, false)
        return
    end
    
    entity:updateBrain(self.inputs, dt)
    self.inputs1 = bit32_bor(self.inputs1, self.inputs:state())
    self.inputs2 = bit32_bor(self.inputs2, self.inputs:ostate())
    
    -- Server
    local force = Vec2:new()
    local hspeed = 2.5
    
    local on_ground;
    on_ground, self.ground_timer =
        Monster.updateGroundTimer(entity, self.ground_timer, dt)
    
    self.fall_state:updateTimers(dt)
    
    if(self.state == State.Idle)
    then
        self.frame = self.frame + 0.2 * dt
        
        if(on_ground)
        then
            if(self.inputs:check(InputKey.Space))
            then
                self:setState(entity, State.JumpStart)
            elseif(self.inputs:check(InputKey.MouseLeft))
            then
                if (self.inputs:check(InputKey.Shift)) then
                    self:setState(entity, State.Beam)
                elseif(self.inputs:check(InputKey.Down))
                then
                    self:setState(entity, State.AttackGround)
                elseif(self.inputs:check(InputKey.Up))
                then
                    self:setState(entity, State.Shoot)
                else
                    self:setState(entity, State.Attack)
                end

            elseif(Monster.checkMovementInput(self))
            then
                self:setState(entity, State.Move)
            end
        else
            self:setState(entity, State.JumpAir)
        end
    elseif(self.state == State.Spawn)
    then
        self.frame = self.frame + 0.15 * dt
        if(self.frame >= 16)
        then
            self:setState(entity, State.Move)
        end
    elseif(self.state == State.Move)
    then
        self.frame = self.frame + 0.2 * dt
        
        if(on_ground)then
            if(self.inputs:check(InputKey.Space)) then
                self:setState(entity, State.JumpStart)
            elseif(self.inputs:check(InputKey.MouseLeft)) then
                if (self.inputs:check(InputKey.Shift)) then
                    self:setState(entity, State.Beam)
                elseif(self.inputs:check(InputKey.Down))then
                    self:setState(entity, State.AttackGround)
                elseif(self.inputs:check(InputKey.Up))then
                    self:setState(entity, State.Shoot)
                else
                    self:setState(entity, State.Attack)
                end
            elseif(Monster.checkMovementInput(self))then
                --nop
            else
                self:setState(entity, State.Idle)
            end
            
            force.x = (1 + self.size/2.0) * entity:speedCoef() * self.scalex
        else
            self:setState(entity, State.JumpAir)
        end
    elseif(self.fall_state:update(self, entity, dt, 0.2, Vec2:new()))
    then
    elseif(self.jump_state:update(
        self, entity, self.inputs, entity.vel, self.scalex,
        force, hspeed + self.size/2.0, 0.2, dt))
    then
        if (on_ground and self.state == State.Idle)
        then
            self.bullet_launched = false
        end
    elseif(self.state == State.Attack)
    -- Standard attack
    then
        if(self.frame >= 4 and self.frame < 5)
        then
            self.frame = self.frame + 0.06 * dt
        else
            self.frame = self.frame + 0.2 * dt
        end
        
        if(self.frame >= 6 and self.frame < 8)
        then
            local force = HitForce:new(Vec2:new(self.scalex, -0.4), ProjectionPower.Strong, 1, 1)
            entity:inflictDamagesHitforce(self.state, 0, force)
        end
        
        if(self.frame >= 16.0)
        then
            self:setState(entity, State.Idle)
        end
    elseif(self.state == State.AttackGround)
    -- Magma ground attack
    then
        if(self.frame >= 3 and self.frame < 4)
        then
            self.frame = self.frame + 0.06 * dt
        else
            self.frame = self.frame + 0.2 * dt
        end
        
        self:createMagma(entity)
        
        if(self.frame >= 16.0)
        then
            self:setState(entity, State.Idle)
        end
    elseif(self.state == State.Shoot)
    then
        if (self.target == nil) then
            self.target = entity:findNearTarget(1000);
        end
    
        self:magmaShoot(entity, self.target, dt, self.inputs)
        
        if (self.frame_pause == true) then
            -- nuh uh
        elseif(self.frame >= 7 and self.frame < 8)
        then
            self.frame = self.frame + 0.1 * dt
        else
            self.frame = self.frame + 0.2 * dt
        end
        
        if(self.frame >= 20.0)
        then
            self:setState(entity, State.Idle)
        end
    elseif(self.state == State.Beam)
    then
        if (self.target == nil) then
            self.target = entity:findNearTarget(1000);
        end
        
        self:beamShoot(entity, self.target, dt, self.inputs)
        if (self.frame_pause == true) then
            -- nuh uh
        elseif (self.frame >= 7 and self.frame < 8)
        then
            self.frame = self.frame + 0.1 * dt
        
        elseif (self.frame >= 11 and self.frame < 16) then
            self.frame = self.frame + 0.065 * dt
            
        elseif (self.frame <= 11 or self.frame >= 16) then
            self.frame = self.frame + 0.2 * dt
        end
        
        if(self.frame >= 20)
        then
            self:setState(entity, State.Idle)
        end
    end
    
    local platforms_solid = not self.inputs:check(InputKey.Control)
    entity:enablePlatforms(platforms_solid)
    entity:updateLandPhysics(
        dt, gravity, force, Vec2:new(0.05,0), 0.2, true,
        self.fall_state:canBounce(self))
    entity:enablePlatforms(false)
end

function MonsterLavaGolem:evSend(entity, buf)

    Monster.evSend(self, entity, buf, 0x00)
end

function MonsterLavaGolem:evReceive(entity, buf)

    Monster.evReceive(self, entity, buf)
end
-- Netplay

function MonsterLavaGolem:evSendReliable(entity, buf)
    
    Monster.evSendReliable(Snapshot, self, entity, buf)


    local gfx_bool = 1
    
    if (not self.gfx) then
        gfx_bool = 0
    end
    
    local render_ball_bool = 1
    
    if (not self.render_ball) then
        render_ball_bool = 0
    end
    
    local render_beam_bool= 1
    
    if (not self.render_beam) then
        render_beam_bool = 0
    end
    
    local render_warn_beam_bool = 1
    
    if (not self.warn_beam) then
        render_warn_beam_bool = 0
    end
    
    write2b(buf, math.floor(self.angle))
    write2b(buf, math.floor(self.ball_frame))
    write2b(buf, math.floor(self.gfx_frame))
    write1b(buf, gfx_bool)
    write1b(buf, render_ball_bool)
    write1b(buf, render_beam_bool)
    write1b(buf, render_warn_beam_bool)
end

function MonsterLavaGolem:evReceiveReliable(entity, buf)
    Monster.evReceiveReliable(Snapshot, entity, buf)

    self.angle = read2b(buf)
    self.ball_frame = read2b(buf)
    self.gfx_frame = read2b(buf)
    local gfx_bool = read1b(buf)
    
    if (gfx_bool == 0) then
        self.gfx = false
    else
        self.gfx = true
    end
    
    local render_ball_bool = read1b(buf)
    
    if (render_ball_bool == 0) then
        self.render_ball = false
    else
        self.render_ball = true
    end
    
    local render_beam_bool = read1b(buf)
    
    if (render_beam_bool ==0) then
        self.render_beam = false
    else
        self.render_beam = true
    end

    local render_warn_beam_bool = read1b(buf)
    
    if (render_warn_beam_bool ==0) then
        self.render_warn_beam = false
    else
        self.render_warn_beam = true
    end
end

function MonsterLavaGolem:hitbox(state, entity)
    local box = {}
    local anchor_x = -self.scalex
    
    if(state == State.Attack)
    then
        box = entity:boundingBoxRelative()
        box:scale(2.2, 0.6, anchor_x, RectAnchor.Bottom)
        box:translate(entity.pos.x + 20.0*self.scalex, entity.pos.y + 16.0)
    elseif(state == State.AttackGround)
    then
        box = entity:boundingBoxRelative()
        box:scale(1.5, 0.25, anchor_x, RectAnchor.Bottom)
        box:translate(entity.pos.x, entity.pos.y)
    else
        box = Rect:new()
    end
    
    return box
end

function MonsterLavaGolem:evHurt(entity, damages, owner)
    if(not self.fall_state:hurt(self, entity, damages))
    then
        local dmg = damages:clone()
        dmg.force = HitForce:new()
        return entity:hurtBase(dmg, owner)
    end
    return entity:hurtBase(damages, owner)
end

function MonsterLavaGolem:evGetHit(entity, owner, damages)
    entity:evGetHitBase(owner, damages)
    
    if(entity:alive()) then
        entity:soundPlay("hurt", entity.pos)
    end
end

function MonsterLavaGolem:evDie(entity, owner)
    entity:evDieBase(owner)
    self.frame = 0
    self.state = State.Die
    
    entity:soundPlay("die", entity.pos)
end

function MonsterLavaGolem:makeBrain(entity)
    return LavaGolemBrainAI:new()
end

function MonsterLavaGolem:haveRecoil(entity)
    if(self.state == State.Shoot or self.state == State.Beam or self.state == State.Attack or self.state == State.AttackGround)
    then
        return false
    end

    return true
end

function MonsterLavaGolem:bbox()
    return self.rect
end

function MonsterLavaGolem:facingx()
    return self.scalex
end

function MonsterLavaGolem:isIdle()
    return self.state == State.Idle
end

function MonsterLavaGolem:isMoving()
    return self.state == State.Move
end

function MonsterLavaGolem:isJumping()
    return self.state == State.JumpAir
end

function MonsterLavaGolem:isFalling()
    return self.state == State.Fall
end

function MonsterLavaGolem:canBeUsedAsMount(entity)
    return false
end


function MonsterLavaGolem:lightPoints(entity, vec)
    local rarity = entity:attribs().rarity:color()
    local color = Color:new(255,255,255)
    if (rarity == MonsterRarityColor.Normal) then
        color = Color:new(233, 95, 46)
    elseif (rarity == MonsterRarityColor.Uncommon) then
        color = Color:new(21, 104, 208)        
    elseif(rarity == MonsterRarityColor.Rare) then
        color = Color:new(165, 7, 242)        
    elseif(rarity == MonsterRarityColor.Divine) then
        color = Color:new(144, 21, 222)
    elseif(rarity == MonsterRarityColor.Legendary) then
        color = Color:new(232, 0, 5)
    end
    
    
    local lp = LightPoint:new(color, Vec2:new(entity:boundingBox():center().x, entity:boundingBox():center().y))
    vec:add(lp)

end

function MonsterLavaGolem:shouldInflictDamages(state, frame)
    return ((state == State.Attack and frame >= 6 and frame < 8) or
            (state == State.AttackGround and frame >= 4 and frame < 7) or
            (state == State.Shoot and frame >= 6) or
            (state == State.Beam and frame >= 6))
end


function LavaGolemBrainAI:initialize()
    self.cooldown_beam = 0.0
    self.cooldown_ground = 0.0
    self.cooldown_shoot = 0.0
end

function LavaGolemBrainAI:update(m, entity, brain, inputs, dt)
    self.cooldown_beam = self.cooldown_beam - dt
    self.cooldown_ground = self.cooldown_ground - dt
    self.cooldown_shoot = self.cooldown_shoot - dt
    brain:updateAI(entity, inputs, dt)
end

function LavaGolemBrainAI:tryToAttack(m, entity, focus, inputs)
    local dist = focus:distanceTo(entity:asAliveEntity())
    local facing = false
    
    local box1 = entity:boundingBox()
    local box2 = focus.box
    
    if(m:facingx() > 0.0)
    then
        facing = (box1.x2 <= box2.x1)
    else
        facing = (box1.x1 >= box2.x2)
    end
    
    local vsep = math.abs(box1:center().y - box2:center().y)
    local scale = m.size + 1
    
    if(facing and focus:canBeHit(m:hitbox(State.Attack, entity)))
    then
        inputs:simulateCheck(InputKey.MouseLeft)
        return true
    elseif(self.cooldown_ground <= 0.0
         and facing
         and dist < 150 * scale)
    then
        inputs:simulateCheck(InputKey.MouseLeft)
        inputs:simulateCheck(InputKey.Down)
        self.cooldown_ground = 200.0
        return true
    elseif(self.cooldown_shoot <= 0.0
        and facing
        and dist < 200 * scale
        and vsep < 220)
    then
        inputs:simulateCheck(InputKey.MouseLeft)
        inputs:simulateCheck(InputKey.Up)
        self.cooldown_shoot = 150.0
        return true
    elseif(self.cooldown_beam <= 0.0
        and facing
        and dist < 600 * scale
        and vsep < 220)
    then
        inputs:simulateCheck(InputKey.MouseLeft)
        inputs:simulateCheck(InputKey.Up)
        inputs:simulateCheck(InputKey.Shift)
        self.cooldown_beam = 480.0
        return true
    end
    
    return false
end


return MonsterLavaGolem

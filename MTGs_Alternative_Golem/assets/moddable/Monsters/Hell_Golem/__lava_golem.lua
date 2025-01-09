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
    [State.Beam] = "beam",
    [State.JumpStart] = "move",
    [State.JumpAir] = "move",
    [State.Die] = "die"
}

local RenderConfig = Monster.initRenderConfigZ(
    "monster_lava_golem",
    "pc_palette_monster_golem")
    

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
    
    --entity:makeBrainKeyboard()
end

function MonsterLavaGolem:updateBbox()
    self.rect = rect[self.size+1]
end

function MonsterLavaGolem:render(entity, r)
    Monster.render(self, entity, r, Animations, RenderConfig)
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
    elseif(state == State.Shoot) then
        entity:soundPlay("shoot", entity.pos)
    elseif(state == State.Beam) then
        entity:soundPlay("beam", entity.pos)
    end
end

function MonsterLavaGolem:setState(entity, state)
    self.state = state
    self.frame = 0.0
    self.bullet_launched = false
    self:playSound(entity, state)
end

function MonsterLavaGolem:createBullet(entity)
    if(self.frame >= 9.0 and not self.bullet_launched) then
        self.bullet_launched = true
        
        local scale = (self.size + 1)
        local w = entity:boundingBox():center()
        w.y = w.y - 8 * scale
        w.x = w.x + self:facingx() * 65 * scale
        
        local angle = (self:facingx()<0) and 180.0 or 0.0
        local attrib = entity:makeBulletAttrib(
            pcEntryIdFromString("pc_bullet_magmaball"),
            BulletDirectional:new(angle, 8):asMotion())
        attrib:setDamageCoef(
            entity:getAttackDamages(1):get(DamageType.Fire))
        
        entity:createBullet(attrib, Vec2:new(w.x, w.y))
    end
end

function MonsterLavaGolem:createBeam(entity)
    if(self.frame >= 12.0 and not self.bullet_launched) then
        self.bullet_launched = true
        
        local scale = (self.size + 1)
        local w = entity:boundingBox():center()
        w.x = w.x + self.scalex * 58 * scale
        w.y = w.y - 7 * scale
        
        local angle = (self:facingx()<0) and 180.0 or 0.0
        local attrib = entity:makeBulletAttrib(
            pcEntryIdFromString("pc_bullet_laser_golem"),
            BulletDirectional:new(angle, 4):asMotion())
        attrib:setDamageCoef(
            entity:getAttackDamages(2):get(DamageType.Fire))
        
        entity:createBullet(attrib, Vec2:new(w.x, w.y))
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
                elseif(self.state == State.Shoot) then
                    self:createBullet(entity)
                elseif(self.state == State.Beam) then
                    self:createBeam(entity)
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
        self:createBullet(entity)
        
        if(self.frame >= 7 and self.frame < 8)
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
        self:createBeam(entity)
        
        if(self.frame >= 11 and self.frame < 12)
        then
            self.frame = self.frame + 0.1 * dt
        else
            self.frame = self.frame + 0.2 * dt
        end
        
        if(self.frame >= 28)
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

function MonsterLavaGolem:shouldInflictDamages(state, frame)
    return ((state == State.Attack and frame >= 6 and frame < 8) or
            (state == State.AttackGround and frame >= 4 and frame < 7) or
            (state == State.Shoot and frame >= 9) or
            (state == State.Beam and frame >= 12))
end

-- Netplay (deprecated)

function MonsterLavaGolem:evSend(entity, buf)
    Monster.evSend(self, entity, buf, 0x00)
end

function MonsterLavaGolem:evReceive(entity, buf)
    Monster.evReceive(self, entity, buf)
end

-- Netplay

function MonsterLavaGolem:evSendReliable(entity, buf)
    Monster.evSendReliable(Snapshot, self, entity, buf)
end

function MonsterLavaGolem:evReceiveReliable(entity, buf)
    Monster.evReceiveReliable(Snapshot, entity, buf)
end

-- AI

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
        and dist < 300 * scale
        and vsep < 32)
    then
        inputs:simulateCheck(InputKey.MouseLeft)
        inputs:simulateCheck(InputKey.Up)
        self.cooldown_shoot = 150.0
        return true
    elseif(self.cooldown_beam <= 0.0
        and facing
        and dist < 500 * scale
        and vsep < 32)
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



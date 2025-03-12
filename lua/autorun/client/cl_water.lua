require("niknaks")

BrushesToRender = {}

local matWhite = Material("models/debug/debugwhite")
local wireframe = Material("debug/debugworldwireframe")
local Water2 = Material("water/blu_water")

-- Table to store deform data for different textures
local deformData = {
    ["slime"] = {
        Subdiv = 1,
        deformVertexes = "wave sin 0 1 .5 .5", --wave 100 sin 0 1 .5 .5
        textures = {
            {
                map = Material("liquids/slime7c"),
                tcMod = {
                    turb = {.3, .2, 1, .05},
                    scroll = {.1, .1} -- Scroll values for this texture
                },
                blendfunc = {BLEND_ONE, BLEND_ONE, BLEND_ONE, BLEND_ONE, BLEND_ONE, BLEND_ONE} -- Default blending
            },
            {
                map = Material("liquids/slime7"),
                blendfunc = {BLEND_ONE, BLEND_SRC_ALPHA, BLENDFUNC_ADD, BLEND_ONE, BLEND_ZERO, BLENDFUNC_ADD}, -- Additive blending
                tcMod = {
                    turb = {.2, .1, 1, .05},
                    scale = {.5, .5},
                    scroll = {.1, .6} -- Scroll values for this texture
                }
            },
            --[[{
                map = "liquids/bubbles",
                blendfunc = {BLEND_ZERO, BLEND_SRC_COLOR, BLEND_ONE, BLEND_ONE, 1, BLEND_ONE}, -- Custom blending
                tcMod = {
                    turb = {.2, .1, .1, .2},
                    scale = {.05, .05},
                    scroll = {.001, .001} -- Scroll values for this texture
                }
            }]]
        }
    },
    ["NATURE/WATER_COAST04"] = {
        Subdiv = 8,
        VertexInfo = {
            Type = "wave",
            Math = "sin",
            Vars = {
                Amplitude = 1,
                Phase = 0.5,
                Frequency = 0.5,
                Speed = 1
            }
        },
        Texture = Material("nature/water_coast04_original"),
    },
    ["maps/gm_construct/gm_construct/water_13_1344_3584_32"] = {
        Subdiv = 12,
        VertexInfo = {
            Type = "wave",
            Math = "sin",
            Vars = {
                Amplitude = 12,
                Phase = 0.5,
                Frequency = 0.5,
                Speed = 1
            }
        },
        Texture = Material("gm_construct/water_13_original"),
    }
}

function GetBoundingBox(brush, multiplier)
    -- Initialize min and max with extreme values
    local min = Vector(math.huge, math.huge, math.huge)
    local max = Vector(-math.huge, -math.huge, -math.huge)

    -- Iterate through all combinations of 3 planes to find intersection points
    for i = 1, brush.numsides - 2 do
        for j = i + 1, brush.numsides - 1 do
            for k = j + 1, brush.numsides do
                local plane1 = brush.sides[i].plane
                local plane2 = brush.sides[j].plane
                local plane3 = brush.sides[k].plane

                -- Solve for the intersection point of the 3 planes
                local normal1 = plane1.normal
                local normal2 = plane2.normal
                local normal3 = plane3.normal
                local dist1 = plane1.dist
                local dist2 = plane2.dist
                local dist3 = plane3.dist

                -- Calculate the determinant of the system
                local det = normal1:Dot(normal2:Cross(normal3))
                if math.abs(det) < 1e-6 then
                    -- Planes are parallel or coincident, skip this combination
                    continue
                end

                -- Calculate the intersection point
                local point = (normal2:Cross(normal3) * dist1 +
                               normal3:Cross(normal1) * dist2 +
                               normal1:Cross(normal2) * dist3) / det

                -- Update the bounding box
                min.x = math.min(min.x, point.x)
                min.y = math.min(min.y, point.y)
                min.z = math.min(min.z, point.z)
                max.x = math.max(max.x, point.x)
                max.y = math.max(max.y, point.y)
                max.z = math.max(max.z, point.z)

                continue
            end
        end
    end

    -- Calculate the center of the bounding box
    local center = (min + max) * 0.5

    -- Calculate the size of the bounding box
    local size = max - min

    -- Scale the size by the multiplier
    local scaledSize = size * multiplier

    -- Adjust the min and max to retain the original position
    min = center - (scaledSize * 0.5)
    max = center + (scaledSize * 0.5)

    return min, max
end

for _, brush in ipairs(NikNaks.CurrentMap:GetBrushes()) do
    if brush:HasContents(CONTENTS_WATER) then
        print(brush:GetTexture(6))
        print("found water")
    end
    if brush:HasContents(CONTENTS_WATER) and deformData[brush:GetTexture(6)] then
        local min, max = GetBoundingBox(brush, 1)

        table.insert(BrushesToRender,{
            pos = Vector(0,0,0),
            min=min, 
            max=max,
            texture = brush:GetTexture(6)
        })
    end
end

hook.Remove("PostDrawOpaqueRenderables", "Q3.DrawWaterIMesh")
hook.Add("PostDrawOpaqueRenderables", "Q3.DrawWaterIMesh", function()
    for _, data in ipairs(BrushesToRender) do
        RenderMesh(data)
        render.DrawWireframeBox(Vector(0,0,0), Angle(0, 0, 0), data.min, data.max, Color(0, 255, 0), true)
    end
    
    --[[for _, brushmodels in ipairs( NikNaks.CurrentMap:GetBModels()) do
        render.DrawWireframeBox(brushmodels.origin, Angle( 0, 0, 0 ), brushmodels.maxs, brushmodels.mins, Color(255, 0, 0), true)
    end

    for _, leaf in ipairs(NikNaks.CurrentMap:GetLeafs()) do
        if leaf:HasWater() then
            --render.DrawWireframeBox(Vector( 0, 0, 0 ), Angle( 0, 0, 0 ), leaf.maxs, leaf.mins, Color(0, 255, 0), true)
        end
    end]]
end)

function RenderMesh(data)
    local min, max = data.min, data.max
    local pos = data.pos
    local time = CurTime()

    -- Get deform data for the texture
    local data = deformData[data.texture]
    if not data then return end

    local subdivisions = data.VertexInfo.Vars.Subdiv or 8
    local amplitude = data.VertexInfo.Vars.Amplitude or 1
    local phase = data.VertexInfo.Vars.Phase or 0.5
    local freq = data.VertexInfo.Vars.Frequency or 0.5
    local speed = data.VertexInfo.Vars.Speed or 1

    local function RippleEffect(x, y)
        return math.sin((x + y) * freq + time * speed) * amplitude * 2
    end

    render.SetMaterial( data.Texture )

    --render.SuppressEngineLighting(true)
    render.SetLightingMode(1)

    -- Begin mesh rendering
    mesh.Begin(MATERIAL_TRIANGLES, subdivisions * subdivisions * 6) --6

    local stepX = (max.x - min.x) / subdivisions
    local stepY = (max.y - min.y) / subdivisions

    -- Calculate texture scrolling for the entire mesh
    local scrollU = 0
    local scrollV = 0
    
    -- Apply sine-based texture scrolling
    local sineOffsetU = math.sin(time * scrollU) * 0.1 -- Oscillates between 0 and 1
    local sineOffsetV = math.sin(time * scrollV) * 0.1 -- Oscillates between 0 and 1

    -- Calculate texture scale factor
    local textureScale = 64 -- Desired texture scale
    local scaleU = (max.x - min.x) / textureScale
    local scaleV = (max.y - min.y) / textureScale

    local fixedBrightness = Color(255, 255, 255, 255) -- White color for full brightness

    for i = 0, subdivisions - 1 do
        for j = 0, subdivisions - 1 do
            local x1 = min.x + i * stepX
            local y1 = min.y + j * stepY
            local x2 = x1 + stepX
            local y2 = y1 + stepY

            local p1 = pos + Vector(x1, y1, max.z + RippleEffect(x1, y1))
            local p2 = pos + Vector(x2, y1, max.z + RippleEffect(x2, y1))
            local p3 = pos + Vector(x2, y2, max.z + RippleEffect(x2, y2))
            local p4 = pos + Vector(x1, y2, max.z + RippleEffect(x1, y2))

            -- Calculate base texture coordinates with scaling and sine-based scrolling
            local u1 = ((x1 - min.x) / (max.x - min.x)) * scaleU + sineOffsetU
            local v1 = ((y1 - min.y) / (max.y - min.y)) * scaleV + sineOffsetV
            local u2 = ((x2 - min.x) / (max.x - min.x)) * scaleU + sineOffsetU
            local v2 = ((y2 - min.y) / (max.y - min.y)) * scaleV + sineOffsetV

            -- Calculate normals, tangents, and binormals
            local normal = Vector(0, 0, 1) -- Upward normal for a flat surface
            local tangentS = Vector(1, 0, 0) -- Tangent (S) vector (aligned with the X-axis)
            local tangentT = Vector(0, 1, 0) -- Binormal (T) vector (aligned with the Y-axis)

            --render.DrawLine( p1, p1 + Vector(0,0,1), color_red )

            -- Triangles for the quad (counter-clockwise order)
            -- First triangle
            mesh.Position(p1)
            mesh.Normal(normal)
            mesh.TangentS(tangentS)
            mesh.TangentT(tangentT)
            mesh.TexCoord(0, u1, v1)
            mesh.AdvanceVertex()

            mesh.Position(p4)
            mesh.Normal(normal)
            mesh.TangentS(tangentS)
            mesh.TangentT(tangentT)
            mesh.TexCoord(0, u1, v2)
            mesh.AdvanceVertex()

            mesh.Position(p3)
            mesh.Normal(normal)
            mesh.TangentS(tangentS)
            mesh.TangentT(tangentT)
            mesh.TexCoord(0, u2, v2)
            mesh.AdvanceVertex()

            -- Second triangle
            mesh.Position(p1)
            mesh.Normal(normal)
            mesh.TangentS(tangentS)
            mesh.TangentT(tangentT)
            mesh.TexCoord(0, u1, v1)
            mesh.AdvanceVertex()

            mesh.Position(p3)
            mesh.Normal(normal)
            mesh.TangentS(tangentS)
            mesh.TangentT(tangentT)
            mesh.TexCoord(0, u2, v2)
            mesh.AdvanceVertex()

            mesh.Position(p2)
            mesh.Normal(normal)
            mesh.TangentS(tangentS)
            mesh.TangentT(tangentT)
            mesh.TexCoord(0, u2, v1)
            mesh.AdvanceVertex()
        end
    end

    mesh.End()

    render.OverrideBlend(false)
    render.SetLightingMode(0)

    render.SuppressEngineLighting(false)
end
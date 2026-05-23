function WorldToScreen(worldX, worldY, worldZ)
    local camPos = UIParent:GetViewCameraPos()
    local camDir = UIParent:GetViewCameraDir()
    if not camPos or not camDir then return end

    local dx = worldX - camPos.x
    local dy = worldY - camPos.y
    local dz = worldZ - camPos.z
    local distance = math.sqrt(dx*dx + dy*dy + dz*dz)
    if distance < 0.1 then return end

    -- Dot forward
    local forward = dx*camDir.x + dy*camDir.y + dz*camDir.z
    if forward <= 0.001 then return end

    local screenW = UIParent:GetScreenWidth()
    local screenH = UIParent:GetScreenHeight()
    local fov = UIParent:GetViewCameraFov() or 1.57  -- radians

    local worldUp = {x = 0, y = 0, z = 1}

    local rightX = camDir.y * worldUp.z - camDir.z * worldUp.y
    local rightY = camDir.z * worldUp.x - camDir.x * worldUp.z
    local rightZ = camDir.x * worldUp.y - camDir.y * worldUp.x

    local len = math.sqrt(rightX*rightX + rightY*rightY + rightZ*rightZ)
    if len < 0.001 then return end
    rightX, rightY, rightZ = rightX/len, rightY/len, rightZ/len

    local upX = rightY * camDir.z - rightZ * camDir.y
    local upY = rightZ * camDir.x - rightX * camDir.z
    local upZ = rightX * camDir.y - rightY * camDir.x

    local rc = dx*rightX + dy*rightY + dz*rightZ
    local uc = dx*upX    + dy*upY    + dz*upZ

    local f = 1 / math.tan(fov / 2)

    local screenX = screenW/2 + (rc / forward) * f * (screenH/2)
    local screenY = screenH/2 - (uc / forward) * f * (screenH/2)

    return screenX, screenY, distance
end


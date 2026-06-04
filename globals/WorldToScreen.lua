-- I think Koala made this I'm not sure so yeah credit to him ig
function WorldToScreen(worldX, worldY, worldZ)
    local camPos = UIParent:GetViewCameraPos()
    local camDir = UIParent:GetViewCameraDir()
    if not camPos or not camDir then
        return nil
    end

    local dx = worldX - camPos.x
    local dy = worldY - camPos.y
    local dz = worldZ - camPos.z
    local distance = math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
    if distance < 0.1 then
        return nil
    end

    local forward = (dx * camDir.x) + (dy * camDir.y) + (dz * camDir.z)
    if forward <= 0.001 then
        return nil
    end

    local screenW = UIParent:GetScreenWidth()
    local screenH = UIParent:GetScreenHeight()
    local fov = UIParent:GetViewCameraFov() or 1.57

    local worldUp = { x = 0, y = 0, z = 1 }
    local rightX = (camDir.y * worldUp.z) - (camDir.z * worldUp.y)
    local rightY = (camDir.z * worldUp.x) - (camDir.x * worldUp.z)
    local rightZ = (camDir.x * worldUp.y) - (camDir.y * worldUp.x)

    local rightLen = math.sqrt((rightX * rightX) + (rightY * rightY) + (rightZ * rightZ))
    if rightLen < 0.001 then
        return nil
    end
    rightX, rightY, rightZ = rightX / rightLen, rightY / rightLen, rightZ / rightLen

    local upX = (rightY * camDir.z) - (rightZ * camDir.y)
    local upY = (rightZ * camDir.x) - (rightX * camDir.z)
    local upZ = (rightX * camDir.y) - (rightY * camDir.x)

    local rightComponent = (dx * rightX) + (dy * rightY) + (dz * rightZ)
    local upComponent = (dx * upX) + (dy * upY) + (dz * upZ)
    local focal = 1 / math.tan(fov / 2)

    local screenX = (screenW / 2) + ((rightComponent / forward) * focal * (screenH / 2))
    local screenY = (screenH / 2) - ((upComponent / forward) * focal * (screenH / 2))

    return screenX, screenY, distance
end

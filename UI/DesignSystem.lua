local _, addon = ...

-- Static, addon-owned UI tokens. Identity tint is layered by Theme.lua; none
-- of these values are gameplay settings or persisted cosmetic session state.
local D = {
    surfaceBase = { .035, .041, .055 }, surfaceRaised = { .060, .071, .091 },
    surfaceHover = { .095, .116, .148 }, surfaceSelected = { .080, .152, .194 },
    surfaceInput = { .027, .034, .047 }, surfaceCard = { .051, .062, .081 },
    surfacePrimary = { .060, .190, .235 }, surfaceDanger = { .170, .060, .079 },
    toggleOff = { .020, .029, .043 }, thumbStart = { .970, .985, 1 }, thumbEnd = { .730, .810, .900 },
    borderSubtle = { .145, .174, .214 }, borderStrong = { .240, .340, .430 },
    borderInput = { .092, .116, .148 },
    textPrimary = { .925, .953, .980 }, textSecondary = { .687, .754, .829 },
    textMuted = { .475, .553, .638 }, textDisabled = { .340, .397, .462 },
    accentStart = { .105, .810, .790 }, accentEnd = { .400, .395, .920 },
    accentGlow = { .185, .700, .850 }, danger = { .970, .390, .410 }, success = { .280, .820, .660 },
    spacingXS = 4, spacingS = 8, spacingM = 12, spacingL = 16, spacingXL = 24,
    controlHeight = 30, sectionGap = 16, contentPadding = 24, sectionPadding = 12,
    motionFast = .08, motionNormal = .12, motionSlow = .18, menuClose = .09, menuTravel = 8,
    shellWidth = 900, shellHeight = 640, headerHeight = 76, sidebarWidth = 192,
    footerHeight = 64, contentWidth = 660, contentHeight = 460,
}
addon.DesignSystem = D

function D.Token(name) return D[name] end

function D.Fill(texture, value, alpha)
    local color = type(value) == "string" and D[value] or value
    texture:SetColorTexture(color[1], color[2], color[3], alpha or 1)
end

function D.ApplyGradient(texture, alpha, first, last, orientation)
    first, last, alpha = first or D.accentStart, last or D.accentEnd, alpha or 1
    texture:SetColorTexture(1, 1, 1, 1)
    if texture.SetGradient and CreateColor then
        texture:SetGradient(orientation or "HORIZONTAL", CreateColor(first[1], first[2], first[3], alpha),
            CreateColor(last[1], last[2], last[3], alpha))
    else D.Fill(texture, first, alpha) end
end

function D.Skin(control, kind)
    if control.cuiSkin then return control.cuiSkin end
    local skin = { control = control, kind = kind or "surface", border = {} }
    control.cuiSkin = skin
    skin.fill = control:CreateTexture(nil, "BACKGROUND", nil, -2)
    skin.fill:SetAllPoints(control)
    D.Fill(skin.fill, kind == "input" and "surfaceInput" or kind == "section" and "surfaceCard" or "surfaceRaised")
    if kind == "section" then
        skin.headerWash = control:CreateTexture(nil, "BACKGROUND", nil, -1)
        skin.headerWash:SetPoint("TOPLEFT", control, "TOPLEFT", 1, -1)
        skin.headerWash:SetPoint("TOPRIGHT", control, "TOPRIGHT", -1, -1)
        skin.headerWash:SetHeight(35)
        D.ApplyGradient(skin.headerWash, .045)
    end
    for _, edge in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local line = control:CreateTexture(nil, "BORDER")
        if edge == "TOP" or edge == "BOTTOM" then
            line:SetPoint(edge .. "LEFT", control, edge .. "LEFT", 0, 0)
            line:SetPoint(edge .. "RIGHT", control, edge .. "RIGHT", 0, 0)
            line:SetHeight(1)
        else
            line:SetPoint("TOP" .. edge, control, "TOP" .. edge, 0, 0)
            line:SetPoint("BOTTOM" .. edge, control, "BOTTOM" .. edge, 0, 0)
            line:SetWidth(1)
        end
        D.Fill(line, "borderSubtle")
        skin.border[#skin.border + 1] = line
    end
    return skin
end

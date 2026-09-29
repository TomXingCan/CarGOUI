-- Native Slider contracts complement the visual/lifecycle fixtures. They do
-- not simulate client pixels or physical mouse hit testing.
local h = ...
local test, equal, truthy, same = h.test, h.equal, h.truthy, h.same
local primitive = "Interface\\Buttons\\WHITE8X8"

local function Fixture()
    local env, addon, state = h.login()
    local panel = env.CreateFrame("Frame", nil, env.UIParent)
    panel:SetSize(900, 640)
    panel.cuiPanel, panel.editBoxes, panel.dropdowns = panel, {}, {}
    panel.submissions = {}
    panel.submit = function(patch)
        panel.submissions[#panel.submissions + 1] = patch
        return true
    end
    return env, addon, state, panel, addon.CUI
end

local function NativeDragValue(slider, value)
    -- The native widget changes its value before dispatching OnValueChanged.
    -- Values here are already on the configured native drag step.
    truthy(slider:IsEnabled() and slider:IsMouseEnabled() and slider:IsVisible())
    local down = slider:GetScript("OnMouseDown")
    if down then down(slider, "LeftButton") end
    slider.value = value
    slider:GetScript("OnValueChanged")(slider, value, true)
    local up = slider:GetScript("OnMouseUp")
    if up then up(slider, "LeftButton") end
end

test("SLIDER CONTRACT accepts TextureAsset values and rejects existing texture objects", function()
    local env, _, state, panel = Fixture()
    local slider = env.CreateFrame("Slider", nil, panel)
    local setEnabled, overrideCalls, stateEvents = slider.SetEnabled, 0, 0
    slider.SetEnabled = function() overrideCalls = overrideCalls + 1 end
    slider:SetScript("OnEnable", function() stateEvents = stateEvents + 1 end)
    slider:SetScript("OnDisable", function() stateEvents = stateEvents + 1 end)
    slider:Disable(); truthy(not slider:IsEnabled())
    slider:Enable(); truthy(slider:IsEnabled())
    equal(overrideCalls, 0, "native Enable/Disable never call a Lua SetEnabled override")
    equal(stateEvents, 2, "native enabled changes still dispatch lifecycle callbacks")
    slider.SetEnabled = setEnabled
    slider:SetThumbTexture(primitive)
    local thumb = slider:GetThumbTexture()
    equal(thumb:GetObjectType(), "Texture", "GetThumbTexture exposes the native SimpleTexture")
    equal(thumb:GetParent(), slider, "the slider owns its thumb")
    equal(thumb:GetTexture(), primitive)
    local textureCount = #state.textures
    for _ = 1, 20 do equal(slider:GetThumbTexture(), thumb) end
    equal(#state.textures, textureCount, "reading the native thumb never allocates")

    local other = env.CreateFrame("Slider", nil, panel)
    other:SetThumbTexture(449490)
    equal(other.thumbTextureAsset, 449490, "FileDataIDs are TextureAsset values too")
    equal(other:GetThumbTexture():GetParent(), other)
    truthy(other:GetThumbTexture() ~= thumb, "native sliders never share thumb ownership")
    local ownedTexture = slider:CreateTexture(nil, "OVERLAY")
    local foreignTexture = panel:CreateTexture(nil, "ARTWORK")
    local child = env.CreateFrame("Button", nil, slider)
    env.CreateFrame("Frame", nil, child)
    local children = { slider:GetChildren() }
    equal(#children, 1, "GetChildren returns direct child frames, never texture regions or grandchildren")
    equal(children[1], child)
    textureCount = #state.textures
    local function Reject(value)
        local ok, message = pcall(slider.SetThumbTexture, slider, value)
        equal(ok, false, "SetThumbTexture rejects non-asset arguments")
        truthy(tostring(message):find("TextureAsset", 1, true))
        equal(slider:GetThumbTexture(), thumb, "a rejected call preserves the current native thumb")
        equal(slider.thumbTextureAsset, primitive)
        equal(#state.textures, textureCount, "a rejected call cannot allocate a replacement")
    end
    for _, value in ipairs({ thumb, ownedTexture, foreignTexture, other, {}, false, function() end }) do Reject(value) end
    Reject(nil)
end)

test("SLIDER CONTRACT CUI slider creates and skins its native owned thumb from a neutral asset", function()
    local _, addon, state, panel, C = Fixture()
    local row = C.Slider(panel, panel, "Value", -100, { min = 0, max = 10 }, .5,
        function(value) return { value = value } end)
    local slider = row.slider
    local thumb = slider:GetThumbTexture()
    equal(slider.template, nil)
    equal(slider.thumbTextureAsset, primitive, "CUI supplies a TextureAsset instead of a Texture object")
    equal(thumb:GetParent(), slider)
    equal(thumb:GetWidth(), 12); equal(thumb:GetHeight(), 18)
    same(thumb.color, { addon.DesignSystem.textPrimary[1], addon.DesignSystem.textPrimary[2], addon.DesignSystem.textPrimary[3], 1 })
    equal(slider.track:GetParent(), slider); equal(slider.fill:GetParent(), slider)
    same(slider.fill.gradient.first, { .105, .810, .790, 1 })
    same(slider.fill.gradient.last, { .400, .395, .920, 1 })
    equal(slider.orientation, "HORIZONTAL"); equal(slider.valueStep, .5); equal(slider.obeyStep, true)
    local textureCount = #state.textures
    row:Disable(); equal(thumb:GetAlpha(), .45); truthy(not row.editBox:IsEnabled())
    row:Enable(); equal(thumb:GetAlpha(), 1); truthy(row.editBox:IsEnabled())
    equal(slider:GetThumbTexture(), thumb); equal(#state.textures, textureCount)
end)

test("SLIDER CONTRACT native values and drag callbacks retain save rounding and refresh guards", function()
    local _, _, _, panel, C = Fixture()
    local row = C.Slider(panel, panel, "Value", -100, { min = 0, max = 10 }, .5,
        function(value) return { value = value } end)
    local slider = row.slider
    local thumb = slider:GetThumbTexture()
    panel.refreshing = true
    row:SetValue(2)
    equal(#panel.submissions, 0, "loading settings cannot submit")
    panel.refreshing = false
    row:SetValue(6.26); equal(#panel.submissions, 0, "All programmatic changes stay silent and precise")
    NativeDragValue(slider, 6.26)
    equal(panel.submissions[1].value, 6.5, "User dragging normalizes to the configured step")
    row.editBox.dirty = true; row.editBox:SetInvalid(true)
    NativeDragValue(slider, 8.5)
    equal(slider:GetValue(), 8.5); equal(panel.submissions[2].value, 8.5)
    equal(row.editBox.dirty, false); equal(row.editBox.invalid, false)
    equal(slider.fill:GetWidth(), slider:GetWidth() * .85)
    NativeDragValue(slider, 10)
    equal(slider:GetValue(), 10); equal(panel.submissions[3].value, 10, "native bounds remain authoritative")
    panel:Hide(); row:SetValue(4)
    equal(#panel.submissions, 3, "hidden controls cannot save")
    equal(slider:GetThumbTexture(), thumb, "value changes retain the same native thumb")
end)

test("SLIDER CONTRACT scrollbars own skinned thumbs and synchronize drag wheel and native scroll values", function()
    local env, addon, state, panel, C = Fixture()
    local scroll = C.ScrollFrame(panel, panel, 24, -100, 640, 300)
    local content = env.CreateFrame("Frame", nil, scroll)
    content:SetSize(640, 900); scroll:SetScrollChild(content); scroll:RefreshRange()
    local bar, thumb = scroll.scrollBar, scroll.thumb
    equal(bar.template, nil); equal(bar.orientation, "VERTICAL")
    equal(bar.thumbTextureAsset, primitive)
    equal(bar:GetThumbTexture(), thumb); equal(thumb:GetParent(), bar)
    equal(thumb:GetWidth(), 6); equal(thumb:GetHeight(), 100)
    same(thumb.color, { addon.DesignSystem.borderStrong[1], addon.DesignSystem.borderStrong[2], addon.DesignSystem.borderStrong[3], 1 })
    local textureCount = #state.textures
    bar:GetScript("OnEnter")()
    same(thumb.color, { addon.DesignSystem.accentGlow[1], addon.DesignSystem.accentGlow[2], addon.DesignSystem.accentGlow[3], 1 })
    bar:GetScript("OnLeave")()
    same(thumb.color, { addon.DesignSystem.borderStrong[1], addon.DesignSystem.borderStrong[2], addon.DesignSystem.borderStrong[3], 1 })
    bar:SetValue(120); equal(scroll:GetVerticalScroll(), 120)
    scroll:SetVerticalScroll(240); equal(bar:GetValue(), 240)
    NativeDragValue(bar, 330); equal(scroll:GetVerticalScroll(), 330); equal(bar:GetValue(), 330)
    scroll:GetScript("OnMouseWheel")(scroll, -2)
    equal(scroll:GetVerticalScroll(), 390); equal(bar:GetValue(), 390)
    bar:SetValue(900); equal(scroll:GetVerticalScroll(), 600); equal(bar:GetValue(), 600)
    content:SetHeight(340); scroll:RefreshRange()
    equal(scroll:GetVerticalScroll(), 40); equal(bar:GetValue(), 40)
    scroll:Hide(); truthy(not bar:IsShown())
    scroll:Show(); truthy(bar:IsShown())
    equal(bar:GetThumbTexture(), thumb); equal(#state.textures, textureCount)
end)

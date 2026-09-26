local _, addon = ...

-- Header identity is faction-only. Body identity is class/spec-only. Neither
-- palette participates in reminder styles, class colors, or SavedVariables.
addon.optionHeaderThemes = {
    alliance = { label = "Alliance blue", left = { 0.025, 0.075, 0.18 },
        right = { 0.06, 0.28, 0.52 }, accent = { 0.30, 0.66, 1.00 } },
    horde = { label = "Horde red", left = { 0.16, 0.025, 0.035 },
        right = { 0.43, 0.07, 0.085 }, accent = { 1.00, 0.34, 0.30 } },
    neutral = { label = "Neutral faction fallback", left = { 0.065, 0.075, 0.09 },
        right = { 0.14, 0.17, 0.20 }, accent = { 0.62, 0.69, 0.76 } },
}

addon.optionBodyThemes = {
    neutral = { label = "Neutral Body fallback", motif = "none",
        background = { 0.035, 0.04, 0.048 }, left = { 0.045, 0.052, 0.064 }, right = { 0.080, 0.095, 0.115 },
        accent = { 0.56, 0.65, 0.75 }, input = { 0.025, 0.032, 0.042 }, button = { 0.075, 0.092, 0.115 } },
    mage = { label = "Mage Body fallback", motif = "none",
        background = { 0.03, 0.043, 0.057 }, left = { 0.045, 0.069, 0.088 }, right = { 0.078, 0.105, 0.14 },
        accent = { 0.47, 0.70, 0.83 }, input = { 0.022, 0.036, 0.050 }, button = { 0.065, 0.105, 0.14 } },
    arcane = { label = "Arcane violet", motif = "arcane",
        background = { 0.043, 0.025, 0.067 }, left = { 0.064, 0.031, 0.11 }, right = { 0.17, 0.078, 0.245 },
        accent = { 0.73, 0.49, 0.98 }, input = { 0.035, 0.021, 0.060 }, button = { 0.12, 0.064, 0.18 } },
    fire = { label = "Fire ember / amber", motif = "fire",
        background = { 0.070, 0.027, 0.018 }, left = { 0.12, 0.034, 0.019 }, right = { 0.245, 0.13, 0.047 },
        accent = { 1.00, 0.62, 0.27 }, input = { 0.057, 0.025, 0.019 }, button = { 0.18, 0.082, 0.032 } },
    frost = { label = "Frost deep blue / cyan", motif = "frost",
        background = { 0.018, 0.039, 0.070 }, left = { 0.026, 0.062, 0.14 }, right = { 0.055, 0.18, 0.23 },
        accent = { 0.43, 0.84, 1.00 }, input = { 0.018, 0.031, 0.058 }, button = { 0.042, 0.105, 0.16 } },
}

addon.optionThemeSpecs = { [62] = { key = "arcane", label = "Arcane" },
    [63] = { key = "fire", label = "Fire" }, [64] = { key = "frost", label = "Frost" } }
addon.optionThemeClassNames = {
    DEATHKNIGHT = "Death Knight", DEMONHUNTER = "Demon Hunter", DRUID = "Druid",
    EVOKER = "Evoker", HUNTER = "Hunter", MAGE = "Mage", MONK = "Monk",
    PALADIN = "Paladin", PRIEST = "Priest", ROGUE = "Rogue", SHAMAN = "Shaman",
    WARLOCK = "Warlock", WARRIOR = "Warrior",
}

-- Explicit identity roster from the pinned Retail 12.1 specialization UI.
-- This is decorative identity metadata, never a spell or Mobility database.
addon.optionThemeClasses = {
    DEATHKNIGHT = { key = "deathknight", specs = {
        [250] = { key = "deathknight_blood", label = "Blood" }, [251] = { key = "deathknight_frost", label = "Frost" },
        [252] = { key = "deathknight_unholy", label = "Unholy" } } },
    DEMONHUNTER = { key = "demonhunter", specs = {
        [577] = { key = "demonhunter_havoc", label = "Havoc" }, [581] = { key = "demonhunter_vengeance", label = "Vengeance" },
        [1480] = { key = "demonhunter_devourer", label = "Devourer" } } },
    DRUID = { key = "druid", specs = {
        [102] = { key = "druid_balance", label = "Balance" }, [103] = { key = "druid_feral", label = "Feral" },
        [104] = { key = "druid_guardian", label = "Guardian" }, [105] = { key = "druid_restoration", label = "Restoration" } } },
    EVOKER = { key = "evoker", specs = {
        [1467] = { key = "evoker_devastation", label = "Devastation" }, [1468] = { key = "evoker_preservation", label = "Preservation" },
        [1473] = { key = "evoker_augmentation", label = "Augmentation" } } },
    HUNTER = { key = "hunter", specs = {
        [253] = { key = "hunter_beastmastery", label = "Beast Mastery" }, [254] = { key = "hunter_marksmanship", label = "Marksmanship" },
        [255] = { key = "hunter_survival", label = "Survival" } } },
    MAGE = { key = "mage", specs = addon.optionThemeSpecs },
    MONK = { key = "monk", specs = {
        [268] = { key = "monk_brewmaster", label = "Brewmaster" }, [269] = { key = "monk_windwalker", label = "Windwalker" },
        [270] = { key = "monk_mistweaver", label = "Mistweaver" } } },
    PALADIN = { key = "paladin", specs = {
        [65] = { key = "paladin_holy", label = "Holy" }, [66] = { key = "paladin_protection", label = "Protection" },
        [70] = { key = "paladin_retribution", label = "Retribution" } } },
    PRIEST = { key = "priest", specs = {
        [256] = { key = "priest_discipline", label = "Discipline" }, [257] = { key = "priest_holy", label = "Holy" },
        [258] = { key = "priest_shadow", label = "Shadow" } } },
    ROGUE = { key = "rogue", specs = {
        [259] = { key = "rogue_assassination", label = "Assassination" }, [260] = { key = "rogue_outlaw", label = "Outlaw" },
        [261] = { key = "rogue_subtlety", label = "Subtlety" } } },
    SHAMAN = { key = "shaman", specs = {
        [262] = { key = "shaman_elemental", label = "Elemental" }, [263] = { key = "shaman_enhancement", label = "Enhancement" },
        [264] = { key = "shaman_restoration", label = "Restoration" } } },
    WARLOCK = { key = "warlock", specs = {
        [265] = { key = "warlock_affliction", label = "Affliction" }, [266] = { key = "warlock_demonology", label = "Demonology" },
        [267] = { key = "warlock_destruction", label = "Destruction" } } },
    WARRIOR = { key = "warrior", specs = {
        [71] = { key = "warrior_arms", label = "Arms" }, [72] = { key = "warrior_fury", label = "Fury" },
        [73] = { key = "warrior_protection", label = "Protection" } } },
}

local function Shade(color, factor)
    return { color[1] * factor, color[2] * factor, color[3] * factor }
end

local function Body(key, label, left, right, accent)
    addon.optionBodyThemes[key] = { label = label, motif = key, left = left, right = right, accent = accent,
        background = Shade(left, 0.65), input = Shade(left, 0.40), button = Shade(right, 0.65) }
end

-- New palettes are original design proposals. The existing three Mage records
-- above remain byte-for-byte unchanged; input fills stay dark in every family.
Body("deathknight", "Death Knight / dark runesteel", { .065,.031,.047 }, { .17,.075,.12 }, { .78,.39,.53 })
Body("deathknight_blood", "Blood / crimson", { .085,.022,.030 }, { .25,.052,.078 }, { 1,.34,.43 })
Body("deathknight_frost", "Frost / icy steel", { .027,.059,.10 }, { .075,.16,.24 }, { .55,.83,1 })
Body("deathknight_unholy", "Unholy / plague green", { .040,.065,.025 }, { .12,.20,.055 }, { .64,.88,.31 })
Body("demonhunter", "Demon Hunter / fel jade", { .025,.059,.048 }, { .075,.18,.105 }, { .40,.89,.58 })
Body("demonhunter_havoc", "Havoc / acid jade", { .025,.068,.032 }, { .12,.23,.052 }, { .64,1,.31 })
Body("demonhunter_vengeance", "Vengeance / scorched copper", { .071,.039,.025 }, { .22,.11,.037 }, { 1,.66,.30 })
Body("demonhunter_devourer", "Devourer / void violet", { .042,.026,.082 }, { .16,.065,.25 }, { .76,.45,1 })
Body("druid", "Druid / forest amber", { .028,.061,.032 }, { .13,.16,.052 }, { .72,.83,.40 })
Body("druid_balance", "Balance / moonlit indigo", { .027,.036,.088 }, { .11,.10,.23 }, { .70,.73,1 })
Body("druid_feral", "Feral / rust and bark", { .078,.036,.023 }, { .23,.10,.048 }, { 1,.62,.31 })
Body("druid_guardian", "Guardian / bronze earth", { .057,.046,.026 }, { .19,.145,.062 }, { .87,.72,.38 })
Body("druid_restoration", "Restoration / living green", { .023,.064,.043 }, { .062,.205,.10 }, { .44,.96,.63 })
Body("evoker", "Evoker / draconic jade", { .025,.052,.054 }, { .075,.16,.16 }, { .43,.83,.80 })
Body("evoker_devastation", "Devastation / ruby to blue", { .085,.025,.044 }, { .064,.12,.23 }, { .96,.48,.56 })
Body("evoker_preservation", "Preservation / emerald bronze", { .027,.061,.046 }, { .12,.19,.075 }, { .58,.89,.57 })
Body("evoker_augmentation", "Augmentation / obsidian bronze", { .050,.038,.032 }, { .205,.15,.066 }, { .94,.76,.40 })
Body("hunter", "Hunter / woodland olive", { .035,.055,.027 }, { .115,.17,.065 }, { .67,.83,.42 })
Body("hunter_beastmastery", "Beast Mastery / fern amber", { .034,.064,.029 }, { .18,.175,.058 }, { .90,.80,.34 })
Body("hunter_marksmanship", "Marksmanship / forest steel", { .025,.052,.074 }, { .055,.16,.18 }, { .47,.82,.91 })
Body("hunter_survival", "Survival / moss and rust", { .042,.058,.027 }, { .205,.11,.045 }, { .87,.65,.35 })
addon.optionBodyThemes.mage.motif = "mage"
Body("monk", "Monk / jade", { .022,.061,.052 }, { .055,.18,.14 }, { .40,.93,.73 })
Body("monk_brewmaster", "Brewmaster / amber jade", { .064,.048,.024 }, { .18,.17,.059 }, { .91,.80,.40 })
Body("monk_windwalker", "Windwalker / sky jade", { .022,.060,.065 }, { .055,.19,.21 }, { .43,.92,.98 })
Body("monk_mistweaver", "Mistweaver / sea green", { .020,.063,.043 }, { .045,.21,.13 }, { .40,.98,.70 })
Body("paladin", "Paladin / muted gold", { .063,.047,.027 }, { .20,.16,.070 }, { .97,.83,.49 })
Body("paladin_holy", "Holy / warm radiance", { .075,.052,.023 }, { .24,.18,.070 }, { 1,.89,.57 })
Body("paladin_protection", "Protection / blue and gold", { .030,.046,.076 }, { .14,.17,.20 }, { .72,.81,.95 })
Body("paladin_retribution", "Retribution / crimson gold", { .079,.027,.039 }, { .23,.115,.054 }, { 1,.66,.45 })
Body("priest", "Priest / warm ivory", { .054,.051,.046 }, { .17,.16,.115 }, { .92,.89,.71 })
Body("priest_discipline", "Discipline / blue gold", { .037,.045,.076 }, { .15,.14,.205 }, { .78,.76,1 })
Body("priest_holy", "Holy / ivory amber", { .064,.052,.032 }, { .22,.18,.095 }, { 1,.94,.72 })
Body("priest_shadow", "Shadow / deep violet", { .036,.021,.067 }, { .13,.046,.205 }, { .70,.42,.94 })
Body("rogue", "Rogue / charcoal brass", { .048,.044,.030 }, { .15,.13,.054 }, { .85,.76,.38 })
Body("rogue_assassination", "Assassination / poison olive", { .044,.057,.022 }, { .16,.195,.039 }, { .79,.93,.30 })
Body("rogue_outlaw", "Outlaw / brass and sea", { .067,.046,.021 }, { .042,.14,.14 }, { 1,.79,.37 })
Body("rogue_subtlety", "Subtlety / midnight violet", { .024,.031,.062 }, { .105,.065,.185 }, { .64,.58,.98 })
Body("shaman", "Shaman / storm blue", { .020,.047,.080 }, { .052,.13,.22 }, { .38,.72,1 })
Body("shaman_elemental", "Elemental / lava and storm", { .080,.028,.022 }, { .092,.08,.20 }, { .97,.57,.35 })
Body("shaman_enhancement", "Enhancement / lightning steel", { .030,.048,.077 }, { .065,.17,.23 }, { .49,.86,1 })
Body("shaman_restoration", "Restoration / tidal teal", { .018,.052,.066 }, { .042,.175,.17 }, { .39,.92,.85 })
Body("warlock", "Warlock / fel amethyst", { .047,.025,.072 }, { .13,.08,.185 }, { .75,.54,.96 })
Body("warlock_affliction", "Affliction / sickly violet", { .039,.045,.037 }, { .13,.075,.17 }, { .77,.86,.42 })
Body("warlock_demonology", "Demonology / amethyst fel", { .055,.026,.078 }, { .18,.07,.23 }, { .89,.49,1 })
Body("warlock_destruction", "Destruction / fel embers", { .076,.031,.021 }, { .21,.11,.055 }, { 1,.61,.31 })
Body("warrior", "Warrior / iron and rust", { .053,.038,.034 }, { .17,.12,.086 }, { .82,.66,.49 })
Body("warrior_arms", "Arms / crimson bronze", { .075,.025,.028 }, { .21,.105,.050 }, { .96,.61,.39 })
Body("warrior_fury", "Fury / raging embers", { .090,.025,.019 }, { .26,.075,.026 }, { 1,.47,.25 })
Body("warrior_protection", "Protection / tempered steel", { .032,.041,.059 }, { .105,.145,.18 }, { .62,.79,.92 })
addon.optionThemeOpacity = { header = 1, selection = 0.56, motif = 0.16, border = 0.50, line = 0.34 }
addon.optionThemeText = { 0.90, 0.91, 0.94 }
addon.optionThemeWatermarkSize, addon.optionThemeMotifLimit = 200, 64

-- One current class/spec geometry is assembled on demand. Helpers describe
-- original symbolic outlines, not spell icons, faction emblems or game assets.
local function ClassMotif(kind, line)
    local class, spec = kind:match("^([^_]+)_(.+)$")
    class, spec = class or kind, spec or "base"
    local function path(points, width, mirror)
        mirror = mirror or 1
        for i = 2, #points do
            line(points[i-1][1] * mirror, points[i-1][2], points[i][1] * mirror, points[i][2], width)
        end
    end
    local function arc(x, y, rx, ry, first, last, count, width)
        for i = 1, count do
            local a, b = first + (last-first)*(i-1)/count, first + (last-first)*i/count
            line(x+rx*math.cos(a), y+ry*math.sin(a), x+rx*math.cos(b), y+ry*math.sin(b), width)
        end
    end
    local function circle(x, y, radius, count) arc(x,y,radius,radius,0,2*math.pi,count or 16) end
    local function diamond(x, y, w, h)
        path({{x,y+h},{x+w,y},{x,y-h},{x-w,y},{x,y+h}},2)
    end
    local function leaf(x, y, w, h)
        path({{x,y+h},{x+w,y+h*.2},{x+w*.7,y-h*.6},{x,y-h},{x-w*.7,y-h*.6},{x-w,y+h*.2},{x,y+h}},2)
    end
    local function rays(x,y,r1,r2,count,phase)
        for i=0,count-1 do
            local a=(phase or 0)+2*math.pi*i/count
            line(x+r1*math.cos(a),y+r1*math.sin(a),x+r2*math.cos(a),y+r2*math.sin(a),2)
        end
    end
    local function wave(y, width)
        path({{-63,y},{-42,y+9},{-21,y},{0,y-9},{21,y},{42,y+9},{63,y}},width or 2)
    end
    local function paw(x,y)
        diamond(x,y-12,22,17)
        for _, dx in ipairs({-25,0,25}) do diamond(x+dx,y+17,7,10) end
    end
    if class == "deathknight" then
        path({{0,92},{19,58},{12,-20},{-12,-20},{-19,58},{0,92}},3)
        path({{-48,-20},{48,-20},{29,-31},{-29,-31},{-48,-20}},3)
        path({{-7,-31},{-7,-76},{0,-88},{7,-76},{7,-31}},3)
        if spec == "blood" then leaf(0,31,12,23); line(0,12,0,51,2)
        elseif spec == "frost" then
            rays(-54,34,6,23,6,math.pi/6); rays(54,34,6,23,6,math.pi/6)
        elseif spec == "unholy" then
            path({{-39,50},{-51,61},{-65,49},{-61,25},{-46,18},{-39,50}},2)
            path({{39,50},{51,61},{65,49},{61,25},{46,18},{39,50}},2)
            line(-57,44,-47,36,3); line(47,36,57,44,3)
        else diamond(0,37,8,19); diamond(-57,14,10,15); diamond(57,14,10,15) end
    elseif class == "demonhunter" then
        local glaive={{20,-37},{48,-64},{84,-48},{62,-24},{75,22},{87,65},{54,47},{26,7},{20,-37}}
        path(glaive,3); path(glaive,3,-1)
        line(-22,8,22,8,3); line(-18,-1,18,-1,3)
        if spec == "havoc" then
            path({{-30,24},{-8,58},{0,43},{8,58},{30,24}},3); rays(0,-35,6,18,4,math.pi/4)
        elseif spec == "vengeance" then
            path({{-26,45},{0,59},{26,45},{21,-2},{0,-29},{-21,-2},{-26,45}},3)
        elseif spec == "devourer" then circle(0,32,30,20); diamond(0,32,9,18)
        else diamond(0,34,13,23); line(0,-17,0,-62,3) end
    elseif class == "druid" then
        local antler={{-8,8},{-34,34},{-37,68},{-27,86}}
        path(antler,3); path(antler,3,-1)
        local branch={{-35,47},{-62,61},{-73,84}}
        path(branch,3); path(branch,3,-1)
        line(-40,28,-71,35,2); line(40,28,71,35,2)
        leaf(0,-22,26,49); line(0,-68,0,20,2)
        if spec == "balance" then
            arc(0,43,23,29,math.pi*.3,math.pi*1.7,12); path({{14,66},{-3,48},{-4,35},{14,20}},2)
        elseif spec == "feral" then
            for _,x in ipairs({-51,-38,-25}) do path({{x,-28},{x-5,-48},{x-3,-71}},3); end
            for _,x in ipairs({25,38,51}) do path({{x,-28},{x+5,-48},{x+3,-71}},3); end
        elseif spec == "guardian" then paw(0,-20)
        elseif spec == "restoration" then leaf(-49,-11,12,20); leaf(49,-11,12,20)
        else diamond(0,52,12,20) end
    elseif class == "evoker" then
        local wing={{9,8},{33,45},{86,68},{72,28},{54,35},{51,1},{32,14},{9,8}}
        path(wing,3); path(wing,3,-1)
        path({{-11,32},{-18,64},{0,83},{18,64},{11,32},{0,15},{-11,32}},3)
        path({{0,15},{-7,-21},{12,-47},{0,-75},{-23,-85}},3)
        if spec == "devastation" then
            path({{-44,-32},{-35,-4},{-19,-41},{-32,-63},{-44,-32}},2)
            path({{28,-58},{49,-23},{61,-49},{44,-77},{28,-58}},2)
        elseif spec == "preservation" then leaf(-42,-29,19,28); leaf(42,-29,19,28)
        elseif spec == "augmentation" then
            diamond(-44,-24,19,30); diamond(44,-24,19,30); line(-59,-24,-29,-24,2); line(29,-24,59,-24,2)
        else diamond(0,-8,9,17) end
    elseif class == "hunter" then
        arc(-28,0,56,86,-math.pi/2,math.pi/2,12,3)
        line(-28,-86,-28,86,2); line(-70,0,88,0,3)
        path({{68,14},{88,0},{68,-14}},3)
        path({{-58,0},{-73,13},{-87,13}},2); path({{-58,0},{-73,-13},{-87,-13}},2)
        if spec == "beastmastery" then paw(0,-46)
        elseif spec == "marksmanship" then circle(51,0,25,16); rays(51,0,29,37,4)
        elseif spec == "survival" then
            path({{-60,-56},{-18,-18},{13,46},{22,76},{-4,57},{-18,-18}},3)
            diamond(47,-49,20,16)
        else diamond(48,-40,14,23) end
    elseif class == "mage" then
        circle(0,32,40,20); rays(0,32,47,64,8,math.pi/8)
        path({{-7,-8},{-7,-81},{7,-81},{7,-8}},3); diamond(0,32,19,28)
    elseif class == "monk" then
        circle(-23,0,57,16); circle(23,0,57,16)
        if spec == "brewmaster" then
            path({{-18,38},{18,38},{25,0},{18,-39},{-18,-39},{-25,0},{-18,38}},3)
            line(-20,20,20,20,2); line(-20,-20,20,-20,2)
        elseif spec == "mistweaver" then wave(75); wave(-75)
        elseif spec == "windwalker" then
            arc(0,0,88,75,math.pi*.1,math.pi*1.5,14,3); path({{0,-75},{19,-83},{9,-59}},3)
        else diamond(0,0,20,32) end
    elseif class == "paladin" then
        path({{-56,64},{0,84},{56,64},{49,-16},{0,-84},{-49,-16},{-56,64}},3)
        path({{-28,27},{28,27},{28,2},{8,2},{8,-47},{-8,-47},{-8,2},{-28,2},{-28,27}},3)
        if spec == "holy" then circle(0,51,14,12); rays(0,51,20,31,8,math.pi/8)
        elseif spec == "protection" then
            path({{-42,51},{0,67},{42,51},{35,-11},{0,-61},{-35,-11},{-42,51}},2)
        elseif spec == "retribution" then
            path({{-70,-60},{-40,-40},{47,69},{64,91},{57,62},{-40,-40}},2)
            path({{70,-60},{40,-40},{-47,69},{-64,91},{-57,62},{40,-40}},2)
        else diamond(0,51,13,17) end
    elseif class == "priest" then
        circle(0,59,28,16)
        line(0,29,0,-86,3); line(-29,6,29,6,3)
        path({{-14,-15},{-45,-58},{-69,-73},{-37,-71},{-13,-50}},2)
        path({{14,-15},{45,-58},{69,-73},{37,-71},{13,-50}},2)
        if spec == "discipline" then diamond(-40,16,19,25); diamond(40,16,19,25); line(-62,-23,62,-23,2)
        elseif spec == "holy" then rays(0,59,33,41,8,math.pi/8)
        elseif spec == "shadow" then
            arc(-27,-3,51,62,math.pi*.45,math.pi*1.55,12,3)
            arc(27,-3,51,62,-math.pi*.55,math.pi*.55,12,3)
        else diamond(0,-29,11,23) end
    elseif class == "rogue" then
        local dagger={{-66,83},{-53,32},{24,-39},{37,-25},{-32,48},{-66,83}}
        path(dagger,3); path(dagger,3,-1)
        line(14,-51,49,-17,3); line(-14,-51,-49,-17,3)
        line(31,-42,55,-69,3); line(-31,-42,-55,-69,3)
        if spec == "assassination" then leaf(0,12,10,21); leaf(-57,-21,9,17); leaf(57,-21,9,17)
        elseif spec == "outlaw" then circle(0,15,34,16); rays(0,15,39,50,8)
        elseif spec == "subtlety" then
            arc(0,35,39,17,0,math.pi,8); arc(0,35,39,17,math.pi,2*math.pi,8); diamond(0,35,7,13)
        else diamond(0,22,13,21) end
    elseif class == "shaman" then
        circle(0,0,76,20)
        path({{2,63},{-34,4},{-2,10},{-13,-56},{32,12},{6,4},{2,63}},3)
        if spec == "elemental" then
            path({{-54,-36},{-69,-7},{-46,-20},{-41,6},{-25,-26},{-38,-48},{-54,-36}},2)
            path({{26,-39},{39,-24},{53,-39},{42,-55},{26,-39}},2)
        elseif spec == "enhancement" then
            path({{-51,45},{-71,3},{-51,12},{-61,-14}},3)
            path({{51,-45},{71,-3},{51,-12},{61,14}},3)
        elseif spec == "restoration" then wave(-25); wave(0); wave(25)
        else diamond(0,0,90,90) end
    elseif class == "warlock" then
        circle(0,-4,59,20)
        path({{-34,34},{-63,58},{-76,88},{-39,71},{-18,48}},3)
        path({{34,34},{63,58},{76,88},{39,71},{18,48}},3)
        line(-30,-54,-40,-78,3); line(30,-54,40,-78,3)
        if spec == "affliction" then diamond(-21,-2,11,24); diamond(0,-18,11,24); diamond(21,-2,11,24)
        elseif spec == "demonology" then
            path({{-30,23},{-15,-5},{0,15},{15,-5},{30,23},{18,-31},{0,-17},{-18,-31},{-30,23}},3)
            diamond(0,35,9,13)
        elseif spec == "destruction" then
            path({{-21,-31},{-32,-6},{-9,16},{-12,37},{13,14},{7,-3},{28,12},{31,-17},{13,-38},{-4,-46},{-21,-31}},3)
        else diamond(0,-3,24,34) end
    elseif class == "warrior" then
        local sword={{-69,88},{-68,50},{39,-55},{55,-39},{-50,68},{-69,88}}
        path(sword,3); path(sword,3,-1)
        line(27,-66,67,-27,3); line(-27,-66,-67,-27,3)
        line(50,-55,76,-85,3); line(-50,-55,-76,-85,3)
        if spec == "arms" then
            path({{0,90},{14,53},{9,-10},{-9,-10},{-14,53},{0,90}},3); line(-25,-13,25,-13,3)
        elseif spec == "fury" then
            path({{-24,12},{-37,42},{-14,29},{-18,72},{10,46},{5,24},{30,41},{24,12}},3)
        elseif spec == "protection" then
            path({{-33,44},{0,57},{33,44},{28,-13},{0,-43},{-28,-13},{-33,44}},3)
        else diamond(0,31,15,26) end
    end
end

-- Original geometric outlines; no external art or game atlas is copied. Only
-- the selected shape's short segment list is generated, then discarded.
function addon:BuildOptionsThemeMotif(kind)
    local result = {}
    local function line(x1, y1, x2, y2, width)
        result[#result + 1] = { x1, y1, x2, y2, width or 2 }
    end
    local function ring(radius, count)
        for i = 1, count do
            local a, b = (i - 1) * 2 * math.pi / count, i * 2 * math.pi / count
            line(radius * math.cos(a), radius * math.sin(a), radius * math.cos(b), radius * math.sin(b))
        end
    end
    if kind == "arcane" then
        ring(88, 28); ring(64, 20)
        line(0, 48, 38, 0, 3); line(38, 0, 0, -48, 3)
        line(0, -48, -38, 0, 3); line(-38, 0, 0, 48, 3)
        for _, angle in ipairs({ 0, math.pi / 2, math.pi, 3 * math.pi / 2 }) do
            local x, y = 76 * math.cos(angle), 76 * math.sin(angle)
            line(x - 5, y - 6, x + 5, y + 6); line(x - 5, y + 6, x + 5, y - 6)
        end
    elseif kind == "fire" then
        local outer = { {-12,94}, {16,65}, {29,39}, {22,15}, {44,34}, {68,2}, {74,-29},
            {61,-60}, {36,-81}, {0,-91}, {-36,-82}, {-61,-59}, {-70,-24}, {-60,5},
            {-37,32}, {-39,7}, {-22,24}, {-8,48}, {-12,94} }
        for i = 2, #outer do line(outer[i-1][1], outer[i-1][2], outer[i][1], outer[i][2], 3) end
        local inner = { {4,24}, {25,-6}, {30,-30}, {16,-56}, {0,-71}, {-22,-58}, {-31,-34}, {-24,-12}, {-8,-30}, {4,24} }
        for i = 2, #inner do line(inner[i-1][1], inner[i-1][2], inner[i][1], inner[i][2], 2) end
    elseif kind == "frost" then
        ring(34, 6)
        for i = 0, 5 do
            local angle = i * math.pi / 3
            local dx, dy = math.cos(angle), math.sin(angle)
            line(0, 0, 92 * dx, 92 * dy, 3)
            for _, distance in ipairs({ 48, 70 }) do
                local x, y = distance * dx, distance * dy
                line(x, y, x - 17 * dx - 14 * dy, y - 17 * dy + 14 * dx)
                line(x, y, x - 17 * dx + 14 * dy, y - 17 * dy - 14 * dx)
            end
        end
    else ClassMotif(kind, line) end
    return result
end

local _, data = ...

-- Exact inventory of the single Data TOC; all these files load together.
data.host.dataFileManifest = {
    "Bootstrap.lua",
    "Shared/SpellState.lua",
    "Shared/Adapter.lua",
    "Shared/ProcDefinitions.lua",
    "Shared/FreeMoveDefinitions.lua",
    "Classes/Mage/Bootstrap.lua",
    "Classes/Mage/MobilityEntries.lua",
    "Classes/Mage/ProcDefinitions.lua",
    "Classes/Mage/PreviewEntries.lua",
    "Classes/Mage/SpellState.lua",
    "Classes/Mage/Register.lua",
    "Classes/Mage/AdditionalMobility.lua",
    "Classes/DeathKnight/MobilityDefinitions.lua",
    "Classes/DemonHunter/MobilityDefinitions.lua",
    "Classes/Druid/MobilityDefinitions.lua",
    "Classes/Evoker/MobilityDefinitions.lua",
    "Classes/Hunter/MobilityDefinitions.lua",
    "Classes/Monk/MobilityDefinitions.lua",
    "Classes/Paladin/MobilityDefinitions.lua",
    "Classes/Priest/MobilityDefinitions.lua",
    "Classes/Rogue/MobilityDefinitions.lua",
    "Classes/Shaman/MobilityDefinitions.lua",
    "Classes/Warlock/MobilityDefinitions.lua",
    "Classes/Warrior/MobilityDefinitions.lua",
    "Classes/DeathKnight/ProcDefinitions.lua",
    "Classes/Paladin/ProcDefinitions.lua",
    "Classes/Priest/ProcDefinitions.lua",
    "Classes/Warlock/ProcDefinitions.lua",
    "Classes/Druid/ProcDefinitions.lua",
    "Classes/Shaman/ProcDefinitions.lua",
    "Classes/Evoker/ProcDefinitions.lua",
    "Classes/Rogue/ProcDefinitions.lua",
    "Complete.lua",
}
data.host.dataCodeFileCount = #data.host.dataFileManifest
local classFiles = 0
for _, path in ipairs(data.host.dataFileManifest) do
    if path:match("^Classes/") then classFiles = classFiles + 1 end
end
data.host.dataClassFileCount = classFiles
data.host.dataPackageLoaded = true

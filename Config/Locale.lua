local _, addon = ...

local english = {
    options = "Options", general = "General", typography = "Font & appearance",
    preview = "Preview", mobility = "Mobility", proc = "Proc", themes = "Themes",
    importExport = "Import / Export", unavailable = "Not implemented",
    future = "Disabled categories are reserved for future updates.",
    generalHint = "Control the display and its position relative to the screen center.",
    enabled = "Show CarGOUI display", x = "X offset", y = "Y offset",
    apply = "Apply", center = "Center position", scale = "Scale",
    positionHint = "Range: -10000 to 10000. Positive X moves right; positive Y moves up. Position uses UI coordinates.",
    appearanceHint = "Choose a built-in game font and adjust the text appearance.",
    font = "Font", fontSize = "Font size", outline = "Outline", shadow = "Text shadow",
    none = "None", normal = "Outline", thick = "Thick outline", openPreview = "View preview",
    previewHint = "Static text using your current settings. No spell or buff simulation.",
    previewFit = "Large text is fitted into this preview. The game display uses the configured scale and offsets.",
    previewHidden = "The game display is hidden; this sample is still visible here.",
    immediate = "Changes apply immediately. For typed numbers, press Enter or Apply.",
    saved = "Settings applied.", invalidPosition = "Enter X and Y from -10000 to 10000.",
    invalidFontSize = "Enter a font size from 8 to 72.", invalidScale = "Enter a scale from 0.5 to 3.",
    invalid = "Invalid setting. Check the allowed values.",
    reset = "Reset all settings", confirmReset = "Confirm reset",
    resetHint = "Click Confirm reset to restore all CarGOUI defaults.", resetDone = "Default settings restored.",
    close = "Close",
}

-- Retained for a future explicit language choice; inactive in this release.
local chinese = {
    options = "设置", general = "常规", typography = "字体与外观",
    preview = "预览", mobility = "位移提醒", proc = "触发提醒", themes = "主题",
    importExport = "导入 / 导出", unavailable = "未实现",
    future = "灰色分类尚未实现，将在后续版本开放。",
    generalHint = "调整显示开关，以及相对屏幕中心的位置。",
    enabled = "显示 CarGOUI 文字", x = "X 偏移", y = "Y 偏移",
    apply = "应用", center = "恢复居中", scale = "缩放",
    positionHint = "范围：-10000 至 10000。X 正数向右，Y 正数向上。偏移使用界面坐标单位。",
    appearanceHint = "选择游戏内置字体，调整字号、描边与阴影。",
    font = "字体", fontSize = "字号", outline = "描边", shadow = "文字阴影",
    none = "无描边", normal = "普通描边", thick = "加粗描边", openPreview = "查看预览",
    previewHint = "按当前设置显示静态文字，不模拟技能或增益效果。",
    previewFit = "过大的文字会缩小以适应预览区域；实际显示仍使用设置的缩放与偏移。",
    previewHidden = "实际显示已隐藏；此处仍可查看字体样例。",
    immediate = "设置立即生效；输入数值后请按 Enter 或点击应用。",
    saved = "设置已应用。", invalidPosition = "请输入 -10000 至 10000 的 X 和 Y 偏移。",
    invalidFontSize = "请输入 8 至 72 的字号。", invalidScale = "请输入 0.5 至 3 的缩放。",
    invalid = "设置无效，请检查允许的范围。",
    reset = "重置全部设置", confirmReset = "确认重置",
    resetHint = "再次点击确认重置，将恢复 CarGOUI 的全部默认设置。", resetDone = "已恢复默认设置。",
    close = "关闭",
}

-- This release uses English on every client; never infer UI language from GetLocale().
addon.L = english

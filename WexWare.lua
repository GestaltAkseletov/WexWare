--[=[
    WexWare Hub - Использует нативную библиотеку DeltaLibrary.
    Обеспечивает плавный интерфейс, аккордеонные вкладки и нативную логику.
]=]

-- Загрузка DeltaLibrary, как вы указали.
loadstring(game:HttpGet("https://raw.githubusercontent.com/deltaexe/DeltaLibrary/main/Library.lua"))()

-- ПРЕДПОЛОЖЕНИЕ: Библиотека Delta создает глобальную таблицу/функцию, например, 'Library' или 'DeltaUI'.
-- Если DeltaLibrary не создает глобальную переменную, нужно будет скорректировать этот код.
local Library = getgenv().Library or DeltaUI or _G.DeltaLibrary -- Называем переменную как Library для удобства

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService") -- Для работы с HEX/другими утилитами
local DataStoreService = game:GetService("DataStoreService") 

-- ** DataStore для сохранения настроек и скриптов **
local SettingsStore = DataStoreService:GetDataStore("WexWare_Delta_Settings")
local ScriptsStore = DataStoreService:GetDataStore("WexWare_Delta_Scripts")

-- ** Настройки по умолчанию (Delta обычно использует свои встроенные) **
local DefaultConfig = {
    -- В DeltaLibrary эти настройки обычно управляются самой библиотекой
    AccentColor = Color3.fromRGB(70, 130, 180), -- Используем для Custom Scripts
    CustomScripts = {},                         
    -- Позиция кнопки W и цвета меню управляются библиотекой
}
local CurrentSettings = table.clone(DefaultConfig)

-- Функция-заглушка для получения Enum.Font по строке (необходима для Delta)
local function GetFontByName(name)
    for _, font in pairs(Enum.Font:GetEnumItems()) do
        if font.Name == name then
            return font
        end
    end
    return Enum.Font.SourceSansSemibold
end

-- ** Преобразование Color3 в HEX (обычно используется в библиотеках) **
local function Color3ToHex(color3)
    local r = math.floor(color3.R * 255)
    local g = math.floor(color3.G * 255)
    local b = math.floor(color3.B * 255)
    return string.format("#%02x%02x%02x", r, g, b)
end

-- ** Основная функция загрузки и создания GUI **
local function CreateWexWareHub()
    -- ** 2. Создание главного окна **
    -- (Предполагаемые методы DeltaLibrary)
    local Window = Library:CreateWindow("WexWare", "Build. Set. Use.") -- Название и подзаголовок

    -- ** 3. Настройка и Конфиги (Загрузка данных) **
    
    local loadedSettings = SettingsStore:GetAsync("LastUsedConfig")
    if loadedSettings then
        -- В DeltaLibrary часто можно установить настройки прямо перед созданием окна
        -- Если Delta не имеет встроенной системы, мы будем сохранять только CustomScripts
        CurrentSettings.CustomScripts = ScriptsStore:GetAsync("LastUsedScripts") or {}
    end

    -- ** 4. Создание вкладок (Аккордеон)**
    
    -- Вкладки 1: Info 
    local InfoTab = Window:CreateTab("Info") 
    
    InfoTab:CreateLabel("WexWare Information")
    InfoTab:CreateParagraph({
        Text = "WexWare is a hub created by Wexdork, WexWare was created as a regular project in 2025 and is still being developed. Advantages - why choose WexWare? Because WexWare is a foundation for other enthusiasts who want to set up a convenient and pleasant hub for themselves, WexWare has smooth animations and transitions, has the ability to add their scripts and save them, also has a nice look, through the configuration you can assemble your theme and save your scripts to folders. WexWare is completely keyless, meaning you use it immediately after launch.",
        Wrap = true,
        Size = 180 -- Уменьшен размер для удобства
    })
    
    -- Вкладка 2: Settings 
    local SettingsTab = Window:CreateTab("Settings")

    -- ** Кастомизация внешности **
    SettingsTab:CreateLabel("Appearance Settings (Colors and Font)")
    
    -- 2.1. Color Picker (HEX Круг)
    -- В нативных библиотеках Colоr Picker обычно уже реализован
    -- ПРЕДПОЛОЖЕНИЕ: Delta предоставляет ColоrPicker с функцией обратного вызова
    SettingsTab:CreateColorPicker({
        Name = "Main Color",
        Default = Color3ToHex(DefaultConfig.MainColor),
        Callback = function(newColorHex)
            -- Сохранение цвета
            local newColor3 = Color3.fromHex(newColorHex)
            CurrentSettings.MainColor = newColor3
            -- В DeltaLibrary обычно есть функция для обновления UI цвета, например:
            -- Library:SetThemeColor("Main", newColor3)
        end
    })
    -- Повторить для AccentColor, BorderColor, TextColor...
    
    -- 2.2. Font Selection (Базовый выбор шрифтов)
    SettingsTab:CreateDropdown({
        Name = "Menu Font",
        Options = {"SourceSansSemibold", "Roboto", "Monospace"}, -- Базовые шрифты Roblox
        Default = DefaultConfig.Font.Name,
        Callback = function(fontName)
            CurrentSettings.Font = GetFontByName(fontName)
            -- Library:SetThemeFont(CurrentSettings.Font)
        end
    })
    
    -- ** Вкладка 3: Script's (Простой скрипт) **
    local ScriptsTab = Window:CreateTab("Script's")
    
    ScriptsTab:CreateLabel("Single Execution Script")
    ScriptsTab:CreateButton({
        Name = "Execute WexWare Script",
        Callback = function()
            ExecuteScript(SingleScriptURL)
        end
    })

    -- ** Вкладка 4: Script's Advanced (Пользовательские скрипты) **
    local AdvancedTab = Window:CreateTab("Script's Advanced")
    AdvancedTab:CreateLabel("Add Custom Scripts (loadstring/GitHub)")
    
    local NameInput = AdvancedTab:CreateTextBox({Name = "Script Name", Default = ""})
    local LinkInput = AdvancedTab:CreateTextBox({Name = "GitHub Raw Link", Default = "https://raw.githubusercontent.com/..."})
    
    AdvancedTab:CreateButton({
        Name = "Add Script & Save",
        Callback = function()
            local name = NameInput:GetText()
            local link = LinkInput:GetText()
            
            if name ~= "" and link:sub(1, 4) == "http" then
                CurrentScripts[name] = link
                NameInput:SetText("")
                LinkInput:SetText("")
                RefreshScriptsAdvancedUI(AdvancedTab)
                SaveScriptsConfig("LastUsedScripts")
            end
        end
    })
    
    -- Контейнер для динамических скриптов (обычно ScrollingFrame)
    local ScriptsContainer = AdvancedTab:CreateSection("Saved Scripts")
    
    -- ** Вкладка 5: Config's **
    local ConfigsTab = Window:CreateTab("Config's")
    
    -- 5.1. Конфиги внешности (UI/Font)
    ConfigsTab:CreateLabel("WexWare UI Configs (Appearance)")
    local SettingsConfigName = ConfigsTab:CreateTextBox({Name = "Config Name", Default = "MyTheme"})
    ConfigsTab:CreateButton({Name = "Save UI Config", Callback = function() 
        SaveSettingsConfig(SettingsConfigName:GetText()) 
    end})
    ConfigsTab:CreateButton({Name = "Load UI Config", Callback = function() 
        LoadSettingsConfig(SettingsConfigName:GetText()) 
    end})
    -- ... Кнопки Переписать/Удалить
    
    ConfigsTab:CreateDivider()

    -- 5.2. Конфиги пользовательских скриптов
    ConfigsTab:CreateLabel("Custom Scripts Configs")
    local ScriptsConfigName = ConfigsTab:CreateTextBox({Name = "Config Name", Default = "MyScripts"})
    ConfigsTab:CreateButton({Name = "Save Scripts Config", Callback = function() 
        SaveScriptsConfig(ScriptsConfigName:GetText()) 
    end})
    ConfigsTab:CreateButton({Name = "Load Scripts Config", Callback = function() 
        LoadScriptsConfig(ScriptsConfigName:GetText()) 
    end})
    -- ... Кнопки Переписать/Удалить

    -- ** 6. Финальная инициализация **

    -- Отображение окна (DeltaLibrary обычно делает это автоматически)
    -- Также DeltaLibrary обычно предоставляет кнопку W или другой переключатель
    -- Если вам нужен собственный перетаскиваемый W_Button, его придется делать отдельно (как в предыдущем ответе), но это нарушит нативный вид Delta.

    -- Обновление UI скриптов при старте
    RefreshScriptsAdvancedUI(AdvancedTab)
end

-- ** Логика Скриптов **
local SingleScriptURL = "ПОЖАЛУЙСТА, ВСТАВЬТЕ СЮДА ВАШУ ССЫЛКУ НА СКРИПТ"

local function ExecuteScript(url)
    local success, result = pcall(function()
        local scriptCode = game:HttpGet(url) 
        loadstring(scriptCode)()
        print("[WexWare] Executed:", url)
    end)
    if not success then
        warn("[WexWare] Execution Failed:", result)
    end
end

-- ** Логика Configs **

local function SaveSettingsConfig(configName)
    -- В нативной библиотеке Delta, вероятно, есть метод для получения текущих настроек UI.
    -- Если нет, мы просто сохраним то, что задали.
    local success, err = pcall(function()
        SettingsStore:SetAsync(configName, CurrentSettings)
    end)
    if success then print("[WexWare] Settings Config saved:", configName) end
end

local function LoadSettingsConfig(configName)
    local loadedData = SettingsStore:GetAsync(configName)
    if loadedData then
        -- Обновление UI с помощью методов DeltaLibrary
        -- Library:SetThemeColor("Main", loadedData.MainColor)
        -- Library:SetThemeFont(GetFontByName(loadedData.Font.Name))
        print("[WexWare] Settings Config loaded:", configName)
    end
end

local function SaveScriptsConfig(configName)
    local success, err = pcall(function()
        ScriptsStore:SetAsync(configName, CurrentScripts)
    end)
    if success then print("[WexWare] Scripts Config saved:", configName) end
end

local function LoadScriptsConfig(configName)
    CurrentScripts = ScriptsStore:GetAsync(configName) or {}
    print("[WexWare] Scripts Config loaded:", configName)
    -- Обновляем UI после загрузки
    CreateWexWareHub() -- Пересоздание хаба для обновления элементов
end

-- ** Обновление UI Скриптов **

local function RefreshScriptsAdvancedUI(AdvancedTab)
    -- Удалить предыдущие кнопки (зависит от API DeltaLibrary)
    -- AdvancedTab:ClearSection("Saved Scripts") 

    local ScriptsContainer = AdvancedTab:GetSection("Saved Scripts") -- Получаем контейнер
    
    -- Создание новых кнопок для каждого скрипта
    for name, link in pairs(CurrentScripts) do
        ScriptsContainer:CreateButton({
            Name = name,
            Callback = function()
                ExecuteScript(link)
            end
        })
    end
end

-- ** Запуск **
LoadSettingsConfig("LastUsedConfig") -- Загрузить настройки при старте
CreateWexWareHub()

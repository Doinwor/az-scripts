script_name("WebMobile")
script_author("Radare")
script_description("webviews like a browser")
script_version("1.0 Beta")

local jar = require("webviews")
local fa = require('fAwesome6_solid')
local jsoncfg = require("jsoncfg")
local imgui = require("mimgui")
local ffi = require("ffi")
local inicfg = require("inicfg")
local cjson = require("cjson")
local envu = require("android.jnienv-util")
envu.LooperPrepare()
local settings = inicfg.load({
    theme = {
        moonmonet = 0
    }
}, "webmobile.ini")

local gta = ffi.load('GTASA')
ffi.cdef[[void _Z12AND_OpenLinkPKc(const char* link);]]

local loadcolors, monet = pcall(require, "MoonMonet")
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8

local tabs, logs = jsoncfg.load({{id=0, name="Google", url="https://google.com", next = {}, back = {}}}), {}

local new, str, sizeof = imgui.new, ffi.string, ffi.sizeof
local renderWindow, logsWindow = new.bool(false), new.bool(false)
local tabOpen, addressLine, checkOpen, tabFreeze, isBack = -1, new.char[144](), false, {count=50, id=-1}, false
local tabPositions = {x = 0, y = 0, sw = 0, sh = 0}

imgui.OnInitialize(function()
    fa.Init()
    if loadcolors then
      imgui.Theme() 
      local tmp = imgui.ColorConvertU32ToFloat4(settings.theme['moonmonet'])
      mmcolor = imgui.new.float[3](tmp.z, tmp.y, tmp.x)
    end
end)

imgui.OnFrame(function() return logsWindow[0] end,
  function(player)
      imgui.Begin("WebMobileLogs", logsWindow)
      for i, log in ipairs(logs) do imgui.Text(log) end
      if imgui.GetScrollY() >= imgui.GetScrollMaxY() then
        imgui.SetScrollHereY(1.0)
      end
      imgui.End()
end
)

imgui.OnFrame(function() return renderWindow[0] end,
  function(player)
      imgui.SetNextWindowFocus()
      imgui.Begin("WebMobile", renderWindow)
      if imgui.BeginTabBar('Tabs') then
          for i, tab in ipairs(tabs) do
              if imgui.BeginTabItem(tab.id..". "..tab.name, nil, isTabLocked(tab.id)) then
                if tabOpen ~= tab.id then
                  hideAllBrowsers()
                  tabOpen = tab.id
                  isSettingsOpen = false
                  if not isBrowserCreated(tab.id) then
                    jar.createBrowser(tab.id, tab.url)
                    jar.setClickable(tab.id, true)
                    jar.setVisible(tab.id, true)
                    tab.load = false
                    showToast("Загрузка. Пожалуйста подождите...")
                  elseif jar.getStatus(tab.id) then
                    jar.setClickable(tab.id, true)
                    jar.setVisible(tab.id, true)
                  end 
                  imgui.StrCopy(addressLine, tab.url)
                  tabPositions = {x = 0, y = 0, sw = 0, sh = 0}
                end
                if tabPositions.x ~= imgui.GetWindowPos().x or tabPositions.y ~= imgui.GetWindowPos().y then jar.setPos(tab.id, imgui.GetWindowPos().x + imgui.GetCursorPos().x, imgui.GetWindowPos().y + imgui.GetCursorPos().y) end
                if tabPositions.sh ~= imgui.GetWindowContentRegionMax().y or tabPositions.sw ~= imgui.GetWindowContentRegionMax().x then jar.setSize(tab.id, imgui.GetWindowContentRegionMax().x, imgui.GetWindowContentRegionMax().y-170) end
                tabPositions = {x = imgui.GetWindowPos().x, y = imgui.GetWindowPos().y, sw = imgui.GetWindowContentRegionMax().x, sh = imgui.GetWindowContentRegionMax().y}
                if imgui.GetWindowSize().x < 500 then imgui.SetWindowSizeVec2(imgui.ImVec2(500, imgui.GetWindowSize().y)) end
                if imgui.GetWindowSize().y < 500 then imgui.SetWindowSizeVec2(imgui.ImVec2(imgui.GetWindowSize().x, 500)) end

                if isSettingsOpen then
                  local buttonCount = 4
                  local buttonHeight, buttonWidth = (imgui.GetContentRegionAvail().y - 75 - (buttonCount - 1) * 5) / buttonCount, imgui.GetContentRegionAvail().x
                  if imgui.Button(fa.CIRCLE_XMARK..u8' Закрыть вкладку', imgui.ImVec2(buttonWidth, buttonHeight)) then
                      removeBrowserById(tab.id)
                      showToast("Вкладка закрыта.")
                  end
                  if imgui.Button(fa.ARROW_UP_RIGHT_FROM_SQUARE..u8' Открыть в браузере', imgui.ImVec2(buttonWidth, buttonHeight)) then
                      gta._Z12AND_OpenLinkPKc(tab.url)
                      showToast("Открываем в браузере..")
                  end
                  if imgui.Button(fa.BROOM..u8' Очистить историю вкладки', imgui.ImVec2(buttonWidth, buttonHeight)) then
                      setBrowserValue(tab.id, "back", {})
                      setBrowserValue(tab.id, "next", {})
                      showToast("История очищена!")
                  end
                  if imgui.Button(fa.BROOM..(tab.muted and u8" Включить" or u8" Отключить")..u8' звук (no stable)', imgui.ImVec2(buttonWidth, buttonHeight)) then
                      showToast("Звук на вкладке "..(tab.muted and "включен" or "отключен").."!")
                      tab.muted = not tab.muted
                      jar.executeJS(tab.id, "document.querySelectorAll('video, audio').forEach(el => el.muted = "..(tab.muted and "true" or "false")..");")
                  end
                end
                imgui.SetCursorPosY(imgui.GetWindowSize().y / 2)
                if tab.crash == true then
                  imgui.CenterText("Данная вкладка сломалась (crash) :(\nПопробуйте перезагрузить страницу.") 
                  imgui.SameLine()
                  if imgui.Button(fa.RETWEET) then tabOpen = -1 end 
                elseif tab.load ~= true then 
                  imgui.CenterText(u8"Загрузка страницы.. (если здесь ничего не появилось за долгое время, скорее всего произошла ошибка)") 
                end
                imgui.SetCursorPosY(imgui.GetWindowContentRegionMax().y-50)
                if type(tab.progress) == "number" and tab.progress < 100 and not tab.crash then
                  imgui.Text(tab.progress.."%%")
                  imgui.SameLine()
                end
                if getBrowserMassive(tab.id, "back", true) then
                  if imgui.Button(fa.ARROW_LEFT) then setPage(tab.id, false) end
                  imgui.SameLine()
                end
                if getBrowserMassive(tab.id, "next", true) then
                  if imgui.Button(fa.ARROW_RIGHT) then setPage(tab.id, true) end
                  imgui.SameLine()
                end
                if imgui.Button(fa.RETWEET) then changeUrl(tab.id, tab.url) end
                imgui.SameLine()
                imgui.InputTextWithHint('##search', u8'Введите запрос или URL', addressLine, ffi.sizeof(addressLine))
                imgui.SameLine()
                if imgui.Button(u8"Перейти "..fa.ARROW_RIGHT) and ffi.string(addressLine) ~= tab.url then changeUrl(tab.id, ffi.string(addressLine)) end
                imgui.SameLine()
                if imgui.Button(u8(isSettingsOpen and "Вкладка " or "Настройки ")..fa.ELLIPSIS_VERTICAL) then 
                  isSettingsOpen = not isSettingsOpen
                  jar.setVisible(tab.id, not isSettingsOpen)
                end
                imgui.EndTabItem()
              end
          end
          if imgui.BeginTabItem('+') then
            if tabOpen ~= -2 then
              hideAllBrowsers()
              tabOpen = -2
              imgui.StrCopy(addressLine, "")
            end
            local input_width = imgui.CalcItemWidth()
            imgui.SetCursorPosY(imgui.GetWindowSize().y / 2)
            imgui.SetCursorPosX((imgui.GetWindowContentRegionMax().x - input_width) / 2);
            imgui.InputTextWithHint('##search', u8'Введите запрос или URL', addressLine, ffi.sizeof(addressLine))
            imgui.SameLine()
            if imgui.Button("->") then
              local url = ffi.string(addressLine)
              if not string.match(url, "^([%w%-]+)%.([a-zA-Z]+)$") then url = "https://google.com/search?q="..url end
              created = addBrowser(u8"Новая вкладка", url)
              lockTab(created)
            end
            imgui.SetCursorPosX((imgui.GetWindowContentRegionMax().x - input_width) / 2); 
            if loadcolors then
              if imgui.ColorEdit3('##ColorsTheme', mmcolor) then
                  r,g,b = mmcolor[0] * 255, mmcolor[1] * 255, mmcolor[2] * 255
                  argb = join_argb(0, r, g, b)
                  settings.theme.moonmonet = argb
                  inicfg.save(settings, 'webmobile.ini')
                  imgui.Theme()
              end
              imgui.SameLine()
              if imgui.Button(fa.RAINBOW) then
                isRainbowColors = not isRainbowColors
              end
            else imgui.Text("Please install MoonMonet :(") end
            imgui.SetCursorPosY(imgui.GetWindowSize().y-55)
            if imgui.Button(fa.CLIPBOARD_LIST) then logsWindow[0] = not logsWindow[0] end
            imgui.SetCursorPosY(imgui.GetWindowSize().y-35)
            imgui.SameLine()
            imgui.Text("Maded by Radare (t.me/ryderinc) | Version: "..thisScript().version.." | Version WebViews library: "..jar.getVersion().name)
            imgui.EndTabItem()
          end
      end
      if isRainbowColors then rainbowColors() end
      imgui.End()
  end
)

function rainbowColors()
    speed = 1
    local clock = os.clock()
    local r = math.floor(math.sin(clock * speed) * 127 + 128)
    local g = math.floor(math.sin(clock * speed + 2) * 127 + 128)
    local b = math.floor(math.sin(clock * speed + 4) * 127 + 128)
    argb = join_argb(0, r, g, b)
    settings.theme.moonmonet = argb
    imgui.Theme()
end

function main()
  wait(500)
  table.sort(tabs, function(a, b) return a.id < b.id end)
  sampRegisterChatCommand("wm", function() renderWindow[0] = not renderWindow[0] end)
  showToast("WebMobile успешно загружен! Build: "..thisScript().version)
  while true do
    wait(0)
    if checkOpen ~= renderWindow[0] then
      if checkOpen then
        hideAllBrowsers()
        tabOpen = -1
      else
          for i, tab in ipairs(tabs) do
          jar.createBrowser(tab.id, tab.url)
      end 
      end
    end
    checkOpen = renderWindow[0]
  end
end

function hideAllBrowsers() for i, id in ipairs(jar.getBrowsers()) do jar.setVisible(id, false) end end

function isBrowserCreated(id)
  for _, browserId in ipairs(jar.getBrowsers()) do
      if browserId == id then
          return true
      end
  end
  return false
end

function jar.onAction(data)
  if data.type == "WV_STARTED" then
    setBrowserValue(data.browserid, "crash", false)
    setBrowserValue(data.browserid, "load", false)
    setBrowserValue(data.browserid, "url", data.msg)
    if isBack then addBrowserMassive(data.browserid, "next", getBrowserValue(data.browserid, "url"))
    else addBrowserMassive(data.browserid, "back", getBrowserValue(data.browserid, "url")) end
    isBack = false
  elseif data.type == "WV_LOADED" then
    setBrowserValue(data.browserid, "load", true)
    setBrowserValue(data.browserid, "url", data.msg)
    jar.executeJS(data.browserid, "console.log(JSON.stringify({ type: \"title\", title: document.title }));")
    jar.executeJS(data.browserid, "new MutationObserver((m) => m.forEach((e) => e.type === 'childList' && console.log(JSON.stringify({ type: \"title\", title: document.title })))) .observe(document.querySelector('title'), { childList: true });")
    jar.executeJS(data.browserid, "document.querySelectorAll('video, audio').forEach(el => el.muted = "..(getBrowserValue(data.browserid, "muted") and "true" or "false")..");")
    if tabOpen == data.browserid then imgui.StrCopy(addressLine, data.msg) end
  elseif data.type == "WV_ANSWER" then
    local success, json = pcall(cjson.decode, data.msg)
    if success and json.type == "title" then
      if data.browserid == tabOpen then lockTab(data.browserid) end
      setBrowserValue(data.browserid, "name", json.title)
    end
  elseif data.type == "WV_PROGRESS" then
    local progress = getBrowserValue(data.browserid, "progress")
    if progress ~= nil and progress < 100 and tonumber(data.msg) > progress then setBrowserValue(data.browserid, "progress", tonumber(data.msg)) end
  elseif data.type == "WV_DIE" then
    setBrowserValue(data.browserid, "crash", true)
    jar.deleteBrowser(data.browserid)
  elseif data.type == "WV_LOG" then
      table.insert(logs, data.msg)
  end
end

function lockTab(id) tabFreeze = {count=50, id=id} end
function isTabLocked(id) 
     if tabFreeze.id == id and tabFreeze.count > 0 then 
        tabFreeze.count =  tabFreeze.count - 1
        return 2
      else return 0 end 
end

function setPage(id, isNext)
  isBack = not isNext
  goUrl = getBrowserMassive(id, (isNext and "next" or "back"), false)
  if goUrl then changeUrl(id, goUrl) end
end

function addBrowser(name, url)
    local min_id = 1

    for _, browser in ipairs(tabs) do
        if browser.id >= min_id then
            min_id = browser.id + 1
        end
    end

    table.insert(tabs, { id = min_id, name = name, url = url, back = {}, next = {}})
    jsoncfg.save(tabs)
    return min_id
end

 function removeBrowserById(id)
    for i, browser in ipairs(tabs) do
        if browser.id == id then
            if isBrowserCreated(id) then jar.deleteBrowser(id) end
            table.remove(tabs, i)
            jsoncfg.save(tabs)
            return
        end
    end
    print("Browser with ID " .. id .. " not found")
end 

function setBrowserValue(id, key, value)
  for _, browser in ipairs(tabs) do
      if browser.id == id then
          browser[key] = value
          jsoncfg.save(tabs) 
          return
      end
  end
  print("Browser with ID " .. id .. " not found")
end 

function getBrowserValue(id, key)
  for _, browser in ipairs(tabs) do
      if browser.id == id then
          return browser[key]
      end
  end
  print("Browser with ID " .. id .. " not found")
  return nil
end 

function addBrowserMassive(id, key, value)
  for _, browser in ipairs(tabs) do
      if browser.id == id then
          if getBrowserMassive(id, key, true) ~= value then
            table.insert(browser[key], value)
            jsoncfg.save(tabs) 
            return
          end
      end
  end
  print("Browser with ID " .. id .. " not found")
end

function getBrowserMassive(id, key, check)
  for _, browser in ipairs(tabs) do
      if browser.id == id then
          local lastIndex = #browser[key]
          local keyTab = browser[key]
          local lastTab = keyTab[lastIndex]
          if not check then 
            table.remove(browser[key], lastIndex)
          end
          jsoncfg.save(tabs) 
          return lastTab
      end
  end
  print("Browser with ID " .. id .. " not found")
  return nil
end


function showToast(msg)
  local toast = envu.Toast(u8(msg))
  toast.show()
end

function scriptPrint(msg)
  origPrint(msg)
  if type(msg) == "string" then jar.addLog(msg) end
end

function changeUrl(id, url)
  showToast("Загрузка. Пожалуйста подождите...")
  jar.changeUrl(id, url)
end

origPrint = print
print = scriptPrint


function onScriptTerminate(s, q)
  if s == thisScript() then 
    hideAllBrowsers()
    for i, id in ipairs(jar.getBrowsers()) do
      jar.deleteBrowser(id) 
    end 
  end
end

function imgui.Theme()
  imgui.SwitchContext()
  local style = imgui.GetStyle()
  local colors = style.Colors
  local clr = imgui.Col
  local ImVec4 = imgui.ImVec4
  local generated_color = monet.buildColors(settings.theme.moonmonet, 1.0, true)

  style.WindowPadding = imgui.ImVec2(5, 5)
  style.FramePadding = imgui.ImVec2(10, 10)
  style.ItemSpacing = imgui.ImVec2(10, 10)
  style.ItemInnerSpacing = imgui.ImVec2(5, 5)
  style.TouchExtraPadding = imgui.ImVec2(5 * MONET_DPI_SCALE, 5 * MONET_DPI_SCALE)
  style.IndentSpacing = 0
  style.ScrollbarSize = 20 * MONET_DPI_SCALE
  style.GrabMinSize = 20 * MONET_DPI_SCALE

  style.WindowBorderSize = 1
  style.ChildBorderSize = 1
  style.PopupBorderSize = 1
  style.FrameBorderSize = 1
  style.TabBorderSize = 1

  style.WindowRounding = 5
  style.ChildRounding = 5
  style.FrameRounding = 5
  style.PopupRounding = 5
  style.ScrollbarRounding = 5
  style.GrabRounding = 5
  style.TabRounding = 5

  style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
  style.ButtonTextAlign = imgui.ImVec2(0.5, 0.5)
  style.SelectableTextAlign = imgui.ImVec2(0.5, 0.5)

  colors[clr.Text] = ColorAccentsAdapter(generated_color.accent2.color_50):as_vec4()
  colors[clr.TextDisabled] = ColorAccentsAdapter(generated_color.neutral1.color_600):as_vec4()
  colors[clr.WindowBg] = ColorAccentsAdapter(generated_color.accent2.color_900):as_vec4()
  colors[clr.ChildBg] = ColorAccentsAdapter(generated_color.accent2.color_800):as_vec4()
  colors[clr.PopupBg] = ColorAccentsAdapter(generated_color.accent2.color_700):as_vec4()
  colors[clr.Border] = ColorAccentsAdapter(generated_color.accent1.color_200):apply_alpha(0xcc):as_vec4()
  colors[clr.Separator] = ColorAccentsAdapter(generated_color.accent1.color_200):apply_alpha(0xcc):as_vec4()
  colors[clr.BorderShadow] = imgui.ImVec4(0.00, 0.00, 0.00, 0.00)
  colors[clr.FrameBg] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0x60):as_vec4()
  colors[clr.FrameBgHovered] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0x70):as_vec4()
  colors[clr.FrameBgActive] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0x50):as_vec4()
  colors[clr.TitleBg] = ColorAccentsAdapter(generated_color.accent2.color_700):apply_alpha(0xcc):as_vec4()
  colors[clr.TitleBgCollapsed] = ColorAccentsAdapter(generated_color.accent2.color_700):apply_alpha(0x7f):as_vec4()
  colors[clr.TitleBgActive] = ColorAccentsAdapter(generated_color.accent2.color_700):as_vec4()
  colors[clr.MenuBarBg] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0x91):as_vec4()
  colors[clr.ScrollbarBg] = imgui.ImVec4(0,0,0,0)
  colors[clr.ScrollbarGrab] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0x85):as_vec4()
  colors[clr.ScrollbarGrabHovered] = ColorAccentsAdapter(generated_color.accent1.color_600):as_vec4()
  colors[clr.ScrollbarGrabActive] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0xb3):as_vec4()
  colors[clr.CheckMark] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0xcc):as_vec4()
  colors[clr.SliderGrab] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0xcc):as_vec4()
  colors[clr.SliderGrabActive] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0x80):as_vec4()
  colors[clr.Button] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0xcc):as_vec4()
  colors[clr.ButtonHovered] = ColorAccentsAdapter(generated_color.accent1.color_600):as_vec4()
  colors[clr.ButtonActive] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0xb3):as_vec4()
  colors[clr.Tab] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0xcc):as_vec4()
  colors[clr.TabActive] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0xb3):as_vec4()
  colors[clr.TabHovered] = ColorAccentsAdapter(generated_color.accent1.color_600):as_vec4()
  colors[clr.Header] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0xcc):as_vec4()
  colors[clr.HeaderHovered] = ColorAccentsAdapter(generated_color.accent1.color_600):as_vec4()
  colors[clr.HeaderActive] = ColorAccentsAdapter(generated_color.accent1.color_600):apply_alpha(0xb3):as_vec4()
  colors[clr.ResizeGrip] = ColorAccentsAdapter(generated_color.accent2.color_700):apply_alpha(0xcc):as_vec4()
  colors[clr.ResizeGripHovered] = ColorAccentsAdapter(generated_color.accent2.color_700):as_vec4()
  colors[clr.ResizeGripActive] = ColorAccentsAdapter(generated_color.accent2.color_700):apply_alpha(0xb3):as_vec4()
  colors[clr.PlotLines] = ColorAccentsAdapter(generated_color.accent2.color_600):as_vec4()
  colors[clr.PlotLinesHovered] = ColorAccentsAdapter(generated_color.accent1.color_600):as_vec4()
  colors[clr.PlotHistogram] = ColorAccentsAdapter(generated_color.accent2.color_600):as_vec4()
  colors[clr.PlotHistogramHovered] = ColorAccentsAdapter(generated_color.accent1.color_600):as_vec4()
  colors[clr.TextSelectedBg] = ColorAccentsAdapter(generated_color.accent1.color_600):as_vec4()
  colors[clr.ModalWindowDimBg] = ColorAccentsAdapter(generated_color.accent1.color_200):apply_alpha(0x26):as_vec4()
end

function ColorAccentsAdapter(color)
    local a, r, g, b = explode_argb(color)
    local ret = {a = a, r = r, g = g, b = b}
    function ret:apply_alpha(alpha)
        self.a = alpha
        return self
    end
    function ret:as_u32()
        return join_argb(self.a, self.b, self.g, self.r)
    end
    function ret:as_vec4()
        return imgui.ImVec4(self.r / 255, self.g / 255, self.b / 255, self.a / 255)
    end
    function ret:as_argb()
        return join_argb(self.a, self.r, self.g, self.b)
    end
    function ret:as_rgba()
        return join_argb(self.r, self.g, self.b, self.a)
    end
    return ret
end

function explode_argb(argb)
    local a = bit.band(bit.rshift(argb, 24), 0xFF)
    local r = bit.band(bit.rshift(argb, 16), 0xFF)
    local g = bit.band(bit.rshift(argb, 8), 0xFF)
    local b = bit.band(argb, 0xFF)
    return a, r, g, b
end

function join_argb(a, r, g, b)
    local argb = b
    argb = bit.bor(argb, bit.lshift(g, 8))
    argb = bit.bor(argb, bit.lshift(r, 16))
    argb = bit.bor(argb, bit.lshift(a, 24))
    return argb
end

function imgui.CenterText(text)
    local width = imgui.GetWindowWidth()
    local height = imgui.GetWindowHeight()
    local calc = imgui.CalcTextSize(text)
    imgui.SetCursorPosX( width / 2 - calc.x / 2 )
    imgui.Text(text)
end

EXPORTS = {
   canToggle = function() return true end,
   getToggle = function() return renderWindow[0] end,
   toggle = function() renderWindow[0] = not renderWindow[0] end
}
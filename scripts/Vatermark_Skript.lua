script_author("OSPx | t.me/monetbinder")
script_name("Watermarks")
script_description("Больше подобных скриптов в тгк t.me/monetbinder")
script_version("1.0")


local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8

local ffi = require 'ffi'
local jsoncfg = require 'jsoncfg'
local imgui = require 'mimgui'

local cfgFile = "Watermarks.json"
local cfg = jsoncfg.load({
  watermarks = {}
}, cfgFile)

local watermarksDir = getWorkingDirectory() .. "/config/watermarks"
if not doesDirectoryExist(getWorkingDirectory() .. "/config") then
  createDirectory(getWorkingDirectory() .. "/config")
end
if not doesDirectoryExist(watermarksDir) then
  createDirectory(watermarksDir)
end

local MDS = MONET_DPI_SCALE
local sx, sy = getScreenResolution()

local window = imgui.new.bool(false)
local urlInput = imgui.new.char[256]()
local downloadProgress = {}

local WaterMarkM = {}
function WaterMarkM.new(data)
  local self = {
    path = data.path,
    size = data.size or { 0, 0 },
    position = data.position or { 0, 0 },
    opacity = imgui.new.float(data.opacity or 1),
    visible = imgui.new.bool(data.visible == nil and true or data.visible),
    movable = imgui.new.bool(data.movable == true),
    texture = data.texture
  }

  setmetatable(self, { __index = WaterMarkM })
  return self
end

function WaterMarkM:decode()
  return {
    path = self.path,
    size = self.size,
    position = self.position,
    opacity = self.opacity[0],
    visible = self.visible[0],
    movable = self.movable[0]
  }
end

local WaterMarks = {}
for i, data in ipairs(cfg.watermarks) do
  table.insert(WaterMarks, WaterMarkM.new(data))
end

imgui.OnInitialize(function()
  imgui.GetIO().IniFilename = nil
  imgui.GetStyle():ScaleAllSizes(MDS)

  for i, watermark in ipairs(WaterMarks) do
    watermark.texture = imgui.CreateTextureFromFile(watermark.path)
  end
end)

imgui.OnFrame(function() return window[0] end,
  function()
    imgui.SetNextWindowSize(imgui.ImVec2(400, 300), imgui.Cond.FirstUseEver)
    imgui.SetNextWindowPos(imgui.ImVec2(sx / 2, sy / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
    imgui.Begin(u8 'Watermarks', window)

    local middle = GetMiddleButtonX(#WaterMarks > 4 and 4 or #WaterMarks)
    for i, watermark in ipairs(WaterMarks) do
      local isLastInLine = i % 4 == 0
      local isLastLine = #WaterMarks - i < 4

      local choosed = currentWaterMark == i
      if choosed then
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.5, 0.5, 0.5, 1))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.5, 0.5, 0.5, 1))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.5, 0.5, 0.5, 1))
      end
      if imgui.Button(basename(watermark.path) .. "##" .. i, imgui.ImVec2(middle, 20 * MDS)) then
        currentWaterMark = i
      end
      if choosed then
        imgui.PopStyleColor(3)
      end

      if not isLastInLine and i ~= #WaterMarks then
        imgui.SameLine()
      else
        middle = GetMiddleButtonX(isLastLine and #WaterMarks - i or 4)
      end
    end
    imgui.SetNextItemWidth(imgui.GetWindowWidth() * 0.75 - imgui.GetStyle().ItemSpacing.x)
    imgui.InputTextWithHint("##urlinput", u8("URL изображения (png)"), urlInput, 256)
    imgui.SameLine()

    local ok = validateURL(ffi.string(urlInput))
    local file = checkForFileExtURL(ffi.string(urlInput), "png")
    if ButtonDisabled(u8("Загрузить"), imgui.ImVec2(-1, 0), not ok or downloadProgress.pos) then
      downloadProgress = {
        pos = 0,
        total = 0,
      }
      local filepath = watermarksDir .. "/" .. (file and file or generateUniqueFileName(10, ".png"))
      downloadToFile(ffi.string(urlInput), filepath, function(type, pos, total_size)
        if type == "downloading" then
          downloadProgress.pos = pos
          print(pos, total_size)
          downloadProgress.total = total_size
        elseif type == "finished" then
          downloadProgress = {}

          local width, height = get_image_size(filepath)
          if not width then
            downloadProgress.error = height
            return
          end

          local watermark = WaterMarkM.new({
            path = filepath,
            size = { width*MDS, height*MDS },
            position = { 0, 0 },
            opacity =  100.0,
            visible = true,
            texture = imgui.CreateTextureFromFile(filepath)
          })

          table.insert(WaterMarks, watermark)
          table.insert(cfg.watermarks, watermark:decode())
          jsoncfg.save(cfg, cfgFile)
        elseif type == "error" then
          downloadProgress = {error = pos}
        end
      end)
    end

    if not downloadProgress.error and downloadProgress.pos then
      imgui.Text(u8("Загружено: " ..
        math.floor(downloadProgress.pos / 1024) .. " КБ / " .. math.floor(downloadProgress.total / 1024) .. " КБ"))
    elseif downloadProgress.error then
      imgui.Text(u8("Ошибка загрузки: " .. downloadProgress.error))
    end
    imgui.Separator()
    local watermark = WaterMarks[currentWaterMark]

    if watermark then
      TextCentered(u8(basename(watermark.path)))
      if imgui.Button(u8("Удалить"), imgui.ImVec2(GetMiddleButtonX(2), 20 * MDS)) then
        table.remove(WaterMarks, currentWaterMark)
        table.remove(cfg.watermarks, currentWaterMark)
        jsoncfg.save(cfg, cfgFile)
      end
      imgui.SameLine()
      if imgui.Button(u8("Сохранить"), imgui.ImVec2(GetMiddleButtonX(2), 20 * MDS)) then
        cfg.watermarks[currentWaterMark] = watermark:decode()
        jsoncfg.save(cfg, cfgFile)
      end
      imgui.Checkbox(u8("Отображать"), watermark.visible)
      imgui.Checkbox(u8("Перемещение"), watermark.movable)
      imgui.SliderFloat("##opacity", watermark.opacity, 0.0, 100.0, u8 "Непрозрачность %.2f")
    end
    imgui.End()
  end)

imgui.OnFrame(function() return #WaterMarks > 0 end,
  function()
    for i, watermark in ipairs(WaterMarks) do
      if watermark.visible[0] then
        local pos = watermark.position
        local size = watermark.size
        local opacity = watermark.opacity[0]

        local flags = imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoScrollbar
        if not watermark.movable[0] then
          flags = flags + imgui.WindowFlags.NoMove + imgui.WindowFlags.NoResize
              + imgui.WindowFlags.NoBackground
        end

        imgui.SetNextWindowPos(imgui.ImVec2(pos[1], pos[2]), imgui.Cond.Once)
        imgui.SetNextWindowSize(imgui.ImVec2(size[1], size[2]), imgui.Cond.Once)
        imgui.Begin(u8 "##watermark" .. i, watermark.visible, flags)
        local s = imgui.GetWindowSize()
        local pos = imgui.GetWindowPos()

        imgui.SetCursorPos(imgui.ImVec2(0, 0))
        imgui.Image(watermark.texture, s, imgui.ImVec2(0, 0), imgui.ImVec2(1, 1), imgui.ImVec4(255,255,255, opacity * 0.01))

        local active = imgui.IsItemHovered()
        imgui.End()

        if watermark.movable[0] then
          if active then
            watermark.position = { pos.x, pos.y }
            watermark.size = { s.x, s.y }

            cfg.watermarks[i] = watermark:decode()
            jsoncfg.save(cfg, cfgFile)
            print(watermark.position[1], watermark.position[2], watermark.size[1], watermark.size[2])
          end
        end
      end
    end
  end)

sampRegisterChatCommand("wm", function()
  window[0] = not window[0]
end)

function GetMiddleButtonX(count)
  local width = imgui.GetWindowContentRegionWidth()
  local space = imgui.GetStyle().ItemSpacing.x
  return count == 1 and width or width / count - ((space * (count - 1)) / count)
end

function validateURL(url)
  return url:match("^https?://[%w-_%.%?%.:/%+=&]+$")
end

function checkForFileExtURL(url, ext)
  local file = url:match("([^/]+)$")
  if not file then return nil end

  local extension = file:match("%.(.-)$")
  if not extension then return nil end

  return file
end

math.randomseed(os.time())
function generateUniqueFileName(length, extension)
    local chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local function fileExists(name)
        local f = io.open(name, "r")
        if f then f:close() return true else return false end
    end

    local function generateRandomFileName()
        local fileName = ''
        for _ = 1, length do
            local index = math.random(1, #chars)
            fileName = fileName .. chars:sub(index, index)
        end
        return fileName .. extension
    end

    local fileName = generateRandomFileName()
    while fileExists(fileName) do
        fileName = generateRandomFileName()
    end

    return fileName
end

function basename(path)
  return path:match("^.+/(.+)$")
end

function TextCentered(text)
  local size = imgui.CalcTextSize(text)
  local x = (imgui.GetWindowWidth() - size.x) / 2
  imgui.SetCursorPosX(x)
  imgui.Text(text)
end

function ButtonDisabled(text, size, cond)
  if cond then
    local color = imgui.ImVec4(0.5, 0.5, 0.5, 1)
    imgui.PushStyleColor(imgui.Col.Button, color)
    imgui.PushStyleColor(imgui.Col.ButtonHovered, color)
    imgui.PushStyleColor(imgui.Col.ButtonActive, color)
  end

  local result = imgui.Button(text, size)

  if cond then
    imgui.PopStyleColor(3)
  end

  return not cond and result
end



ffi.cdef[[
typedef struct {
    uint8_t  signature[8];
    uint32_t length;
    char     type[4];
    uint32_t width;
    uint32_t height;
} PNGHeader;

typedef struct {
    uint16_t bfType;
    uint32_t bfSize;
    uint16_t bfReserved1;
    uint16_t bfReserved2;
    uint32_t bfOffBits;
    uint32_t biSize;
    uint32_t biWidth;
    uint32_t biHeight;
} BMPHeader;

typedef struct {
    uint8_t  marker[2];
    uint16_t code;
    uint16_t length;
} JPEGSegment;
]]

local function swap_endian_32(value)
    return bit.bor(
        bit.lshift(bit.band(value, 0x000000FF), 24),
        bit.lshift(bit.band(value, 0x0000FF00), 8),
        bit.rshift(bit.band(value, 0x00FF0000), 8),
        bit.rshift(bit.band(value, 0xFF000000), 24)
    )
end

local function swap_endian_16(value)
    return bit.bor(
        bit.lshift(bit.band(value, 0x00FF), 8),
        bit.rshift(bit.band(value, 0xFF00), 8)
    )
end

local function read_png_size(header)
    local png_header = ffi.cast("PNGHeader*", header)
    local width = swap_endian_32(tonumber(png_header.width))
    local height = swap_endian_32(tonumber(png_header.height))
    return width, height
end

local function read_bmp_size(header)
    local bmp_header = ffi.cast("BMPHeader*", header)
    local width = swap_endian_32(tonumber(bmp_header.biWidth))
    local height = swap_endian_32(tonumber(bmp_header.biHeight))
    return width, height
end

local function read_jpeg_size(file)
    local width, height = 0, 0
    local found_sof = false

    while true do
        local segment = file:read(6)
        if not segment or #segment < 6 then
            break
        end

        local jpeg_segment = ffi.cast("JPEGSegment*", segment)
        local marker = string.char(jpeg_segment.marker[0], jpeg_segment.marker[1])
        local code = swap_endian_16(jpeg_segment.code)
        local length = swap_endian_16(jpeg_segment.length)

        if marker == "\xFF\xC0" or marker == "\xFF\xC2" then
            -- SOF0 or SOF2 segment
            found_sof = true
            local data = file:read(length - 6)
            local width_ptr = ffi.cast("uint16_t*", data)
            local height_ptr = ffi.cast("uint16_t*", data + 2)
            width = swap_endian_16(width_ptr[0])
            height = swap_endian_16(height_ptr[0])
            break
        elseif marker == "\xFF\xD9" then
            -- EOI marker
            break
        else
            -- Skip other segments
            file:read(length - 6)
        end
    end

    if found_sof then
        return width, height
    else
        return nil, "Failed to find SOF segment in JPEG file"
    end
end

function get_image_size(file_path)
    local file = io.open(file_path, "rb")
    if not file then
        return nil, "Cannot open file"
    end

    -- Read the file header
    local header = file:read(24)
    file:seek("set", 0)

    if not header then
        file:close()
        return nil, "Failed to read file header"
    end

    -- Check the file type
    local signature = string.sub(ffi.string(header, 8), 1, 4)
    if signature == "\137PNG" then
        -- PNG file
        return read_png_size(header)
    elseif signature == "BM" then
        -- BMP file
        return read_bmp_size(header)
    elseif string.sub(ffi.string(header, 1, 2), 1, 2) == "\xFF\xD8" then
        -- JPEG file
        return read_jpeg_size(file)
    else
        file:close()
        return nil, "Unsupported file format"
    end
end

---Скачивает асинхронно файл из URL в указанный путь
---@param url string @URL
---@param path string @Путь к файлу, в который будет сохранен скачанный файл
---@param callback? fun(type: "downloading"|"finished"|"error", pos: number, total_size?: number) @Функция, которая будет вызвана при изменении прогресса скачивания или завершении
---@param progressInterval? number @Интервал в секундах между вызовами callback, по умолчанию 0.1
function downloadToFile(url, path, callback, progressInterval)
  callback = callback or function() end
  progressInterval = progressInterval or 0.1
  local effil = require("effil")
  local progressChannel = effil.channel(0)

  local runner = effil.thread(function(url, path)
    local http = require("socket.http")
    local ltn = require("ltn12")

    local r, c, h = http.request({
      method = "HEAD",
      url = url,
    })

    if c ~= 200 then
      return false, c
    end
    local total_size = h["content-length"]

    local f = io.open(path, "w+b")
    if not f then
      return false, "failed to open file"
    end
    local success, res, status_code = pcall(http.request, {
      method = "GET",
      url = url,
      sink = function(chunk, err)
        local clock = os.clock()
        if chunk and not lastProgress or (clock - lastProgress) >= progressInterval then
          progressChannel:push("downloading", f:seek("end"), total_size)
          lastProgress = os.clock()
        elseif err then
          progressChannel:push("error", err)
        end

        return ltn.sink.file(f)(chunk, err)
      end,
    })

    if not success then
      return false, res
    end

    if not res then
      return false, status_code
    end

    return true, total_size
  end)
  local thread = runner(url, path)

  local function checkStatus()
    local tstatus = thread:status()
    if tstatus == "failed" or tstatus == "completed" then
      local result, value = thread:get()

      if result then
        callback("finished", value)
      else
        callback("error", value)
      end

      return true
    end
  end

  lua_thread.create(function()
    if checkStatus() then
      return
    end

    while thread:status() == "running" do
      if progressChannel:size() > 0 then
        local type, pos, total_size = progressChannel:pop()
        callback(type, pos, total_size)
      end
      wait(0)
    end

    checkStatus()
  end)
end
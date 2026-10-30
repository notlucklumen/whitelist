-- clean system for multiple executions
local function cleanAll()
    if shared.whitelistGarbage then
        for _, obj in shared.whitelistGarbage do
            pcall(function() obj:Disconnect() end)
            pcall(function() obj:Destroy() end)
        end
    end
end
cleanAll()
shared.whitelistGarbage = {}
local function clean(obj)
    table.insert(shared.whitelistGarbage, obj)
    return obj
end

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TextChatService = game:GetService("TextChatService")
local TextService = game:GetService("TextService")
local CoreGui = game:GetService("CoreGui")

local ICON_SIZE = 20
local ICON_Y_OFFSET = 2

local jsonString = game:HttpGet('https://raw.githubusercontent.com/notlucklumen/whitelist/refs/heads/main/whitelist.json')

local data = HttpService:JSONDecode(jsonString)
local whitelist = {}
for _, entry in data.whitelist do
    whitelist[entry.NAME:lower()] = entry.TAG
end

local function getTag(player)
    return whitelist[player.Name:lower()]
end

local function toColor3(c)
    return Color3.fromRGB(c[1], c[2], c[3])
end

local spaceWidth = 4
pcall(function()
    local params = Instance.new("GetTextBoundsParams")
    params.Font = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Medium)
    params.Size = 14
    params.Width = 1000
    params.Text = "a a"
    local withSpace = TextService:GetTextBoundsAsync(params).X
    params.Text = "aa"
    local without = TextService:GetTextBoundsAsync(params).X
    local measured = withSpace - without
    if measured > 0 then
        spaceWidth = measured
    end
end)
local iconSpaces = string.rep(" ", math.ceil((ICON_SIZE + 4) / spaceWidth))

local function addBillboard(player, character)
    local tag = getTag(player)
    if not tag then return end
    local head = character:WaitForChild("Head", 10)
    if not head then return end

    local old = head:FindFirstChild("WhitelistTag")
    if old then old:Destroy() end

    local gui = clean(Instance.new("BillboardGui"))
    gui.Name = "WhitelistTag"
    gui.Size = UDim2.new(800, 0, 4, 0)
    gui.StudsOffset = Vector3.new(0, 2.5, 0)
    gui.AlwaysOnTop = false
    gui.Adornee = head

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 6)
    layout.Parent = gui

    if tag.ICON and tag.ICON ~= "" then
        local icon = Instance.new("ImageLabel")
        icon.LayoutOrder = 1
        icon.Size = UDim2.new(0, 32, 0, 32)
        icon.BackgroundTransparency = 1
        icon.Image = tag.ICON
        icon.ScaleType = Enum.ScaleType.Fit
        icon.Parent = gui
    end

    local label = Instance.new("TextLabel")
    label.LayoutOrder = 2
    label.Size = UDim2.new(0, 0, 0, 25)
    label.AutomaticSize = Enum.AutomaticSize.X
    label.BackgroundTransparency = 1
    label.Text = tag.TEXT
    label.TextColor3 = toColor3(tag.COLOR)
    label.TextStrokeTransparency = 0
    label.TextSize = tag.FONT_SIZE
    label.Font = Enum.Font[tag.FONT]
    label.Parent = gui

    gui.Parent = head
end

local function setupPlayer(player)
    if not getTag(player) then return end
    if player.Character then
        task.spawn(addBillboard, player, player.Character)
    end
    clean(player.CharacterAdded:Connect(function(character)
        addBillboard(player, character)
    end))
end

for _, player in Players:GetPlayers() do
    setupPlayer(player)
end
clean(Players.PlayerAdded:Connect(setupPlayer))

TextChatService.OnIncomingMessage = function(message)
    local props = Instance.new("TextChatMessageProperties")

    local source = message.TextSource
    if source then
        local player = Players:GetPlayerByUserId(source.UserId)
        local tag = player and getTag(player)
        if tag then
            local c = toColor3(tag.COLOR)
            local pad = (tag.ICON and tag.ICON ~= "") and iconSpaces or ""
            props.PrefixText = string.format(
                '<font>%s<font color="#%s">%s</font> %s</font>',
                pad,
                c:ToHex(),
                tag.TEXT,
                message.PrefixText
            )
        end
    end

    return props
end

clean({
    Disconnect = function()
        TextChatService.OnIncomingMessage = nil
    end
})

local function decorateRow(row)
    local userId = tonumber(row.Name:match("^(%d+)%-"))
    if not userId then return end
    local player = Players:GetPlayerByUserId(userId)
    local tag = player and getTag(player)
    if not tag or not tag.ICON or tag.ICON == "" then return end

    local textMessage = row:WaitForChild("TextMessage", 5)
    if not textMessage then return end
    if textMessage:FindFirstChild("WhitelistIcon") then return end

    local icon = clean(Instance.new("ImageLabel"))
    icon.Name = "WhitelistIcon"
    icon.BackgroundTransparency = 1
    icon.Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE)
    icon.Position = UDim2.new(0, 0, 0, ICON_Y_OFFSET)
    icon.Image = tag.ICON
    icon.ScaleType = Enum.ScaleType.Fit
    icon.ZIndex = 10
    icon.Parent = textMessage
end

task.spawn(function()
    local ok, scrollView = pcall(function()
        local node = CoreGui
        for _, name in {
            "ExperienceChat", "appLayout", "chatWindow", "contentFrame",
            "scrollingView", "bottomLockedScrollView", "scrollView"
        } do
            node = node:WaitForChild(name, 15)
            if not node then error("missing " .. name) end
        end
        return node
    end)
    if not ok then return end

    for _, row in scrollView:GetChildren() do
        task.spawn(decorateRow, row)
    end
    clean(scrollView.ChildAdded:Connect(function(row)
        task.spawn(decorateRow, row)
    end))
end)

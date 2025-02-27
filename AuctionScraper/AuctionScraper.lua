local AuctionScraper = LibStub("AceAddon-3.0"):NewAddon("AuctionScraper", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")

AuctionScraper.currentPage = 0
AuctionScraper.totalPages = 0
AuctionScraper.isScanning = false
AuctionScraper.lastProcessedPage = -1
AuctionScraper.lastScanTime = 0
AuctionScraper.processedPages = {}
AuctionScraper_Data = AuctionScraper_Data or { auctions = {}, items = {}, scanInfo = {} }

local suffixes = {
    "of the Monkey", "of the Eagle", "of the Bear", "of the Whale", "of the Owl",
    "of the Gorilla", "of the Falcon", "of the Boar", "of the Wolf", "of the Tiger",
    "of Spirit", "of Stamina", "of Strength", "of Agility", "of Intellect",
    "of Power", "of Spell Power", "of Defense", "of Regeneration", "of Eluding",
    "of Concentration", "of Arcane Protection", "of Fire Protection", "of Frost Protection",
    "of Nature Protection", "of Shadow Protection", "of the Sorcerer", "of the Physician",
    "of the Prophet", "of the Invoker", "of the Bandit", "of the Beast", "of the Hierophant",
    "of the Soldier", "of the Elder", "of the Champion", "of the Test", "of Blocking",
    "of Paladin Testing", "of the Grove", "of the Hunt", "of the Mind", "of the Crusade",
    "of the Vision", "of the Ancestor", "of the Nightmare", "of the Battle", "of the Shadow",
    "of the Sun", "of the Moon", "of the Wild", "of Magic", "of the Knight", "of the Seer",
    "of the Foreseer", "of the Thief", "of the Necromancer", "of the Marksman", "of the Squire",
    "of Restoration", "of Speed"
}

local function CleanItemName(name)
    if not name then return "N/A" end
    local cleanedName = name
    for _, suffix in ipairs(suffixes) do
        cleanedName = cleanedName:gsub(suffix, ""):gsub("%s+", " "):trim()
    end
    return cleanedName ~= "" and cleanedName or "N/A"
end

function AuctionScraper:OnInitialize()
    AuctionScraper_Data.auctions = AuctionScraper_Data.auctions or {}
    AuctionScraper_Data.items = AuctionScraper_Data.items or {}
    AuctionScraper_Data.scanInfo = AuctionScraper_Data.scanInfo or {}
    self:Print("AuctionScraper initialized! Use /scan to start scanning.")
end

function AuctionScraper:StartScan()
    if not AuctionFrame or not AuctionFrame:IsShown() then
        self:Print("Please open the Auction House first!")
        return
    end
    
    self.isScanning = true
    self.currentPage = 0
    self.totalPages = 0
    self.lastProcessedPage = -1
    self.lastScanTime = GetTime()
    
    wipe(AuctionScraper_Data.auctions)
    wipe(self.processedPages)
    
    self:Print("Starting Auction House scan!")
    self:ScheduleTimer("QueryNextPage", 1)
end

function AuctionScraper:StopScan(message)
    if self.isScanning then
        self.isScanning = false
        wipe(self.processedPages)
        self:Print(message)
    end
end

function AuctionScraper:SlashScan()
    if self.isScanning then
        self:Print("Scan already in progress!")
    else
        self:StartScan()
    end
end

function AuctionScraper:QueryNextPage()
    if not self.isScanning or not AuctionFrame:IsShown() then
        return
    end

    local currentTime = GetTime()
    if (currentTime - self.lastScanTime) < 2.5 then
        self:ScheduleTimer("QueryNextPage", 2.5 - (currentTime - self.lastScanTime))
        return
    end

    self.lastScanTime = currentTime
    self.currentPage = self.currentPage + 1
    QueryAuctionItems("", nil, nil, 0, 0, 0, self.currentPage - 1, false, false)
    self.lastRequestedPage = self.currentPage
    self:ScheduleTimer("CheckPageData", 1.5)
end

function AuctionScraper:CheckPageData()
    if not CanSendAuctionQuery() then
        self:Print("Auction data not ready, retrying...")
        self:ScheduleTimer("CheckPageData", 2)
        return
    end

    local numBatchAuctions, totalAuctions = GetNumAuctionItems("list")
    self.totalPages = math.ceil(totalAuctions / 50)

    if self.lastRequestedPage and self.currentPage ~= self.lastRequestedPage then
        self:Print("Page data mismatch, retrying...")
        self:ScheduleTimer("CheckPageData", 1.5)
        return
    end

    self:ProcessAuctionData()
end

function AuctionScraper:ProcessAuctionData()
    if not self.isScanning or not AuctionFrame:IsShown() then
        return
    end

    local numBatchAuctions, totalAuctions = GetNumAuctionItems("list")
    if totalAuctions == 0 then
        self:Print("No auctions found!")
        self.isScanning = false
        return
    end

    self.totalPages = math.ceil(totalAuctions / 50)

    if self.currentPage == self.lastProcessedPage then
        return
    end

    self.lastProcessedPage = self.currentPage
    self:Print(("Scanning Page: %d/%d"):format(self.currentPage, self.totalPages))
    self.processedPages[self.currentPage] = true

    for i = 1, numBatchAuctions do
        local name, texture, count, _, _, _, _, _, buyout = GetAuctionItemInfo("list", i)
        local link = GetAuctionItemLink("list", i)
        local id = link and tonumber(link:match("item:(%d+)")) or "N/A"
        local cleanName = CleanItemName(name)

        local itemExists = false
        for _, item in ipairs(AuctionScraper_Data.items) do
            if item.entry == id then
                itemExists = true
                break
            end
        end

        if id ~= "N/A" and not itemExists then
            local cleanTexture = texture and texture:gsub("Interface\\Icons\\", "") or "N/A"
            table.insert(AuctionScraper_Data.items, {
                entry = id,
                name = cleanName,
                icon = cleanTexture
            })
        end

        table.insert(AuctionScraper_Data.auctions, {
            entry = id,
            quantity = count or 0,
            price = buyout or 0
        })
    end

    if self.currentPage < self.totalPages then
        self:ScheduleTimer("QueryNextPage", 2.5)
    elseif self.currentPage == self.totalPages then
        self:ScheduleTimer("FinalPageCheck", 2)
    end
end

function AuctionScraper:FinalPageCheck()
    local numBatchAuctions, totalAuctions = GetNumAuctionItems("list")
    if numBatchAuctions > 0 then
        self:ProcessAuctionData()
    end
    AuctionScraper_Data.scanInfo = {
        ["timestamp"] = time(),
        ["count"] = #AuctionScraper_Data.auctions
    }
    self:Print(("Auction House scan complete! Found %d auctions!"):format(
        AuctionScraper_Data.scanInfo["count"]))
    self.isScanning = false
    wipe(self.processedPages)
end

function AuctionScraper:AUCTION_ITEM_LIST_UPDATE()
    if self.isScanning and AuctionFrame:IsShown() then
        local currentTime = GetTime()
        if not self.lastUpdate or (currentTime - self.lastUpdate) > 1 then
            self.lastUpdate = currentTime
            self:ScheduleTimer("CheckPageData", 0.5)
        end
    end
end

function AuctionScraper:AUCTION_HOUSE_CLOSED()
    if self.isScanning then
        self:StopScan("Auction House closed - scan stopped!")
    end
end

AuctionScraper:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
AuctionScraper:RegisterEvent("AUCTION_HOUSE_CLOSED")
AuctionScraper:RegisterChatCommand("scan", "SlashScan")
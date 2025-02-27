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
    if not AuctionScraper_Data.auctions then
        AuctionScraper_Data.auctions = {}
    end
    if not AuctionScraper_Data.items then
        AuctionScraper_Data.items = {}
    end
    if not AuctionScraper_Data.scanInfo then
        AuctionScraper_Data.scanInfo = {}
    end
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
    self:QueryNextPage()
end

function AuctionScraper:StopScan(message)
    self.isScanning = false
    wipe(self.processedPages)
    self:Print(message)
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
        if self.isScanning then
            self:StopScan("Auction House closed - scan stopped!")
        end
        return
    end
    
    local currentTime = GetTime()
    if (currentTime - self.lastScanTime) < 1 then
        self:ScheduleTimer("QueryNextPage", 1 - (currentTime - self.lastScanTime))
        return
    end
    
    self.lastScanTime = currentTime
    QueryAuctionItems("", 0, 0, 0, 0, 0, self.currentPage, 0, 0)
end

function AuctionScraper:ProcessAuctionData()
    if not self.isScanning or not AuctionFrame:IsShown() then
        if self.isScanning then
            self:StopScan("Auction House closed - scan stopped!")
        end
        return
    end
    
    if self.currentPage == self.lastProcessedPage then
        return
    end
    
    self.lastProcessedPage = self.currentPage
    local numBatchAuctions, totalAuctions = GetNumAuctionItems("list")
    
    if totalAuctions == 0 then
        self:Print("No auctions found!")
        self.isScanning = false
        return
    end
    
    self.totalPages = math.ceil(totalAuctions / 50)
    
    if not self.processedPages[self.currentPage] then
        self:Print(("Scanning Page: %d/%d"):format(self.currentPage + 1, self.totalPages))
        self.processedPages[self.currentPage] = true
    end
    
    local pageItems = 0
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
        
        pageItems = pageItems + (count or 0)
    end
    
    if self.currentPage < self.totalPages then
        self.currentPage = self.currentPage + 1
        self:ScheduleTimer("QueryNextPage", 1)
    else
        AuctionScraper_Data.scanInfo = {
            ["timestamp"] = time(),
            ["count"] = 0
        }
        for _, auction in ipairs(AuctionScraper_Data.auctions) do
            AuctionScraper_Data.scanInfo["count"] = AuctionScraper_Data.scanInfo["count"] + auction.quantity
        end
        
        self:Print(("Auction House scan complete! Found %d auctions with %d total items"):format(
            #AuctionScraper_Data.auctions, AuctionScraper_Data.scanInfo["count"]))
        self.isScanning = false
        wipe(self.processedPages)
    end
end

function AuctionScraper:AUCTION_ITEM_LIST_UPDATE()
    if self.isScanning and AuctionFrame:IsShown() then
        local currentTime = GetTime()
        if not self.lastUpdate or (currentTime - self.lastUpdate) > 0.5 then
            self.lastUpdate = currentTime
            self:ScheduleTimer("ProcessAuctionData", 0.1)
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
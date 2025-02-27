# AuctionScraper

An addon for the 3.3.5 game client designed to scrape data from the auction house.

## Installation and Usage

1. **Install AuctionScraper**  
   Download and extract the addon, then place it in your `AddOns` folder.

2. **Run the Scan**  
   Open the auction house in-game and enter the following command: `/scan`
   
3. **Complete the Scan**  
Once the scan is complete, either:  
- Type `/reload` in the chat, or  
- Exit the game entirely.

4. **Locate the Data**  
Find the saved data in: `Client\WTF\Account\NAME\SavedVariables`

The results will be stored in the file `AuctionScraper.lua`.

## Data Output

The `AuctionScraper.lua` file includes the following information:

- **Unique Items**  
  - Item ID  
  - Item Name  
  - Item Icon  

- **Auction Details**  
  - Item ID  
  - Quantity being sold  
  - Buyout price  

- **Scan Metadata**  
  - Time the scan was completed  
  - Total number of auctions found  

## Notes
- Ensure the addon is properly installed in the `AddOns` directory before launching the game.
- The scan requires an active auction house window to function.
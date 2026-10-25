# Privacy Policy 

This bot collects basic data for analytics.

Private messages to the bot will not be logged or read by the bot.

## Logged Data
- **Timestamp** of the command usage  
- **Username** and **User ID** of the person using the bot or if bot is used in the play ground then a hash of the IP address is logged (the actual IP address is not logged anywhere).
- **Command invoked**  
- **Message length** (number of characters)  
- **Errors**, for example a GitHub link that failed to import.

## Data Not Collected
- The content of your messages is **never stored** or made public, except what is listed under Stored Data.  
- No personal or sensitive information beyond username and user ID is logged.  

## Stored Data
- **Code you run with `/compile`** is kept for 24 hours for the **see raw** link. Anyone with the link can view it.
- **DataStores and MemoryStores** your code saves in Discord are kept on the bot's server under your User ID, up to 1 MB. Data that isn't used for 30 days is deleted, and MemoryStore entries are deleted when they expire.
- Code run in the play ground doesn't save DataStores or MemoryStores.
- To delete your saved data, remove it with `RemoveAsync`, or wait 30 days.

## Purpose
- The data is used only to monitor bot usage, optimize performance, and troubleshoot issues.  
- Raw data is **kept private** and is **not shared publicly**.  

## Third Parties
- Your code runs on Roblox, either on the bot's server or on Roblox's servers.
- `ask` sends your prompt to Roblox using TextGenerator.
- `io.import` downloads from GitHub or wally.run.

## Example of Logged Data

| Timestamp        | User         | User ID             | Command  | Data                       |
|-----------------|-------------|--------------------|----------|---------------------------|
| 9/2/2025 11:57  | haotian2006 | 435997176477253682 | bytecode | Code length: 15,389 characters |

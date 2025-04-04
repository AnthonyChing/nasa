-- Debian default Lua configuration file for PowerDNS Recursor

-- Load DNSSEC root keys from dns-root-data package.
-- Note: If you provide your own Lua configuration file, consider
-- running rootkeys.lua too.
dofile("/usr/share/pdns-recursor/lua-config/rootkeys.lua")
addTA('cscat.tw', "8052 13 2 02c0a42f3ffb56019ab0dcadff75146a0140965e5c9b329375b00fbf96abc34a")

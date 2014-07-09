local socket = require("socket")

if not task then dofile("task.lua") end
local task = task

local SERVERS = {
  "114.114.114.114", "223.5.5.5",
  "106.186.17.181:2053", "128.199.248.105:54",
  "208.67.222.123:443"
}

local FAKE_IP = {
  "74.125.127.102", "74.125.155.102", "74.125.39.102", "243.185.187.3", "243.185.187.39",
  "74.125.39.113", "209.85.229.138", "4.36.66.178", "8.7.198.45", "37.61.54.158",
  "46.82.174.68", "59.24.3.173", "64.33.88.161", "64.33.99.47", "64.66.163.251",
  "65.104.202.252", "65.160.219.113", "66.45.252.237", "72.14.205.104", "72.14.205.99",
  "78.16.49.15", "93.46.8.89", "128.121.126.139", "159.106.121.75", "169.132.13.103",
  "192.67.198.6", "202.106.1.2", "202.181.7.85", "203.161.230.171", "203.98.7.65",
  "207.12.88.98", "208.56.31.43", "209.145.54.50", "209.220.30.174", "209.36.73.33",
  "209.85.229.138", "211.94.66.147", "213.169.251.35", "216.221.188.182", "216.234.179.13"
}

local IP, PORT = {}, {}
local busy, busy_count = false, 0

local function listener(proxy, forwarder)
  while true do
    local data, ip, port = proxy:receivefrom()
    if data and #data > 0 then
      local domain = (data:sub(14, -6):gsub("[^%w]", "."))
      io.write(domain.."\n")
      local ID = data:sub(1, 2)
      IP[ID], PORT[ID] = ip, port
      for _, server in ipairs(SERVERS) do
        local dns_ip, dns_port = string.match(server, "([^:]*):?(.*)")
        dns_port = tonumber(dns_port) or 53
        forwarder:sendto(data, dns_ip, dns_port)
      end
      busy, busy_count = true, 10
    else
      if busy then
        busy_count = busy_count - 1
        if busy_count == 0 then busy = false end
      end
    end
    task.sleep(busy and 0.02 or 0.1)
  end
end

local function replier(proxy, forwarder)
  while true do
    local data = forwarder:receive()
    if data and #data > 0 then
      local ID = data:sub(1, 2)
      if IP[ID] and not FAKE_IP[data:sub(-4)] then
        proxy:sendto(data, IP[ID], PORT[ID])
        IP[ID], PORT[ID] = nil, nil
      end
    end
    task.sleep(busy and 0.01 or 0.1)
  end
end

local function main()
  local proxy = socket.udp()
  proxy:settimeout(0)
  assert(proxy:setsockname("*", 53))

  local forwarder = socket.udp()
  forwarder:settimeout(0)
  assert(forwarder:setsockname("*", 0))

  for _, ip in ipairs(FAKE_IP) do
    FAKE_IP[ip:gsub("%d+", string.char):gsub("(.).", "%1")] = true
  end

  task.go(listener, proxy, forwarder)
  task.go(replier, proxy, forwarder)
  task.loop()
end

main()

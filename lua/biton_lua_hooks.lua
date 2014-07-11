--------------------------------------------------------------------------------------------------------
-- biton_lua_hooks.lua
-- Author: P.Colclough
-- Date  : 18 June 2012
-- Homepage: https://www.linkedin.com/in/petercolclough
--           https://github.com/bitonp/mysql-lua-logging
-- License: MIT
-- Description: First attempt at LUA for Proxy. To trap sql, and pass to RabbitMQ/FIFO Buffer for further recording
-- Treat me nicely
--  27/6/2014 - Amended to write via Curl, to Elasticsearch... so Kibana (Graph) can read from it
--
--  =========================== Lua APR Used with kind permission of Pete Rodding ================================
--  Author: Peter Odding <peter@peterodding.com>
--  Last Change: December 7, 2011
--  Homepage: http://peterodding.com/code/lua/apr/
--  License: MIT
--  ==============================================================================================================
-- Notes: 
-- 1. package.* holds the loaders. So the paths are put in:
--           package.path       - lua files
--           packahge.cpath     - c files
--
-- 2. Cursors = table of stmts{}
-- 3. stmts   = table of statements{id="x", timestart="timestamp", timeend="timestamp", exectime="timestamp", sql="sql"} 
-- 4. Modifying Repsponse
--    resp = {
--			type = proxy.MYSQLD_PACKET_OK,
--			resultset = {
--				fields = {
--					{ name = "statisitics" }, {name = 'End of teh World'}
--				},
--				rows = {
--					{ "Hello World" ,'Goodbye Forever'}
--				}
--			}
--		}
--    proxy.response = resp;   
--    return proxy.PROXY_SEND_RESULT;
--------------------------------------------------------------------------------------------------------

-- global changes
-- config options
gDebug = true;
nMaxQryLen = 500;
sfifo      = "/var/log/mysql/proxy.out";


--- Swap these around for remote
local blocal = true

-- include files

------------------------------------------------------------------------
-- Different setups for local and remote
-- These will probably change according to your setup
------------------------------------------------------------------------
if(blocal == true) then 
	package.path = "./?.lua;./?.lc;/usr/local/?/init.lua;/usr/local/share/lua/5.1/?.lua;/usr/share/nmap/?.lua;/usr/lib/mysql-proxy/lua/?.lua;/home/bitonp/mysql-proxy/mysql-proxy-0.8.4-linux-glibc2.3-x86-64bit/lib/mysql-proxy/lua/proxy/?.lua";
	package.cpath = "/home/bitonp/mysql-proxy/mysql-proxy-0.8.4-linux-glibc2.3-x86-64bit/lib/apr.so;./?.so;./?.dll;/usr/local/?/init.so;/usr/local/lib/lua/5.1/?.so;/usr/lib/lua/5.1/socket/?.so;./?.lua;/home/bitonp/mysql-proxy/mysql-proxy-0.8.4-linux-glibc2.3-x86-64bit/lib/mysql-proxy/lua/proxy/?.lua";
else
	package.path = "./?.lua;/usr/local/share/lua/5.1/?.lua;/usr/local/share/lua/5.1/?/init.lua;/usr/local/lib/lua/5.1/?.lua;/usr/local/lib/lua/5.1/?/init.lua;/usr/share/lua/5.1/?.lua;/usr/share/lua/5.1/?/init.lua;/usr/share/mysql-proxy/?.lua";
	package.cpath = "./?.so;/usr/local/lib/lua/5.1/?.so;/usr/lib/x86_64-linux-gnu/lua/5.1/?.so;/usr/lib/lua/5.1/?.so;/usr/local/lib/lua/5.1/loadall.so";
end

-- local requires
local biton      = require("bitonstructs");
local apr        = require("apr");
-- objects
-- Tables

-- global variables
hfifo      = nil;
sCurl      = "curl -XPOST 'http://awse-sl01:9200/mysql/query_data/' -d '%s'"
-- variables
local access_ndx = 0;
local current_id = 1;
local cursors    = {};
local stmts      = {};

local secdiv     = 1000000;
------------------------------------------------------
-- Connects using the Proxy connection Table
-- See: http://dev.mysql.com/doc/refman/5.1/en/mysql-proxy-scripting-structures.html#mysql-proxy-scripting-structures-connection
-- Notes: No data to use at this point... goto read_handshake()
------------------------------------------------------
function connect_server()
    if(hfifo == nil) then
       hfifo = io.open(sfifo, "w");
    end
end

------------------------------------------------------
-- Reads the server data after connection
-- See: http://dev.mysql.com/doc/refman/5.1/en/mysql-proxy-scripting-structures.html#mysql-proxy-scripting-structures-connection
------------------------------------------------------
function read_handshake( )
   local sFunc = 'read_handshake()';
end

------------------------------------------------------
-- Reads the server data after read_handshake
-- See: http://dev.mysql.com/doc/refman/5.1/en/mysql-proxy-scripting-structures.html#mysql-proxy-scripting-structures-connection
------------------------------------------------------

function read_auth( )
  local sFunc = 'read_auth()';
  local oConnection = proxy.connection;
  local oConn;
  local nThread     = oConnection.server.thread_id;
   -- Fill the local table
   table.insert(bitonConn,{user  = oConnection.client.username, 
                         clndb = oConnection.client.default_db,
                         proxyname = oConnection.client.dst.name, 
                         clnname = oConnection.client.src.name, 
                         srvversion = oConnection.server.mysqld_version,
                         srvthread = nThread,
                         srvname = oConnection.server.dst.name});
   nElem = table.getn(bitonConn);								-- returns last inserted   
   
   oConn = bitonConn[nElem];									-- Do what we want with it here
   return;
end

------------------------------------------------------
-- Called after the authentication has taken place
-- See: http://dev.mysql.com/doc/refman/5.1/en/mysql-proxy-scripting-structures.html#mysql-proxy-scripting-structures-connection
------------------------------------------------------
function read_auth_result()

end

function disconnect_client()
  local sFunc = "disconnect_client()";
  local oConnection = proxy.connection;
  local oConn = findConnection(oConnection.server.thread_id);
  
  if (oConn ~= false) then
		killConnection(oConn.srvthread);
  end
end

------------------------------------------------------
-- Called as the request is received
-- See: http://dev.mysql.com/doc/refman/5.1/en/mysql-proxy-scripting-structures.html#mysql-proxy-scripting-structures-connection
--
-- The packet contains the query. If we need to send this to the server we need to add it to the
-- proxy.queues. If we dont, it will still be sent to the server, but we won;t get the query results/times etc etc back.
--
-- packet::sub(1)       -> Query Type
-- packet::sub(2)       -> Query itself 
------------------------------------------------------
function read_query (packet)
   local nqCount = table.getn(bitonQuery);
   local bresultset = false;
   -- Set the counter to one more
   nqCount = nqCount + 1;
   table.insert(bitonQuery, {
				          id          = nqCount,	
						  threadid    = proxy.connection.server.thread_id ,
				          querytype   = packet:sub(1),
				          query       = packet:sub(2),
				          timesent    = microtime(),
				          timereceived = nil,
				          querytime   = nil,
				          responsetime = nil
				     });
   -- Send the query
   proxy.queries:append(nqCount, packet, { resultset_is_needed = bresultset });
   return proxy.PROXY_SEND_QUERY;
  
end

------------------------------------------------------
-- Called after query has taken place
-- See: http://dev.mysql.com/doc/refman/5.1/en/mysql-proxy-scripting-structures.html#mysql-proxy-scripting-structures-connection
------------------------------------------------------
function read_query_result (res)

  -- Get the relevant query from the query pool.
  local oQuery = findQuery(res.id);
  local oConn = nil;
  local buffer = nil;
  
  if(oQuery ~= nil) then
	oQuery.timereceived = microtime();
	oQuery.querytime = res.query_time/secdiv;
	oQuery.responsetime = res.response_time/secdiv;
	oQuery.lockouttime = (oQuery.timereceived - oQuery.timesent - oQuery.responsetime);
	oConn = findConnection(oQuery.threadid);
	
	if(oConn ~= nil) then sendQuery(oConn,oQuery); end --- when written
    
    killQuery(oQuery.id);
  end
  return ;
end


---------------------------------------------------------
-- Additional functions
---------------------------------------------------------
function print_access(msg)
    access_ndx = access_ndx + 1
    --print( string.format('%3d %-30s',access_ndx,msg))
end

function formatPacket( npQueryType, spSql)
    retPacket = string.char(npQueryType) .. spSql;
    return retPacket;
end

function getDate()
   local ntime = os.date('%Y-%m-%d %H:%M:%S')
   return ntime
end
----------------------------
-- Base time for ES
-- YYYY-MM-DDTHH:MM:SS.nnnZ
----------------------------
function getBaseTime()
        local nsec, nms = math.modf(microtime());
        nms = string.sub(tostring(nms)..'000',3,5)              -- make sure we have 3 digits
        local ttime = os.date("*t");
        local stime = string.format("%04d-%02d-%02dT%02d:%02d:%02d.%sZ",ttime.year, ttime.month, ttime.day,ttime.hour, ttime.min,ttime.sec,nms);
        return stime;
end

function getTimestamp()
   local ntime = apr.time_now();
   return ntime;
end

function microtime()
   local ntime = apr.time_now();
   return ntime;
end

function addtable(spElem, spTable)
   if(spTable == nil) then
		nElem = 0;
   else
		nElem = table.getn(spTable);
   end
   nElem = nElem+1;
   table.setn(spTable, nElem);
   table.insert(spTable, nElem, spElem);
   return nElem;
end

--------------------------------------------------------
-- Dump information from this statement structure
-- local stmt = {
--     id = current_id,
--     query_type = packet:byte(),
--     timestart = getTimestamp(),
--     timeend   = 0,
--     sql       = packet:sub(2),
--     query_time = 0,
--     response_time = 0,
--     roundTrip = 0,
--     connection = proxy.connection
--  } 
 
--  resp = {
--			type = proxy.MYSQLD_PACKET_OK,
--			resultset = {
--				fields = {
--					{ name = "Round Trip" }, {name = 'Query Time'}, {name = 'Response Time'}
--				},
--				rows = {
--					{ roundTrip ,stmt.query_time, string.format("%f",stmt.response_time)}
--				}
--			}
--		}
  --  proxy.response = resp;   
   
--------------------------------------------------------

-----------------------------------------------------------
-- Show servers Information
-----------------------------------------------------------
function showServers()
  local servers = proxy.global.backends;
  local strRes = '';
  local numservers = #servers;
  local ncount = 1;
  
  
  while (ncount < numservers) or (ncount == numservers) do
      svr = servers[ncount];
      
      strRes = string.format("Name:%s \nIP: %s\nPort: %s\nClients: %d\nState: %d\nType: %d\n----------\n", svr.dst.name, svr.dst.address, svr.dst.port, svr.connected_clients, svr.state, svr.type );
      ncount = ncount + 1;
  end
  return;
end

-----------------------------------------------------------
-- dump servers
-----------------------------------------------------------
function dumpServers(spserver)
  local servers = proxy.global.backends;
  local strRes = '';
  local numservers = #servers;
  local ncount = 1;
  

  while (ncount <= numservers) do
     svr = servers[ncount]; 
     if string.find(svr.dst.name, spserver,1) then
        proxy.global.backends[ncount].state = BACKEND_STATE_DOWN;
        break;
     end
     ncount = ncount + 1;
  end

  showServers();
  return;

end

-----------------------------------------------------------
-- sendQuery
-- os.execute('curl ...')
-- Set up for ElasticSearch.. change for your output of choice
-----------------------------------------------------------
function sendQuery(opConn, opQuery)
   local currIndex = proxy.connection.backend_ndx;
   local numQuery   = countQueries();
   local sttl = "1d"
   local sQuery     = string.gsub(opQuery.query,"\n", " ");
   local stime = getDate();
   local sCmd = '';

   nlen = string.len(sQuery);
   if(nlen > nMaxQryLen) then
          sQuery = string.sub(sQuery, 1,nMaxQryLen)..'...'..string.sub(sQuery, nlen - 10, nlen);
   end

   sQuery           = string.gsub(sQuery,'\\', '\\\\');
   -- sQuery           = string.gsub(sQuery,"'", "''");
   sQuery           = string.gsub(sQuery,'"', '\\"');
   local buffer = string.format('"Server":"%s","User":"%s", "proxyName":"%s","server_version":"%s","Client":"%s","Thread":"%s","QueryLen":%s,"Query":"%s","QueryType":%s,"timeSent":"%f","timeReceived":"%f","queryTime":"%f","responseTime":"%f","lockoutTime":"%f"',
                                opConn.srvname,
                                opConn.user,
                                opConn.proxyname,
                                opConn.srvversion,
                                opConn.clnname,
                                opConn.srvthread,
                                nlen,
                                sQuery,
                                (string.byte(opQuery.querytype)),
                                opQuery.timesent,
                                opQuery.timereceived,
                                opQuery.querytime,
                                opQuery.responsetime,
                                opQuery.lockouttime);
   
    -- Now get backends
    local serverBuff = string.format("\"client_connections\":\"%d\"",
                                      proxy.global.backends[currIndex].connected_clients);
    -- local connBuff  = string.format('"queries":{"current":"%d"}',numQuery);
    local connBuff  = string.format('"current":"%d"',numQuery);
    local writebuff = string.format('{"@timestamp":"%s",%s,%s, %s}\n', getBaseTime(),serverBuff, buffer, connBuff);
    if(gDebug == true) then
        hfifo:write(writebuff);
        hfifo:flush();
    end
    -- Now the Curl Call
    -- Need to add:
    -- 1. _id ??
    -- 2. _ttl - Set to 24 Hours initially
    --------------------------------------- 
    sdate = getDate()
    sCmd = string.format(sCurl,writebuff);
    if(gDebug == true) then
                hfifo:write(sCmd);
                hfifo:flush();
        end
        os.execute(sCurl);
    return;
end


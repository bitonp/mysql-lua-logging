--------------------------------------------------------------------------------------------------------
-- bitonstructs.lua
-- Author: P.Colclough
-- Date  : 21 Feb 2013
-- Description: A place for any tables/structures to be defined 
-- All these are global, unless marked 'local var'
--
-- bitonConn 				- A Table of Connection Details.
--       {	user  = oConnection.client.username, 
--          clndb = oConnection.client.default_db,
--          proxyname = oConnection.client.src.name, 
--          clnname = oConnection.client.src.name, 
--          srvversion = oConnection.server.mysqld_version,
--          srvthread = nThread,
--          srvname = oConnection.server.dst.name}
--
-- bitonQuery             - A table of queries
--     {
--          id          = nextid,	
-- 			threadid    = thread ,
--          querytype   = packet::sub(1),
--          query       = packet::sub(2),
--          timesent    = microtime(),
--          timereceived = microtime(),
--          querytime   = response_query_time,
--          responsetime = response_response_time,
--          lockouttime  = (timereceived - timesent - responsetime)
--     }
--
--
--
--
--
--
--
--
--
-- functions               findConnection - Find a Connection based on thread id
--                         killConnection - Set a connection to nil
--
-- Global Tables           bitonCurl      - Table of Curl Commands to run. 
--------------------------------------------------------------------------------------------------------

-- global vars
bitonConn    = {};
bitonQuery   = {};
bitonCurl    = {};
-- local vars
-- methods/functions... call it what you will
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
--------------------------------------------------------------------------------------------------------
-- findConnection 
-- Description: Find connection by threadid
-- Return a bitonConn connection or nil
--------------------------------------------------------------------------------------------------------
function findConnection(npThread)
     local nC = 1;
     oConn    = nil;                                -- Default value
     while (nC <= table.getn(bitonConn)) do
        if (bitonConn[nC].srvthread == npThread) then
			oConn = bitonConn[nC];
			break;
		end
		nC = nC + 1;
     end 
     return oConn;
end
 
--------------------------------------------------------------------------------------------------------
-- killConnection 
-- Description: Kill a Connection.. set to nil
-- Return 
--------------------------------------------------------------------------------------------------------
function killConnection(npThread)
     local nC = 1;
     oConn    = nil;                                -- Default value
     killAllQueries(npThread);
     while (nC <= table.getn(bitonConn)) do
        if (bitonConn[nC].srvthread == npThread) then
			table.remove(bitonConn, nC);
			break;
		end
		nC = nC + 1;
     end 
     return;
end

--------------------------------------------------------------------------------------------------------
-- findQuery 
-- Description: Find a Query array from the ID
-- Return a bitonQuery table element or nil
--------------------------------------------------------------------------------------------------------
function findQuery(npID)
     local nC = 1;
     oQuery    = nil;                                -- Default value
     while (nC <= table.getn(bitonQuery)) do
        if (bitonQuery[nC].id == npID) then
			oQuery = bitonQuery[nC];
			break;
		end
		nC = nC + 1;
     end 
     return oQuery;
end

--------------------------------------------------------------------------------------------------------
-- killQuery 
-- Description: Kill a Query Data from the table
-- Return 
--------------------------------------------------------------------------------------------------------
function killQuery(npID)
     local nC = 1;
     while (nC <= table.getn(bitonQuery)) do
        if (bitonQuery[nC].id == npID) then
			table.remove(bitonQuery, nC);
			break;
		end
		nC = nC + 1;
     end 
     return;
end

--------------------------------------------------------------------------------------------------------
-- killAllQueries 
-- Description: Kill All queries for the given thread
-- Return 
--------------------------------------------------------------------------------------------------------
function killAllQueries(npThreadID)
     local nC = 1;
     while (nC <= table.getn(bitonQuery)) do
        if (bitonQuery[nC].threadid == npThreadID) then
			table.remove(bitonQuery, nC);
			if (nC > 1) then
			   nC = nC - 1;
			end
		end
		nC = nC + 1;
     end 
     return;
end

--------------------------------------------------------------------------------------------------------
-- countQueries 
-- Description: A count of active queries in teh queue ... proxy.queries:len() fails
-- Return Number of queries in table
--------------------------------------------------------------------------------------------------------
function countQueries()
     local nC = 0;
     while (nC < table.getn(bitonQuery)) do
        nC = nC + 1;
     end 
     return nC;
end


mysql-lua-logging
=================

Logging Scripts and methods for MySql using mysql-proxy and custom Lua scripts. Issued under MIT License by
Peter Colclough (biton@compuserve.com). Please read the License information in this repo for more information.

* With thanks to Pete Rodding (http://peterodding.com/code/lua/apr) for his contribution and help with hos Lua-Apr 
(Apache Portable Runtime) binding for Lua, without which microsend timing would not be possible *

Introduction
============
This extension to mysql-proxy allows all teh timming information to be taken from your server, and passed to the 
output of your choice. This particular version makes a Curl call to an ElasticSearch Engine, which is then read
by Kibana for graphs, tables and all things interesting. A blog on this will follow...

The simple (ha!) concept behind ths was finding a way to log all queries that happen on a server, or group of servers, 
to discover usage, issues, and all queries that need optimisation. It grew out of a need of spending a couple of years
optimising queries for a client, and discovering that it wa the 'things we cant see' causing an issue. The Higgs Bosun
of databases.
However, we also had the issue that any recording _must not_ interfere with current database operation. Thats a tall order.

By using mysql-proxy with these two lua scripts, we are able to pipe the query information, via curl(), to a completely
seperate cluster of machines running ElasticSearch. This very small increment in time is negated completely by the removal 
of the need to log slow-logs, and garner them, on the database server. Your logs then also end up in a search engine,
which makes for a much better way of finding queries/tables/columns, than grepping through reams of logs that may not 
hold the data you want.

Have fun.. and please feed back where necessary.


Installation is relatively straight forward, if you follow the examples here.  

OS
==
Built and tested on Ubuntu / Debian Linux (10 ... 13). Should also work on windows (if you must) , but you are sort of
on your own. I will help out where I can... but I am a Unix guys now. 

Required Software (All server side)
=================
1. mysql-proxy           http://dev.mysql.com/downloads/mysql-proxy/
2. Lua (5.1 or above)    http://www.lua.org/download.html
                         - Debian: sudo apt-get install lua5.1
3. liblua5.1             http://peterodding.com/code/lua/apr
                         - Debian: sudo apt-get install liblua5.1-apr1
4. APR (Apache Portable Runtime) https://apr.apache.org/download.cgi

All the above are open source.

Install Directories (suggested)
1. lua files -> /usr/share/mysql-proxy
2. bitonproxy.conf -> /etc/mysql-proxy
3. If using ES, then you will need the mappings.sh script. This is simply a curl() call to be made on against your
   ES server, dictating the types of the data produced, for easy searching... and making sense of by Kibana or 
   graphing packages.
   
Configuration
=============
1. If you have any major issues, it will be in mysql-proxy not picking up your library installation. To get around this,
   once libua5.1 is installed, from the command line run the following:\n
      sh> /usr/bin/lua5.1 -e 'apr = require "apr"; print(apr.time_now()); env=getfenv(); print(env);for i,v in pairs(env.package) do print(i,v); end'
   This should prit out the current time in microtime, plus the path settings used to get them. If you have the microtime printed out, 
   then cut and paste the output into 'package.path' and 'package.cpath' around line 57-60 of biton_lua_hooks.lua.
   If you dont have the microtime, and youo have an error, there is an issue outside of bitonproxy, and to do with 
   your lua installation.
   
 Assuming all that is working ....  (well done)
 
 2. bitonproxy.conf (The default configuration file loaded by mysql-proxy)
    [mysql-proxy]
    admin-address=[my_proxy_server]:4041
    proxy-address=[my_proxy_server]:4040
    proxy-backend-addresses=[my_real_databases:3306],[],[]    <- A list of backends
    proxy-lua-script=/[my_lua_scripts]/biton_lua_hooks.lua    <- /usr/share/mysql-proxy ... suggested
    log-file=/var/log/bitonproxy.log
    keepalive=true
       
 3. You may want to jig with the code in biton_lua_hooks.lua, in the following ways:
    a)  Line 40ish:
        gDebug=true        true, output happens, false it doesn't.
        sfifo=fn.out       if gdebug = true, this is the full path and filename for debg output of the curl call.
        nMaxQryLen=500     Any query over this length will be have the first 500 characters + '...' + the last 30 odd characters
                           recorded. I found a client with 30k+ queries... thats not fun :-).
        local blocal=true  I have 2 configuration options for testing local and remote. This allows for easy swapping 
                           between the two.
    c) sCurl      = "curl -XPOST 'http://[ES-SERVER]:9200/mysql/query_data/' -d '%s'"
                           This is the template curl call to ES. If you aren't writing to ES yoou can ignore this. If youo are 
                           writing to something like RabbitMQ, then you can change this. If you are simply writing to 
                           a log file, you can ignore this, and change the sendQuery() function to perform an io.write() 
                           call instead. 
                           This code is straightforward to a 'C' or competet PHP/Pythin/Perl programmer... if yoou are 
                           not one of these give me a shout... I can help.
   
 4. Install mysql-proxy (either use 'screen' or daemonise in your own way. Success/Failure to write is output here, so you may want to
                         pipe to a log file if daemonising)
      sh>mysql-proxy --defaults-file=/etc/mysql-proxy/bitonproxy.conf
      
 5. If using ElasticSearch, you will need to ensure a 'mysql' (or whatever index you are going to use does not exist), then
    run the elasticsearch_mappings.sh file to set the mappings.
    
    If you aren't ... move on to (6).
  
 6. Make sure that your user has the correct Database rights to connect from your proxy server. If your proxy server is:
            100.2.3.4 and user = 'mydbuser'
    then the users will be 'mydbuser'@'100.2.3.4' 
               
 7. Connect to mysql-proxy using:
         mysql -hmy_proxy_server -udbusername -p -P4040 -A
     The dbusernaame is the username for your backend database that mysql-proxy will connect to,as is the password that you will
     be prompted for.
     
     If connecting through one pf the many client libraries the server will be:
            my_proxy_server:4040         NOT
            my_db_server:3306            that you usually use.
            
  That should be it. If it isn't, please let me know.... if it is and it us working for you... please let me know... 
  if you are having issues.. please let me know (attention seeker that I am).. happy logging.
                     
  
                                                    

         

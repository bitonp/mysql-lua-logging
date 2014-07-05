curl -XPOST http://[MY_ES_SERVER]:9200/mysql/ -d '{
    "settings" : {
        "number_of_shards" : 5,
        "number_of_replicas" : 1,
        "index.analysis.analyzer.default.type": "standard", 
        "index.refresh_interval": "5s"
    },
    "mappings" : {
 	"_default_":{
            "_ttl" : {"enabled":true, "default":"2d"},
	    "@timestamp" : {"type" : "date"} 
         },
        "mysql" : {
	    "properties" : {
 	        "Server":{"type":"string"},
                "client_connections":{"type":"long"},
                "User":{"type":"string"},
                "proxyName":{"type":"string"},
                "server_version":{"type":"string"},
                "Client":{"type":"string"},
                "Thread":{"type":"string"},
	        "QueryLen":{"type":"long"},
                "Query":{"type":"string"},
                "QueryType":{"type":"long"},
                "timeSent":{"type":"string"},
                "queryTime":{"type":"string"},
                "responseTime":{"type":"string"},
                "timeReceived":{"type":"string"},
                "lockoutTime":{"type":"string"},
                "current":{"type":"long"}
            }
        }
    }
}'


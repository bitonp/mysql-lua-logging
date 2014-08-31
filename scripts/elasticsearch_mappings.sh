curl -XPOST http://[MY_ES_SERVER]:9200/mysql/ -d '{
    "settings" : {
        "number_of_shards" : 5,
        "number_of_replicas" : 1,
        "index.analysis.analyzer.default.type": "standard", 
        "index.refresh_interval": "5s"
    },
    "mappings" : {
    "_default_":{
            "_ttl" : {"enabled":true, "default":"4d"},
        "properties" : {
                "@timestamp":{"type":"date"},
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
                "timeSent":{"type":"double"},
                "queryTime":{"type":"double"},
                "responseTime":{"type":"double"},
                "timeReceived":{"type":"double"},
                "lockoutTime":{"type":"double"},
                "current":{"type":"long"}
            }
         },
        "query_data" : {
            "properties" : {
                "@timestamp":{"type":"date"},
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
                "timeSent":{"type":"double"},
                "queryTime":{"type":"double"},
                "responseTime":{"type":"double"},
                "timeReceived":{"type":"double"},
                "lockoutTime":{"type":"double"},
                "current":{"type":"long"}
            }
        }
    }
}'

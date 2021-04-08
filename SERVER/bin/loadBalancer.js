const express = require('express');
const rateLimit = require('express-rate-limit');
const https = require('https');
const request = require('request');
const exec = require('child_process').exec;
const fs = require('fs');
const config = JSON.parse(fs.readFileSync("./config.json",{encoding: "utf8"}));
var servers = [];
var currentServer = 0;
var startingPort = config.instanceServerStartingPort;

const execute = function (command, callback) {
    exec(command, { maxBuffer: 1024 * 250 }, function (error, stdout, stderr) {
        callback(error, stdout, stderr);
    });
};

const startLocalServers = async function(){
    while(servers.length < config.numberOfLocalhostServers){
        await new Promise(function(resolve, reject){
            request("http://127.0.0.1:"+startingPort, async function(error, response, body){
                if(error){
                    await new Promise(function(resolve, reject){
                        var logIdentifier = 0;
                        while(fs.existsSync("logs/outputs"+startingPort+"["+logIdentifier+"].log") || fs.existsSync("logs/errors"+startingPort+"["+logIdentifier+"].log"))
                            logIdentifier++;
                        execute("export PORT="+startingPort+"; export DEBUGGING=false; ./node_modules/forever/bin/forever start -o logs/outputs"+startingPort+"["+logIdentifier+"].log -e logs/errors"+startingPort+"["+logIdentifier+"].log -c ./node server.js", function(error, stdout, stderr){
                            console.log(stdout);
                            servers.push("http://127.0.0.1:"+startingPort);
                            resolve();
                        });
                    });
                }
                resolve();
            });
        });
        console.log("SERVERS STARTED: ");
        console.log(servers);
        startingPort++;
    }
    for(var x = 0; x < config.remoteServerUrls.length; x++){
        servers.push(config.remoteServerUrls[x]);
    }
    return true;
}

startLocalServers().then(function(){
    const handler = function(req, res){
        //Execute the line below in a separate thread for better performance
        //and scalability when handling large files. It has not been implemented 
        //due to the small size of current response data
        req.pipe(request({ url: servers[currentServer] + req.url })).pipe(res);
        currentServer = (currentServer + 1) % servers.length;
    };
    
    const loadBalancer = express().get('*', handler).post('*', handler).use(
        rateLimit({
            windowMs: 15 * 60 * 1000,
            max: 1500,
            message: "try again later."
        })
    );
    
    const credentials = {
        key: fs.readFileSync(config.keyPath, "utf8"),
        cert: fs.readFileSync(config.certPath, "utf8")
    } 
    
    https.createServer(credentials, loadBalancer).listen(config.port);
});


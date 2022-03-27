const express = require('express');
const { createServer } = require('http');
const { createProxyServer } = require('http-proxy')

const BACKEND_SERVER = 'http://localhost:3001';

// set up server and proxy
const app = express();
const server = createServer(app);
const wsProxy = createProxyServer({
    target: BACKEND_SERVER,
    ws: true
});

wsProxy.on("error", (err, req, res, target) => {
    if (err.message.indexOf("ECONNREFUSED") != -1) {
        console.error("proxy: connection to backend refused (backend not started?)")
    } else {
        console.log("proxy:", err)
    }
});

// proxy websockets
server.on('upgrade', (req, socket, head) => {
    wsProxy.ws(req, socket, head);
});

// serve static files
app.use(express.static(__dirname + '/public'));

// listen
server.listen(3000);
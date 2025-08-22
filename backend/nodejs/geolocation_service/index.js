// index.js
const { WebSocketServer } = require('ws');

const PORT = 3000;

// Criamos o servidor WebSocket na porta 3000
const wss = new WebSocketServer({ port: PORT });

// Este evento é disparado sempre que um novo cliente se liga
wss.on('connection', (ws) => {
  console.log('✅ Novo cliente conectado ao serviço de geolocalização!');

  // Este evento é disparado quando recebemos uma mensagem do cliente
  ws.on('message', (message) => {
    console.log('📩 Mensagem recebida: %s', message);

    // Por agora, vamos simplesmente devolver a mensagem para o cliente (eco)
    ws.send(`Servidor recebeu a sua mensagem: ${message}`);
  });

  // Este evento é disparado quando o cliente se desliga
  ws.on('close', () => {
    console.log('❌ Cliente desconectado.');
  });
});

console.log(`🚀 Serviço de Geolocalização (WebSocket) a correr na porta ${PORT}`);

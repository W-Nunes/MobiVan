// index.js
const { WebSocketServer } = require('ws');
const jwt = require('jsonwebtoken');
const url = require('url');

const PORT = 3000;
const JWT_SECRET = 'seu_segredo_super_secreto_aqui'; // O mesmo segredo usado no auth-service

// Estrutura para guardar as "salas" de cada rota.
// A chave será o routeId, e o valor será um Set de clientes (passageiros) naquela rota.
const routes = new Map();

// Criamos o servidor WebSocket
const wss = new WebSocketServer({ port: PORT });

// Este evento é disparado sempre que um novo cliente tenta ligar-se
wss.on('connection', (ws, req) => {
  // 1. Autenticar o utilizador através do token na URL
  const parameters = new URLSearchParams(url.parse(req.url).search);
  const token = parameters.get('token');

  if (!token) {
    console.log('❌ Tentativa de ligação sem token. A desligar.');
    ws.close();
    return;
  }

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    // Anexamos as informações do utilizador à própria ligação WebSocket para referência futura
    ws.userId = decoded.userId;
    ws.role = decoded.role;
    console.log(`✅ Cliente autenticado: Utilizador ${ws.userId} (${ws.role})`);
  } catch (err) {
    console.log('❌ Token inválido. A desligar ligação.');
    ws.close();
    return;
  }

  // 2. Lidar com as mensagens recebidas
  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message);
      console.log('📩 Mensagem recebida:', data);

      // O cliente (motorista ou passageiro) inscreve-se numa rota
      if (data.type === 'subscribe_to_route') {
        const { routeId } = data;
        ws.routeId = routeId; // Guardamos a que rota este cliente pertence

        // Se for um passageiro, adicionamo-lo à sala da rota
        if (ws.role === 'PASSAGEIRO') {
          if (!routes.has(routeId)) {
            routes.set(routeId, new Set());
          }
          routes.get(routeId).add(ws);
          console.log(`🙋 Passageiro ${ws.userId} inscrito na rota ${routeId}. Passageiros na rota: ${routes.get(routeId).size}`);
        }
      }

      // O motorista envia uma atualização de localização
      if (data.type === 'location_update' && ws.role === 'MOTORISTA') {
        const { routeId, location } = data;
        const passengersInRoute = routes.get(routeId);

        if (passengersInRoute) {
          console.log(`🚚 Motorista ${ws.userId} a enviar localização para ${passengersInRoute.size} passageiros na rota ${routeId}.`);
          // Enviamos a localização para cada passageiro na sala da rota
          passengersInRoute.forEach(passengerWs => {
            if (passengerWs.readyState === passengerWs.OPEN) {
              passengerWs.send(JSON.stringify({
                type: 'driver_location',
                location: location
              }));
            }
          });
        }
      }
    } catch (error) {
      console.error('Erro ao processar a mensagem:', error);
    }
  });

  // 3. Lidar com a desconexão
  ws.on('close', () => {
    console.log(`❌ Cliente ${ws.userId} (${ws.role}) desconectado.`);
    // Se era um passageiro, removemo-lo da sala da rota
    if (ws.role === 'PASSAGEIRO' && ws.routeId) {
      const passengersInRoute = routes.get(ws.routeId);
      if (passengersInRoute) {
        passengersInRoute.delete(ws);
        console.log(`🙋 Passageiro ${ws.userId} removido da rota ${ws.routeId}. Passageiros restantes: ${passengersInRoute.size}`);
      }
    }
  });
});

console.log(`🚀 Serviço de Geolocalização (WebSocket) a correr na porta ${PORT}`);

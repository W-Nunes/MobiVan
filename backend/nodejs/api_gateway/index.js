// backend/nodejs/api_gateway/index.js (CÓDIGO CORRETO E COMPLETO)
const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const cors = require('cors');

const app = express();
app.use(cors());

// Definição dos serviços e para onde eles devem ser redirecionados
const services = [
  {
    route: '/auth',
    target: 'http://auth-service:3000',
  },
  {
    route: '/routes',
    target: 'http://routes-service:8000',
  },
  {
    route: '/trips',
    target: 'http://trips-service:8000',
  }
];

// Uma rota de verificação para o próprio Gateway
app.get('/', (req, res) => {
    res.json({ status: 'ok', service: 'api-gateway' });
});


// Configura o redirecionamento (proxy) para cada serviço
services.forEach(({ route, target }) => {
  const proxyOptions = {
    target,
    changeOrigin: true,
    pathRewrite: (path, req) => {
      // Remove o prefixo da rota para a chamada interna
      // Ex: /auth/login -> /login
      const newPath = path.replace(new RegExp(`^${route}`), '');
      console.log(`[API Gateway] Redirecionando: ${req.method} ${path} -> ${target}${newPath}`);
      return newPath;
    },
    onError: (err, req, res) => {
      console.error('[API Gateway] Erro no proxy:', err);
      res.status(500).send('Erro no proxy do API Gateway.');
    }
  };

  app.use(route, createProxyMiddleware(proxyOptions));
});


const PORT = 3000;
app.listen(PORT, () => {
  console.log(`API Gateway funcional a correr na porta ${PORT}`);
});
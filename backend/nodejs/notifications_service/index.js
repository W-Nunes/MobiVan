// index.js
const express = require('express');
const app = express();
const PORT = 3000;

app.get('/', (req, res) => {
  res.send('Olá, Mundo! Este é o serviço Y.');
});

app.listen(PORT, () => {
  console.log(`Serviço Y rodando na porta ${PORT}`);
});
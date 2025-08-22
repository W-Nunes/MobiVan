// index.js
const express = require('express');
const bcrypt = require('bcrypt');
const { pool, testConnection } = require('./db'); // Importamos o nosso pool de ligações

const app = express();
const PORT = 3000;

// Middleware para o Express entender JSON no corpo das requisições
app.use(express.json());

// --- ROTAS ---

// Rota raiz para teste
app.get('/', (req, res) => {
  res.send('Olá, Mundo! Este é o serviço de Autenticação.');
});

// Rota de Registo de Utilizador
app.post('/register', async (req, res) => {
  const { name, email, password, role } = req.body;
  const tenant_id = 'cliente_alpha'; // O nosso tenant_id fixo por enquanto

  // Validação básica
  if (!name || !email || !password || !role) {
    return res.status(400).json({ error: 'Todos os campos são obrigatórios.' });
  }

  try {
    // Encriptar a palavra-passe antes de guardar
    const saltRounds = 10;
    const password_hash = await bcrypt.hash(password, saltRounds);

    // Inserir o novo utilizador na base de dados
    const newUserQuery = `
      INSERT INTO users (name, email, password_hash, role, tenant_id)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING id, name, email, role, created_at;
    `;
    
    const values = [name, email, password_hash, role, tenant_id];
    const result = await pool.query(newUserQuery, values);

    res.status(201).json(result.rows[0]);

  } catch (err) {
    // Tratar erro de email duplicado
    if (err.code === '23505') { // Código de erro do PostgreSQL para violação de constraint UNIQUE
      return res.status(409).json({ error: 'Este email já está em uso.' });
    }
    console.error('Erro ao registar utilizador:', err);
    res.status(500).json({ error: 'Erro interno do servidor.' });
  }
});


// --- INICIALIZAÇÃO DO SERVIDOR ---
app.listen(PORT, () => {
  console.log(`Serviço de Autenticação a correr na porta ${PORT}`);
  testConnection();
});

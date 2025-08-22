// index.js
const express = require('express');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken'); // Importamos a biblioteca JWT
const { pool, testConnection } = require('./db');

const app = express();
const PORT = 3000;
const JWT_SECRET = 'seu_segredo_super_secreto_aqui'; // ATENÇÃO: Mude isto para uma variável de ambiente em produção

app.use(express.json());

// --- ROTAS ---

app.get('/', (req, res) => {
  res.send('Olá, Mundo! Este é o serviço de Autenticação.');
});

app.post('/register', async (req, res) => {
  const { name, email, password, role } = req.body;
  const tenant_id = 'cliente_alpha';

  if (!name || !email || !password || !role) {
    return res.status(400).json({ error: 'Todos os campos são obrigatórios.' });
  }

  try {
    const saltRounds = 10;
    const password_hash = await bcrypt.hash(password, saltRounds);

    const newUserQuery = `
      INSERT INTO users (name, email, password_hash, role, tenant_id)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING id, name, email, role, created_at;
    `;
    
    const values = [name, email, password_hash, role, tenant_id];
    const result = await pool.query(newUserQuery, values);

    res.status(201).json(result.rows[0]);

  } catch (err) {
    if (err.code === '23505') {
      return res.status(409).json({ error: 'Este email já está em uso.' });
    }
    console.error('Erro ao registar utilizador:', err);
    res.status(500).json({ error: 'Erro interno do servidor.' });
  }
});

// Rota de Login de Utilizador
app.post('/login', async (req, res) => {
  const { email, password } = req.body;
  const tenant_id = 'cliente_alpha'; // O login também é por tenant

  if (!email || !password) {
    return res.status(400).json({ error: 'Email e palavra-passe são obrigatórios.' });
  }

  try {
    // 1. Encontrar o utilizador pelo email e tenant_id
    const userQuery = 'SELECT * FROM users WHERE email = $1 AND tenant_id = $2';
    const result = await pool.query(userQuery, [email, tenant_id]);
    const user = result.rows[0];

    if (!user) {
      return res.status(404).json({ error: 'Credenciais inválidas.' }); // Mensagem genérica por segurança
    }

    // 2. Comparar a palavra-passe enviada com o hash guardado
    const isMatch = await bcrypt.compare(password, user.password_hash);

    if (!isMatch) {
      return res.status(401).json({ error: 'Credenciais inválidas.' }); // Mensagem genérica por segurança
    }

    // 3. Gerar o Token JWT
    const payload = {
      userId: user.id,
      role: user.role,
      tenantId: user.tenant_id,
    };

    const token = jwt.sign(payload, JWT_SECRET, { expiresIn: '8h' }); // Token expira em 8 horas

    // 4. Enviar o token de volta para o cliente
    res.json({
      message: 'Login bem-sucedido!',
      token: token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role
      }
    });

  } catch (err) {
    console.error('Erro no login:', err);
    res.status(500).json({ error: 'Erro interno do servidor.' });
  }
});

// --- INICIALIZAÇÃO DO SERVIDOR ---
app.listen(PORT, () => {
  console.log(`Serviço de Autenticação a correr na porta ${PORT}`);
  testConnection();
});

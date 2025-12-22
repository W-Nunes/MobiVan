// backend/nodejs/auth_service/index.js (ATUALIZADO COM LOGS E CONEXÃO REAL)
const express = require('express');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { pool } = require('./db'); // Importa o pool configurado
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

// Configurações de Ambiente
const JWT_SECRET = process.env.JWT_SECRET || 'your_jwt_secret_standard';
const FIXED_TENANT_ID = 'cliente_alpha'; // Consistência com os dados do Postgres

// Rota de verificação de saúde (Health Check)
app.get('/health-check', (req, res) => {
  res.status(200).json({ 
    status: 'ok', 
    service: 'auth-service', 
    timestamp: new Date().toISOString() 
  });
});

// Rota de Registro
app.post('/register', async (req, res) => {
  const { email, password, role } = req.body;
  
  console.log(`[REGISTER] Tentativa de registo para: ${email}`);

  try {
    const hashedPassword = await bcrypt.hash(password, 10);
    const newUser = await pool.query(
      'INSERT INTO users (email, password_hash, role, tenant_id) VALUES ($1, $2, $3, $4) RETURNING id, email, role',
      [email, hashedPassword, role || 'driver', FIXED_TENANT_ID]
    );
    
    console.log(`[REGISTER] Utilizador criado com sucesso: ${email}`);
    res.status(201).json(newUser.rows[0]);
  } catch (err) {
    console.error(`[REGISTER] Erro ao registar: ${err.message}`);
    res.status(500).json({ error: 'Erro no servidor ao registar utilizador' });
  }
});

// Rota de Login
app.post('/login', async (req, res) => {
  const { email, password } = req.body;
  
  console.log(`[LOGIN] >>> Nova requisição recebida para: ${email}`);

  try {
    // Busca o utilizador no banco de dados
    const userResult = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    
    if (userResult.rows.length === 0) {
      console.log(`[LOGIN] XXX Falha: Utilizador não encontrado (${email})`);
      return res.status(400).json({ error: 'Credenciais inválidas' });
    }

    const user = userResult.rows[0];
    console.log(`[LOGIN] OK: Utilizador localizado. Verificando password...`);

    // Compara a password com o hash
    const validPassword = await bcrypt.compare(password, user.password_hash);
    
    if (!validPassword) {
      console.log(`[LOGIN] XXX Falha: Password incorreta para ${email}`);
      return res.status(400).json({ error: 'Credenciais inválidas' });
    }

    // Geração do Token JWT
    const token = jwt.sign(
      { 
        userId: user.id, 
        role: user.role, 
        tenantId: user.tenant_id 
      },
      JWT_SECRET,
      { expiresIn: '2h' }
    );

    console.log(`[LOGIN] SUCCESS: Login realizado com sucesso para ${email} (ID: ${user.id})`);
    
    res.json({ 
      token, 
      role: user.role, 
      userId: user.id,
      tenantId: user.tenant_id
    });

  } catch (err) {
    console.error(`[LOGIN] CRITICAL ERROR: ${err.message}`);
    res.status(500).json({ error: 'Erro interno no serviço de autenticação' });
  }
});

const PORT = 3000;
app.listen(PORT, () => {
  console.log('---------------------------------------------------------');
  console.log(`Serviço de Autenticação ativo na porta ${PORT}`);
  console.log(`Tenant ID configurado: ${FIXED_TENANT_ID}`);
  console.log('---------------------------------------------------------');
});
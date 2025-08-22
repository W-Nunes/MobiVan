// db.js
// Este arquivo gerencia a conexão com o banco de dados PostgreSQL.

const { Pool } = require('pg');

// O Pool gerencia múltiplas conexões de clientes para nós.
// Docker Compose cria uma rede onde os serviços podem se comunicar usando seus nomes.
// Por isso, o 'host' é 'postgres', o nome que demos ao serviço no docker-compose.yml.
const pool = new Pool({
  user: 'vanuser',
  host: 'postgres', // Nome do serviço do banco de dados no docker-compose
  database: 'van_management_db',
  password: 'vanpassword',
  port: 5432,
});

// Função para testar a conexão
const testConnection = async () => {
  try {
    const client = await pool.connect();
    console.log('✅ Conexão com o PostgreSQL estabelecida com sucesso!');
    const res = await client.query('SELECT NOW()');
    console.log('🕒 Hora atual do banco de dados:', res.rows[0].now);
    client.release(); // Libera o cliente de volta para o pool
  } catch (err) {
    console.error('❌ Erro ao conectar com o PostgreSQL:', err.stack);
  }
};

// Modifique o seu arquivo index.js para chamar esta função
// e exporte o pool para ser usado em outras partes da aplicação.
module.exports = {
  pool,
  testConnection,
};

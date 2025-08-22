# main.py
import os
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv

# Carregar variáveis de ambiente (útil para desenvolvimento)
load_dotenv()

app = FastAPI()

# --- Configuração da Base de Dados ---
# Usamos variáveis de ambiente para as credenciais, uma boa prática.
# O Docker Compose irá passar estas variáveis para nós.
DB_NAME = os.getenv("POSTGRES_DB", "van_management_db")
DB_USER = os.getenv("POSTGRES_USER", "vanuser")
DB_PASSWORD = os.getenv("POSTGRES_PASSWORD", "vanpassword")
DB_HOST = os.getenv("DB_HOST", "postgres") # 'postgres' é o nome do serviço no Docker

DATABASE_URL = f"dbname='{DB_NAME}' user='{DB_USER}' password='{DB_PASSWORD}' host='{DB_HOST}'"

def get_db_connection():
    """Função para obter uma ligação à base de dados."""
    try:
        conn = psycopg2.connect(DATABASE_URL)
        return conn
    except psycopg2.OperationalError as e:
        print(f"❌ Erro ao conectar à base de dados: {e}")
        raise

# --- Modelos de Dados (Pydantic) ---
# Pydantic ajuda a validar os dados que recebemos nas requisições.
class RouteCreate(BaseModel):
    name: str
    driver_id: int

class RouteResponse(BaseModel):
    id: int
    name: str
    driver_id: int
    tenant_id: str

# --- ROTAS ---

@app.get("/")
def read_root():
    """Rota raiz para verificar se o serviço está no ar."""
    return {"message": "Olá, Mundo! Este é o Serviço de Rotas."}

@app.post("/routes", response_model=RouteResponse)
def create_route(route: RouteCreate):
    """Cria uma nova rota na base de dados."""
    tenant_id = "cliente_alpha" # O nosso tenant_id fixo por enquanto

    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            # Primeiro, verificamos se o driver_id corresponde a um utilizador com a função 'MOTORISTA'
            cur.execute(
                "SELECT id FROM users WHERE id = %s AND role = 'MOTORISTA' AND tenant_id = %s",
                (route.driver_id, tenant_id)
            )
            driver = cur.fetchone()
            if not driver:
                raise HTTPException(status_code=404, detail="Motorista não encontrado ou inválido.")

            # Se o motorista for válido, inserimos a nova rota
            cur.execute(
                "INSERT INTO routes (name, driver_id, tenant_id) VALUES (%s, %s, %s) RETURNING id, name, driver_id, tenant_id",
                (route.name, route.driver_id, tenant_id)
            )
            new_route = cur.fetchone()
            conn.commit()
            return new_route
    except psycopg2.Error as e:
        print(f"Erro na base de dados: {e}")
        raise HTTPException(status_code=500, detail="Erro interno do servidor ao criar a rota.")
    finally:
        if conn:
            conn.close()


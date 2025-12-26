# main.py
import os
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv
from datetime import date
from typing import List

# Carregar variáveis de ambiente
load_dotenv()

app = FastAPI()

# --- Configuração da Base de Dados ---
DB_NAME = os.getenv("POSTGRES_DB", "van_management_db")
DB_USER = os.getenv("POSTGRES_USER", "vanuser")
DB_PASSWORD = os.getenv("POSTGRES_PASSWORD", "vanpassword")
DB_HOST = os.getenv("DB_HOST", "postgres")

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
class ConfirmationUpdate(BaseModel):
    passenger_id: int
    route_id: int
    status: str # Espera-se 'CONFIRMED' ou 'CANCELLED'

class ConfirmationDetails(BaseModel):
    passenger_id: int
    passenger_name: str
    status: str
    latitude: float = None  # Novo campo opcional
    longitude: float = None # Novo campo opcional
    address: str = None     # Novo campo opcional

# --- ROTAS ---

@app.get("/")
def read_root():
    """Rota raiz para verificar se o serviço está no ar."""
    return {"message": "Olá, Mundo! Este é o Serviço de Viagens."}

@app.post("/confirmations", status_code=200)
def confirm_presence(confirmation: ConfirmationUpdate):
    """Regista a confirmação de presença de um passageiro para a viagem do dia."""
    tenant_id = "cliente_alpha"
    today = date.today()
    conn = None
    
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("""
                INSERT INTO trips (route_id, trip_date, tenant_id)
                VALUES (%s, %s, %s)
                ON CONFLICT (route_id, trip_date) DO UPDATE SET status = trips.status
                RETURNING id;
            """, (confirmation.route_id, today, tenant_id))
            trip = cur.fetchone()
            if not trip:
                raise HTTPException(status_code=500, detail="Não foi possível encontrar ou criar a viagem para hoje.")
            trip_id = trip['id']

            cur.execute("""
                INSERT INTO trip_confirmations (trip_id, passenger_id, status, tenant_id, confirmed_at)
                VALUES (%s, %s, %s, %s, CURRENT_TIMESTAMP)
                ON CONFLICT (trip_id, passenger_id) DO UPDATE SET
                    status = EXCLUDED.status,
                    confirmed_at = CURRENT_TIMESTAMP;
            """, (trip_id, confirmation.passenger_id, confirmation.status, tenant_id))
            
            conn.commit()
            return {"message": f"Presença atualizada para o estado '{confirmation.status}' com sucesso."}

    except psycopg2.Error as e:
        print(f"Erro na base de dados: {e}")
        raise HTTPException(status_code=500, detail="Erro interno do servidor.")
    finally:
        if conn:
            conn.close()

@app.get("/trips/today/{route_id}/confirmations", response_model=List[ConfirmationDetails])
def get_today_confirmations(route_id: int):
    """Obtém a lista de confirmações. Se não houver viagem, retorna PENDING para todos."""
    tenant_id = "cliente_alpha"
    today = date.today()
    conn = None

    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            # 1. Tenta achar a viagem de hoje
            cur.execute(
                "SELECT id FROM trips WHERE route_id = %s AND trip_date = %s AND tenant_id = %s",
                (route_id, today, tenant_id)
            )
            trip = cur.fetchone()

            if not trip:
                # CENÁRIO A: Ninguém confirmou ainda.
                # Buscamos apenas os passageiros da rota e definimos status como PENDING
                cur.execute("""
                    SELECT
                        u.id as passenger_id,
                        u.name as passenger_name,
                        u.latitude,
                        u.longitude,
                        u.address,
                        'PENDING' as status
                    FROM users u
                    JOIN passenger_routes pr ON u.id = pr.passenger_id
                    WHERE pr.route_id = %s AND u.role = 'PASSAGEIRO' AND u.tenant_id = %s
                """, (route_id, tenant_id))
                return cur.fetchall()

            # CENÁRIO B: A viagem já existe (alguém confirmou).
            trip_id = trip['id']
            cur.execute("""
                SELECT
                    u.id as passenger_id,
                    u.name as passenger_name,
                    u.latitude,
                    u.longitude,
                    u.address,
                    COALESCE(tc.status, 'PENDING') as status
                FROM users u
                JOIN passenger_routes pr ON u.id = pr.passenger_id
                LEFT JOIN trip_confirmations tc ON u.id = tc.passenger_id AND tc.trip_id = %s
                WHERE pr.route_id = %s AND u.role = 'PASSAGEIRO' AND u.tenant_id = %s
            """, (trip_id, route_id, tenant_id))

            confirmations = cur.fetchall()
            return confirmations

    except psycopg2.Error as e:
        print(f"Erro na base de dados: {e}")
        raise HTTPException(status_code=500, detail="Erro interno do servidor.")
    finally:
        if conn:
            conn.close()

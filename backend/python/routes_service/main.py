# main.py
import os
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv
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
class RouteCreate(BaseModel):
    name: str
    driver_id: int

class RouteResponse(BaseModel):
    id: int
    name: str
    driver_id: int
    tenant_id: str

class PassengerAdd(BaseModel):
    passenger_id: int

class PassengerResponse(BaseModel):
    id: int
    name: str
    email: str

class RouteDetailResponse(RouteResponse):
    passengers: List[PassengerResponse] = []

# --- ROTAS ---

@app.get("/")
def read_root():
    """Rota raiz para verificar se o serviço está no ar."""
    return {"message": "Olá, Mundo! Este é o Serviço de Rotas."}

@app.post("/routes", response_model=RouteResponse)
def create_route(route: RouteCreate):
    """Cria uma nova rota na base de dados."""
    tenant_id = "cliente_alpha"
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                "SELECT id FROM users WHERE id = %s AND role = 'MOTORISTA' AND tenant_id = %s",
                (route.driver_id, tenant_id)
            )
            if not cur.fetchone():
                raise HTTPException(status_code=404, detail="Motorista não encontrado ou inválido.")

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

@app.post("/routes/{route_id}/passengers", status_code=201)
def add_passenger_to_route(route_id: int, passenger: PassengerAdd):
    """Adiciona um passageiro a uma rota existente."""
    tenant_id = "cliente_alpha"
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                "SELECT id FROM users WHERE id = %s AND role = 'PASSAGEIRO' AND tenant_id = %s",
                (passenger.passenger_id, tenant_id)
            )
            if not cur.fetchone():
                raise HTTPException(status_code=404, detail="Passageiro não encontrado ou inválido.")

            cur.execute(
                "SELECT id FROM routes WHERE id = %s AND tenant_id = %s",
                (route_id, tenant_id)
            )
            if not cur.fetchone():
                raise HTTPException(status_code=404, detail="Rota não encontrada.")

            cur.execute(
                "INSERT INTO passenger_routes (route_id, passenger_id, tenant_id) VALUES (%s, %s, %s)",
                (route_id, passenger.passenger_id, tenant_id)
            )
            conn.commit()
            return {"message": "Passageiro adicionado à rota com sucesso."}
    except psycopg2.IntegrityError:
        raise HTTPException(status_code=409, detail="Este passageiro já está nesta rota.")
    except psycopg2.Error as e:
        print(f"Erro na base de dados: {e}")
        raise HTTPException(status_code=500, detail="Erro interno do servidor.")
    finally:
        if conn:
            conn.close()

@app.get("/routes/{route_id}", response_model=RouteDetailResponse)
def get_route_details(route_id: int):
    """Obtém os detalhes de uma rota, incluindo a lista de passageiros."""
    tenant_id = "cliente_alpha"
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            # 1. Obter os detalhes da rota
            cur.execute(
                "SELECT * FROM routes WHERE id = %s AND tenant_id = %s",
                (route_id, tenant_id)
            )
            route_details = cur.fetchone()
            if not route_details:
                raise HTTPException(status_code=404, detail="Rota não encontrada.")

            # 2. Obter a lista de passageiros associados a essa rota
            cur.execute("""
                SELECT u.id, u.name, u.email
                FROM users u
                JOIN passenger_routes pr ON u.id = pr.passenger_id
                WHERE pr.route_id = %s AND pr.tenant_id = %s
            """, (route_id, tenant_id))
            passengers = cur.fetchall()

            # 3. Combinar os resultados
            route_details["passengers"] = passengers
            return route_details
    except psycopg2.Error as e:
        print(f"Erro na base de dados: {e}")
        raise HTTPException(status_code=500, detail="Erro interno do servidor.")
    finally:
        if conn:
            conn.close()
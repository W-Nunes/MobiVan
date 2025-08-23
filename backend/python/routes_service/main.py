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
    return {"message": "Olá, Mundo! Este é o Serviço de Rotas."}

@app.get("/routes", response_model=List[RouteResponse])
def get_all_routes():
    # (Código existente - sem alterações)
    tenant_id = "cliente_alpha"
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                "SELECT * FROM routes WHERE tenant_id = %s",
                (tenant_id,)
            )
            routes = cur.fetchall()
            return routes
    except psycopg2.Error as e:
        print(f"Erro na base de dados: {e}")
        raise HTTPException(status_code=500, detail="Erro interno do servidor.")
    finally:
        if conn:
            conn.close()

@app.post("/routes", response_model=RouteResponse)
def create_route(route: RouteCreate):
    # (Código existente - sem alterações)
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
    # (Código existente - sem alterações)
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
    # (Código existente - sem alterações)
    tenant_id = "cliente_alpha"
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                "SELECT * FROM routes WHERE id = %s AND tenant_id = %s",
                (route_id, tenant_id)
            )
            route_details = cur.fetchone()
            if not route_details:
                raise HTTPException(status_code=404, detail="Rota não encontrada.")

            cur.execute("""
                SELECT u.id, u.name, u.email
                FROM users u
                JOIN passenger_routes pr ON u.id = pr.passenger_id
                WHERE pr.route_id = %s AND pr.tenant_id = %s
            """, (route_id, tenant_id))
            passengers = cur.fetchall()

            route_details["passengers"] = passengers
            return route_details
    except psycopg2.Error as e:
        print(f"Erro na base de dados: {e}")
        raise HTTPException(status_code=500, detail="Erro interno do servidor.")
    finally:
        if conn:
            conn.close()

# --- NOVA ROTA ---
@app.get("/passengers/{passenger_id}/route", response_model=RouteResponse)
def get_passenger_route(passenger_id: int):
    """Obtém a rota principal de um passageiro."""
    tenant_id = "cliente_alpha"
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            # Fazemos um JOIN para encontrar a rota a partir do ID do passageiro
            cur.execute("""
                SELECT r.id, r.name, r.driver_id, r.tenant_id
                FROM routes r
                JOIN passenger_routes pr ON r.id = pr.route_id
                WHERE pr.passenger_id = %s AND r.tenant_id = %s
                LIMIT 1;
            """, (passenger_id, tenant_id))
            route = cur.fetchone()
            if not route:
                raise HTTPException(status_code=404, detail="Passageiro não associado a nenhuma rota.")
            return route
    except psycopg2.Error as e:
        print(f"Erro na base de dados: {e}")
        raise HTTPException(status_code=500, detail="Erro interno do servidor.")
    finally:
        if conn:
            conn.close()

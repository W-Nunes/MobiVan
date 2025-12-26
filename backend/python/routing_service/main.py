# backend/python/routing_service/main.py
import httpx
import math
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Dict, Any, Optional

app = FastAPI()

# --- MODELOS ---

class Location(BaseModel):
    id: int
    name: str
    latitude: float
    longitude: float
    type: str = "passenger" # 'driver' ou 'passenger'

class RouteRequest(BaseModel):
    driver_start: Location
    passengers: List[Location]

class RouteResponse(BaseModel):
    optimized_order: List[Location] # A lista de passageiros na ordem certa
    total_distance_km: float        # Distância real por estrada
    total_duration_minutes: float   # Tempo estimado (com trânsito padrão)
    geometry: Dict[str, Any]        # O GeoJSON para o Flutter desenhar a linha

# --- LÓGICA AUXILIAR ---

def calculate_haversine(lat1, lon1, lat2, lon2):
    """
    Calcula distância em linha reta para o algoritmo de ordenação (rápido).
    """
    R = 6371  # Raio da Terra em km
    dLat = math.radians(lat2 - lat1)
    dLon = math.radians(lon2 - lon1)
    a = math.sin(dLat/2) * math.sin(dLat/2) + \
        math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * \
        math.sin(dLon/2) * math.sin(dLon/2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return R * c

async def get_osrm_route(ordered_locations: List[Location]):
    """
    Consulta a API pública do OSRM para obter o trajeto real de carro.
    NOTA: O OSRM usa a ordem Longitude,Latitude.
    """
    if len(ordered_locations) < 2:
        return None

    # Formata coordenadas: "lon,lat;lon,lat;..."
    coords_string = ";".join([f"{loc.longitude},{loc.latitude}" for loc in ordered_locations])

    # URL da API Demo (Para produção, recomenda-se hospedar seu próprio container OSRM)
    url = f"http://router.project-osrm.org/route/v1/driving/{coords_string}?overview=full&geometries=geojson"

    async with httpx.AsyncClient() as client:
        try:
            response = await client.get(url, timeout=10.0)
            response.raise_for_status()
            data = response.json()
            if "routes" in data and len(data["routes"]) > 0:
                route = data["routes"][0]
                return {
                    "distance_meters": route["distance"],
                    "duration_seconds": route["duration"],
                    "geometry": route["geometry"]
                }
        except Exception as e:
            print(f"Erro ao conectar com OSRM: {e}")
            return None
    return None

# --- ROTAS ---

@app.get("/")
def read_root():
    return {"message": "Serviço de Roteirização Inteligente Ativo 🚀"}

@app.get("/")
def read_root():
    return {"message": "Serviço de Roteirização Inteligente Ativo 🚀"}

@app.post("/optimize", response_model=RouteResponse)
async def optimize_route(request: RouteRequest):
    """
    1. Define a melhor ordem de parada (Algoritmo Vizinho Mais Próximo).
    2. Calcula a rota real nessa ordem usando OSRM.
    """
    if not request.passengers:
        return RouteResponse(
            optimized_order=[],
            total_distance_km=0.0,
            total_duration_minutes=0.0,
            geometry={}
        )

    # --- PASSO 1: ORDENAÇÃO (Seu algoritmo original) ---
    unvisited = request.passengers.copy()
    current_location = request.driver_start
    optimized_path = [] # Lista final de passageiros ordenados

    # Algoritmo Greedy (Vizinho mais próximo)
    while unvisited:
        nearest_passenger = None
        min_dist = float('inf')

        for passenger in unvisited:
            dist = calculate_haversine(
                current_location.latitude, current_location.longitude,
                passenger.latitude, passenger.longitude
            )
            if dist < min_dist:
                min_dist = dist
                nearest_passenger = passenger

        if nearest_passenger:
            optimized_path.append(nearest_passenger)
            current_location = nearest_passenger
            unvisited.remove(nearest_passenger)

    # --- PASSO 2: ROTA REAL (OSRM) ---
    # Montamos a lista completa: [Motorista] + [Passageiros Ordenados]
    full_route_points = [request.driver_start] + optimized_path

    osrm_data = await get_osrm_route(full_route_points)

    real_distance_km = 0.0
    real_duration_min = 0.0
    route_geometry = {}

    if osrm_data:
        real_distance_km = round(osrm_data["distance_meters"] / 1000, 2)
        real_duration_min = round(osrm_data["duration_seconds"] / 60, 0)
        route_geometry = osrm_data["geometry"]
    else:
        # Fallback: Se o OSRM falhar, retornamos sem geometria e com distância aproximada
        print("Aviso: OSRM falhou ou indisponível. Retornando dados básicos.")

    return RouteResponse(
        optimized_order=optimized_path,
        total_distance_km=real_distance_km,
        total_duration_minutes=real_duration_min,
        geometry=route_geometry
    )
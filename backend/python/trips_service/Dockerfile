# Dockerfile para serviços Python (ex: ./backend/python/routes_service/Dockerfile)
# Este arquivo é um modelo para todos os serviços baseados em Python/FastAPI.

# Use uma imagem base oficial do Python.
FROM python:3.9-slim

# Defina o diretório de trabalho dentro do contêiner.
WORKDIR /app

# Copie o arquivo de dependências para o contêiner.
COPY requirements.txt .

# Instale as dependências.
RUN pip install --no-cache-dir -r requirements.txt

# Copie o resto do código da aplicação para o diretório de trabalho.
COPY . .

# Exponha a porta que a aplicação vai rodar.
EXPOSE 8000

# Comando para iniciar a aplicação usando Uvicorn (servidor ASGI para FastAPI).
# --host 0.0.0.0 permite que a aplicação seja acessível de fora do contêiner.
# --reload monitora mudanças nos arquivos e reinicia o servidor automaticamente (ótimo para desenvolvimento).
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]

# Dockerfile para serviços Node.js (ex: ./backend/nodejs/api_gateway/Dockerfile)
# Este arquivo é um modelo para todos os serviços baseados em Node.js/Express.

# Use uma imagem base oficial do Node.js.
FROM node:16-alpine

# Defina o diretório de trabalho dentro do contêiner.
WORKDIR /usr/src/app

# Copie o package.json e package-lock.json para o contêiner.
# Usamos 'COPY' em vez de montar um volume para esses arquivos para aproveitar o cache do Docker.
COPY package*.json ./

# Instale as dependências da aplicação.
RUN npm install

# Copie o resto do código da aplicação para o diretório de trabalho.
COPY . .

# Exponha a porta que a aplicação vai rodar.
EXPOSE 3000

# Comando para iniciar a aplicação usando nodemon.
# nodemon monitora mudanças nos arquivos e reinicia o servidor automaticamente (ótimo para desenvolvimento).
CMD [ "npm", "run", "dev" ]

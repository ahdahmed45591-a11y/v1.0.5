# Node 22 impose par les dependances : @vitejs/plugin-react (>=22.12),
# @tailwindcss/oxide et @google/genai (>=20). Sous Node 18, npm ignore
# silencieusement leurs binaires natifs et le build casse.
FROM node:22-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build

# Image nginx officielle deja configuree pour tourner en non-root (port 8080
# au lieu de 80) -- evite d'ecrire/maintenir un adduser+chown des dossiers de
# cache nginx a la main.
FROM nginxinc/nginx-unprivileged:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]

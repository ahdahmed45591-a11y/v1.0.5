# Node 22 impose par les dependances : @vitejs/plugin-react (>=22.12),
# @tailwindcss/oxide et @google/genai (>=20). Sous Node 18, npm ignore
# silencieusement leurs binaires natifs et le build casse.
FROM node:22-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .
# Vite integre les VITE_* dans le bundle a la compilation (pas au demarrage
# du conteneur) -- il faut donc les faire passer en ARG de build, sinon la
# valeur par defaut (localhost:3001) se retrouve figee dans le JS livre en
# production. Render transmet automatiquement toute variable d'environnement
# du service portant le meme nom qu'un ARG declare ici.
ARG VITE_API_BASE
ENV VITE_API_BASE=$VITE_API_BASE
RUN npm run build

# Image nginx officielle deja configuree pour tourner en non-root (port 8080
# au lieu de 80) -- evite d'ecrire/maintenir un adduser+chown des dossiers de
# cache nginx a la main.
FROM nginxinc/nginx-unprivileged:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
EXPOSE 8080
# Deja le defaut de l'image (voir commentaire ci-dessus) -- explicite ici
# pour que les scanners qui ne resolvent pas le USER de l'image de base ne
# la signalent pas a tort comme "tourne en root".
USER nginx
CMD ["nginx", "-g", "daemon off;"]

# Node 22 impose par les dependances : @vitejs/plugin-react (>=22.12),
# @tailwindcss/oxide et @google/genai (>=20). Sous Node 18, npm ignore
# silencieusement leurs binaires natifs et le build casse.
FROM node:22-alpine AS builder

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

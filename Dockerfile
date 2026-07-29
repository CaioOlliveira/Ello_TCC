FROM node:22-alpine AS build

WORKDIR /app/backend

COPY backend/package*.json ./
RUN npm ci

COPY backend/ ./
RUN npm run build

FROM node:22-alpine

WORKDIR /app/backend

ENV NODE_ENV=production
ENV PORT=8080

COPY backend/package*.json ./
RUN npm ci --omit=dev

COPY --from=build /app/backend/dist ./dist

EXPOSE 8080

CMD ["npm", "start"]

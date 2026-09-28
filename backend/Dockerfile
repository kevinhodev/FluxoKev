FROM node:24-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
COPY test ./test
RUN npm run build

FROM node:24-alpine AS runtime
ENV NODE_ENV=production
WORKDIR /app
RUN apk add --no-cache poppler-utils tesseract-ocr tesseract-ocr-data-por
COPY package*.json ./
RUN npm ci --omit=dev
COPY --from=build /app/dist ./dist
COPY migrations ./migrations
EXPOSE 8080
USER node
CMD ["sh", "-c", "node dist/src/db/migrate.js && node dist/src/server.js"]

FROM node:22-bookworm-slim
WORKDIR /app
ENV NODE_ENV=production
COPY package*.json ./
RUN npm ci --omit=dev
COPY src ./src
COPY migrations ./migrations
RUN mkdir -p /app/.cache && chown node:node /app/.cache
USER node
EXPOSE 3000
CMD ["node","src/index.js"]

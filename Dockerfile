FROM node:10

# express performs optimizations if NODE_ENV is production
ENV NODE_ENV production
EXPOSE 3000

# install dumb-init since nodejs doesn't handle SIGTERMs well as PID 1
RUN apt-get update && apt-get install -y dumb-init \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/app

COPY  --chown=node:node bin ./bin/

COPY --chown=node:node package*.json ./
# more production optimizations
RUN npm ci --only=production

COPY --chown=node:node src ./src/

USER node

CMD ["dumb-init", "node", "src/000.js"]

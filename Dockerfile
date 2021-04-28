FROM node:10

EXPOSE 3000

WORKDIR /usr/src/app

COPY bin ./bin/

COPY package*.json ./
RUN npm install

COPY src ./src/

CMD ["node", "src/000.js"]
# CMD ["sleep", "100s"]

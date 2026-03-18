FROM node:20-alpine

WORKDIR /usr/src/app

COPY --chown=node:node package*.json ./
RUN npm install

COPY --chown=node:node . ./

USER node

CMD ["npm", "start"]

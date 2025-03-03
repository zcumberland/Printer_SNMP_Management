FROM node:16-alpine

WORKDIR /app

# Copy package.json and install dependencies
COPY package*.json ./
RUN npm ci --only=production

# Create directory structure
RUN mkdir -p models routes middleware

# Copy server code
COPY server.js .
COPY models/ models/
COPY routes/ routes/
COPY middleware/ middleware/

# Expose the port
EXPOSE 3000

# Start the server
CMD ["node", "server.js"]
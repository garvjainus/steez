# ---- Base Stage ----
# Use an official Node.js image as the base for building the application.
# Using a specific version ensures consistency.
FROM node:18-alpine AS builder

# Set the working directory inside the container.
WORKDIR /usr/src/app

# Copy package.json and package-lock.json to leverage Docker's layer caching.
# This step only re-runs if these files change.
COPY package*.json ./

# Install all production dependencies.
RUN npm install

# Copy the rest of your application source code into the container.
COPY . .

# Build the NestJS application. This will create a 'dist' folder with the compiled JavaScript.
RUN npm run build

# ---- Production Stage ----
# Start a new, smaller image for the final production environment.
# 'alpine' images are very lightweight, which improves security and performance.
FROM node:18-alpine

# Set the working directory again for the production stage.
WORKDIR /usr/src/app

# Copy only the necessary files from the 'builder' stage.
# This includes the compiled code, node_modules, and package.json.
# We don't need the source TypeScript files or devDependencies in production.
COPY --from=builder /usr/src/app/dist ./dist
COPY --from=builder /usr/src/app/node_modules ./node_modules
COPY --from=builder /usr/src/app/package.json ./package.json

# Expose the port that the NestJS application will run on.
# Your main.ts file likely specifies port 3000.
EXPOSE 3000

# The command to start the application when the container launches.
CMD ["node", "dist/main"] 
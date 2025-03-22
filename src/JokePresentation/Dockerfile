# Base image for runtime
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS base
WORKDIR /app
EXPOSE 80

# Build image with SDK
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build

# Install curl and clean up to reduce image size
RUN apt-get update && apt-get install -y curl && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY ["JokePresentation.csproj", "./"]

# Restore, build, and publish in a single layer to improve caching and efficiency
RUN dotnet restore "JokePresentation.csproj"
COPY . . 
RUN dotnet build "JokePresentation.csproj" -c Release -o /app/build \
    && dotnet publish "JokePresentation.csproj" -c Release -o /app/publish

# Final runtime image
FROM base AS final
WORKDIR /app

# Copy the published files from the build stage
COPY --from=build /app/publish .

# Set entry point to run the application
ENTRYPOINT ["dotnet", "JokePresentation.dll"]

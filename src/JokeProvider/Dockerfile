FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src/JokeProvider
COPY *.csproj ./
RUN dotnet restore
COPY . .
RUN dotnet publish "JokeProvider.csproj" -c Release -o /out

FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime
RUN apt-get update && apt-get install -y curl && apt-get clean && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /out .
EXPOSE 8080
ENTRYPOINT ["dotnet", "JokeProvider.dll"]
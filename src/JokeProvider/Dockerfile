FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src/JokeProvider
COPY *.csproj ./
RUN dotnet restore
COPY . .
RUN dotnet publish "JokeProvider.csproj" -c Release -o /out

FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime
WORKDIR /app
COPY --from=build /out .
EXPOSE 8080
ENTRYPOINT ["dotnet", "JokeProvider.dll"]
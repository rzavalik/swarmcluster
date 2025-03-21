FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS base
WORKDIR /app
EXPOSE 80

FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src
COPY ["JokePresentation.csproj", "./"]
RUN dotnet restore "JokePresentation.csproj"
COPY . . 
RUN dotnet build "JokePresentation.csproj" -c Release -o /app/build
RUN dotnet publish "JokePresentation.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "JokePresentation.dll"]

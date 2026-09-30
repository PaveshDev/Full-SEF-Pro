# Build Stage
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy project files for layer caching
COPY ["backend/src/LoopWorth.Api/LoopWorth.Api.csproj", "backend/src/LoopWorth.Api/"]
COPY ["backend/src/LoopWorth.Application/LoopWorth.Application.csproj", "backend/src/LoopWorth.Application/"]
COPY ["backend/src/LoopWorth.Domain/LoopWorth.Domain.csproj", "backend/src/LoopWorth.Domain/"]
COPY ["backend/src/LoopWorth.Infrastructure/LoopWorth.Infrastructure.csproj", "backend/src/LoopWorth.Infrastructure/"]

# Restore packages
RUN dotnet restore "backend/src/LoopWorth.Api/LoopWorth.Api.csproj"

# Copy full source tree and publish
COPY backend/src/ ./backend/src/
WORKDIR "/src/backend/src/LoopWorth.Api"
RUN dotnet publish "LoopWorth.Api.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Runtime Stage
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app
COPY --from=build /app/publish .

# Render exposes PORT dynamically; ASP.NET Core 8 binds to 8080 by default
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080

ENTRYPOINT ["dotnet", "LoopWorth.Api.dll"]

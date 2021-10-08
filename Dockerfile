FROM mcr.microsoft.com/dotnet/sdk:3.1 AS build-env
ARG version=1.0.0
WORKDIR /app
EXPOSE 80
EXPOSE 443
EXPOSE 5000
EXPOSE 5001
ARG BUILD_CONFIGURATION=Debug
ENV ASPNETCORE_ENVIRONMENT=Development
ENV DOTNET_USE_POLLING_FILE_WATCHER=true  
ENV ASPNETCORE_URLS=http://+:5000

# Copy csproj and restore as distinct layers
COPY ./ /app
RUN ls -la /app/*

# restore for all projects
RUN dotnet restore /app/CodeCoverageOnIntegrationTest.sln


RUN dotnet clean /app/CodeCoverageOnIntegrationTest.sln /p:Configuration=Debug
RUN dotnet build /app/CodeCoverageOnIntegrationTest.sln /p:Configuration=Debug

RUN dotnet tool install JetBrains.dotCover.GlobalTool -g

ENTRYPOINT ["/bin/bash", "/app/SampleApi/bin/Debug/netcoreapp3.1/run.sh"]
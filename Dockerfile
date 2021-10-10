FROM mcr.microsoft.com/dotnet/sdk:3.1 AS build-env
WORKDIR /app
EXPOSE 5000 5001
ARG BUILD_CONFIGURATION=Debug
ENV ASPNETCORE_ENVIRONMENT=Development
ENV DOTNET_USE_POLLING_FILE_WATCHER=true  
ENV ASPNETCORE_URLS=http://+:5000

# Copy csproj and restore as distinct layers
COPY ./ /app

# restore for all projects
RUN dotnet restore /app/CodeCoverageOnIntegrationTest.sln

# clean the project to avoid any weird stuff that we might have copied
RUN dotnet clean /app/CodeCoverageOnIntegrationTest.sln /p:Configuration=Debug
# build the project
RUN dotnet build /app/CodeCoverageOnIntegrationTest.sln /p:Configuration=Debug

#install jetbrains command line code ceverage tool
RUN dotnet tool install JetBrains.dotCover.GlobalTool -g

#create a  development certificate and trust it
RUN dotnet dev-certs https

# run the script
ENTRYPOINT ["/bin/bash", "/app/SampleApi/bin/Debug/netcoreapp3.1/run.sh"]
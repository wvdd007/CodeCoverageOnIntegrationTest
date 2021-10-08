echo "tools -------------------------------"
ls /root/.dotnet/tools

echo "bin -------------------------------"
ls /bin

dotnet dev-certs https
dotnet dev-certs https --trust

echo "cd -------------------------------"
cd /app/SampleApi/bin/Debug/netcoreapp3.1/

echo "cover -------------------------------"
/root/.dotnet/tools/dotnet-dotcover --dcReportType=DetailedXML SampleApi.dll

echo "cd -------------------------------"
ls

cp dotCover.Output.xml /coverage/dotCover.Output.xml

echo "reportgen -------------------------------"
dotnet /app/Packages/reportgenerator/4.8.13/tools/netcoreapp3.0/ReportGenerator.dll -reporttypes:SonarQube -reports:dotCover.Output.xml -targetdir:/coverage

echo "-------------------------------"
#dotnet /app/Packages/reportgenerator/4.8.13/tools/netcoreapp3.0/ReportGenerator.dll -reporttypes SonarQube dotCover.Output.dcvr
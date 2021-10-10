# trust developer certificates
dotnet dev-certs https --trust

#move to the service directory
cd /app/SampleApi/bin/Debug/netcoreapp3.1/

# cover the application.  This is blocking until the application exits
/root/.dotnet/tools/dotnet-dotcover --dcReportType=DetailedXML SampleApi.dll

# copy the coverage file to the "coverage" volume
cp dotCover.Output.xml /coverage/dotCover.Output.xml

# use the reportgenerator tool to convert it to any format you like.  In this case we convert to SonarQube format.
# again we place the output in the "coverage" volume
dotnet /app/Packages/reportgenerator/4.8.13/tools/netcoreapp3.0/ReportGenerator.dll -reporttypes:SonarQube -reports:dotCover.Output.xml -targetdir:/coverage


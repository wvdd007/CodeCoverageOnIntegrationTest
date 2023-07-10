# Unit tests.
Not more than 15 years ago I was writing software without unit tests. The environment was a little arcane and there were simply no unit test frameworks for my programming environment. Then some new team members arrived and they complained about the absence of automated testing. Of course, I knew about automated unit testing and the benefits of it but I never seemed to get myself to it. So little by little we started adding unit tests to our project. Since then I never went back. I am a huge fan of the practice and I could not imagine programming without them anymore. 
I switched to another company and little by little I convinced teams to write unit tests (those who did not  yet do it, that is). Now we were in a position to enforce writing unit tests. Inspired by SalesForce practices,(they require 75% coverage and passing unit tests) we decided to enforce code coverage.  Our company was already using SonarQube to have automatic metrics so together we adapted our build servers to put this quality gate in place (for new projects).

# Integration tests.
A colleague of mine had some objections.  He pointed out that code coverage is a wrong metric (it is).  It's easy to write meaningless unit tests to increase the code coverage (not to mention adding ´[ExcludeFromCodeCoverage]´ attributes).  To some point I agree with him but it's also true that 0 code coverage has it's drawbacks.  He pointed out that integration tests and end-to end tests are really more important than unit tests.  
So I started to look for a way to measure code coverage for integration tests.  The difference with a normal unit test is that integration tests normally require some services to be running out there.  The tests rely on something infrastructural like a service or a database to be present.  It's useless to know whether all your integration tests are covered.  What you really want is to see the coverage in your "system under test" (SUT).  For the case of this example, the SUT is a .Net core REST webservice.  What we really want is to see how much of the code in the service is actually being tested.
There are a few frameworks and tools out there that let you do this.  What's important is that they generally instrument your code and run your executable while being watched by "the code coverage tool".  While you could actually set this up in a non-production environment, measuring the code coverage there, it actually makes more sense to have some specially prepared instance of your web service for this.  This avoids several problems.  
- The first problem is that it will actually measure what you want, which is the percentage of code covered by your integration tests.  You don't want a tester's tests to interfere with these results.  
- The second problem, related to the first, is that you really want to set up your system, run whatever integration tests you have, and the immediately get back the results.

This is a long story to say that it actually makes sense to have the sut run in a container.  You spin up the container, run the tests and then finally collect the code coverage results of your test.

# Breaking up the problem.
So the problem boils down to these things :

1. set up your webservice to run in a container under some code coverage tool.
1. run your integration tests against the container.
1. stop the service gracefully.
1. collect the data from the code coverage into some format your reporting tool likes.

# Step1: Set up your webservice to run in a container under some code coverage tool
I started by creating a standard .net REST service.  The service is not important for this purpose so I just took the standard "weatherforecast" service, that comes out of the box when you create a new one in Visual studio.
You need to make some small tweaks to your .csproj file of the service and anything you want covered. 

``` xml
  <PropertyGroup>
    <TargetFramework>netcoreapp3.1</TargetFramework>
    <GenerateRuntimeConfigurationFiles>true</GenerateRuntimeConfigurationFiles>
  </PropertyGroup>
<PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|AnyCPU'">
    <DebugType>full</DebugType>
    <DebugSymbols>true</DebugSymbols>
  </PropertyGroup>
``` 

We also make sure our script is deployed to the output directory (there are multiple ways to do this but we just put it in the cproj file)
``` xml
  <ItemGroup Condition="'$(Configuration)|$(Platform)'=='Debug|AnyCPU'">
    <None Update="run.sh">
      <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
    </None>
  </ItemGroup>

``` 

## Choosing a way to activate code coverage.
Then I had to choose a tool to collect code coverage metrics.  There are several tools out there that can help you with it.  There is the "manual" way of doing it with tools like.  
I had a look at the visual studio profiling tools (which can also do code coverage).  I actually got this working but it felt a bit complicated.  Also, the steps are (more or less):  Instrument the assemblies, start profiling (with code coverage mode), run the service, stop profiling. I felt it difficult to see when I was "done" because I probably had to wait for a process to die.
I also had a very diagonal look at `coverlet`.  But i skipped that for no other reason than that I had the impression that this was more about "classical" unit test coverage.  It's probably possible but I didn't see an easy way to collect coverage from something else than running unit tests.
So I finally decided to use Jetbrains `DotCover` for the task.  I use this tool myself (integrated in Visual Studio) and I generally like the Jetbrains tools.  To run the tool is actually quite easy :

``` sh
dotnet tool install JetBrains.dotCover.GlobalTool -g
``` 

Once you have done that, you can use the dotnet-dotcover command to run the code coverage.  Since this will be running inside a linux container, the command would look like this:

``` sh
/root/.dotnet/tools/dotnet-dotcover --dcReportType=DetailedXML SampleApi.dll
``` 

## Dockerfile
So I created a docker file that wraps it all up: 
``` Dockerfile
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

#install jetbrains command line code coverage tool
RUN dotnet tool install JetBrains.dotCover.GlobalTool -g
RUN dotnet tool install dotnet-reportgenerator-globaltool -g 

#create a  development certificate and trust it
RUN dotnet dev-certs https

# run the script
ENTRYPOINT ["/bin/bash", "/app/SampleApi/bin/Debug/netcoreapp3.1/run.sh"]
``` 

There are several points to notice :
- We use `mcr.microsoft.com/dotnet/sdk:3.1` as a base container.  This makes sure we have all the dotnet tools available in our container.  Since this container is really a throw away thing we don't care about the size of it.  There are probably some optimizations possible (ex if you have many such tests it could pay of to create a base container that contains all the project-agnostic stuff)
- we copy the entire source directory into the dockerfile.  Again, we don't really care about sizes.  Because of this we do a clean of the project before we build it.  This is all rather unimportant.
- we install the `JetBrains.dotCover.GlobalTool` tool as a global tool to be able to call it in the container.
- the entrypoint is a ´bash´ script.  The reason is that we want to do multiple things : collect, reformat and publish.

The script looks like this :
``` sh
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

/root/.dotnet/tools/reportgenerator -reporttypes:TeamCitySummary -reports:dotCover.Output.xml -targetdir:/coverage
/root/.dotnet/tools/reportgenerator -reporttypes:SonarQube -reports:dotCover.Output.xml -targetdir:/coverage
/root/.dotnet/tools/reportgenerator -reporttypes:Html -reports:dotCover.Output.xml -targetdir:/coverage

``` 
- We use the [reportgenerator](https://github.com/danielpalme/ReportGenerator) to convert the dotcover format to whatever we like.  Have a look at the tool to see the supported formats (Badges, Clover, Cobertura, CsvSummary, MarkdownSummary, Html, HtmlChart, HtmlInline, HtmlInline_AzurePipelines, htmlInline_AzurePipelines_Dark, HtmlSummary, JsonSummary, Latex, LatexSummary, lcov, MHtml, PngChart, SonarQube, TeamCitySummary, TextSummary, Xml, XmlSummary)

I created the dockerfile on my local machine using :

``` sh
docker build . -t coverage-demo
```

Then I could run it locally using something like :
``` sh
docker run -it -p 80:80 coverage-demo
```

![image.png](https://cdn.hashnode.com/res/hashnode/image/upload/v1633868864349/LoaoXYyg4.png)


Of course you could also deploy it in a kubernetes cluster or somewhere else.  That's an important choice but not for the sake of this article.

# Step2: run your integration tests against the container
Then we need some integration tests
``` c#
 [Fact()]
        public async Task Test1()
        {
            var client = new HttpClient
            {
                BaseAddress = new Uri("http://localhost/")
            };
            HttpResponseMessage response = await client.GetAsync("weatherforecast");
            if (response.IsSuccessStatusCode)
            {
                var streamTask = await response.Content.ReadAsStreamAsync();
                var forecasts = await JsonSerializer.DeserializeAsync<List<WeatherForecast>>(streamTask);
                foreach (var fc in forecasts)
                {
                    _output.WriteLine($"Date:{fc.Date}, temp: {fc.TemperatureC}, summary:{fc.Summary}");
                }
            }
        }
``` 

The uri we call from our test should of course match our running container.  I use localhost on my local machine but it you would deploy this in kubernetes, the address would probably be different.  Here we just do a simple api call but you can write it as simple or as complicated as you want.
You can then run your integration tests from your local machine with any test runner you like.  You could also run them from your ci pipeline.  What matters is that the machine has access to your running container.

I also marked my integration tests with a xUnit Trait to allow running only the integration tests when needed.

``` c#
[assembly: AssemblyTrait("TestType","IntegrationTests")]
``` 

That allows me to run these tests with:

``` powershell
dotnet test --filter TestType=IntegrationTests

``` 

![image.png](https://cdn.hashnode.com/res/hashnode/image/upload/v1633869031979/RS7pjh-PN.png)

Since these tests will actually call the service in the container (the SUT), they will cause dotcover to collect coverage data inside the container.


# Step3 : stop the service gracefully
There is still one small but annoying problem.  After our integration tests have been done, the service is still running.  After all, that is what services are designed to do : they run forever.   For code coverage to be properly collected, it is important that we do a clean  shutdown of the service.  Maybe there are better ways to do this but here is what I came up with.  A separated controller on the api that will stop the application when called.  Needless to say, you want this to be only available in the configuration used for these tests (hence the ´#ifdef´ statements):
``` c#
#if DEBUG
using Microsoft.AspNetCore.Mvc;

namespace SampleApi.Controllers
{
    public class StopController : Controller
    {
        private readonly Microsoft.Extensions.Hosting.IHostApplicationLifetime _applicationLifetime;

        public StopController(Microsoft.Extensions.Hosting.IHostApplicationLifetime applicationLifetime)
        {
            _applicationLifetime = applicationLifetime;
        }

        [HttpGet]
        [Route("/stop")]
        public void Stop()
        {
            _applicationLifetime.StopApplication();
        }
    }
}
#endif
``` 

´StopApplication´ is the clean way to stop a .net core application.


Then all we need to do to stop the code coverage collection is call something like :
``` sh
curl http:// localhost/stop
```

This should be called after our integration tests have run.  It will then cause the dotcover process in the container to stop and the rest of the ´bash´ script will be executed.

# Step4 : collect the data from the code coverage into some format your reporting tool likes
Note that inside or shell script we have the following lines :
``` sh
# use the reportgenerator tool to convert it to any format you like.  In this case we convert to SonarQube format.
# again we place the output in the "coverage" volume
/root/.dotnet/tools/reportgenerator -reporttypes:TeamCitySummary -reports:dotCover.Output.xml -targetdir:/coverage
/root/.dotnet/tools/reportgenerator -reporttypes:SonarQube -reports:dotCover.Output.xml -targetdir:/coverage
/root/.dotnet/tools/reportgenerator -reporttypes:Html -reports:dotCover.Output.xml -targetdir:/coverage
``` 

The reportgenerator tool handles a lot of data formats  and it is up to you to choose which one you need.
We have one last thing to do : make sure we get the reports out of the container.  To make sure the data survives the exit of our container, I save it into a docker volume (depending on your needs that might use a different driver than mine and save it p.e. in azure storage):
``` powershell
 docker volume create coverage
 ```

``` powershell
docker run -it -p 80:80  -v coverage:/coverage coverage-demo
 ```

to get the coverage data later you can use the following [trick](https://stackoverflow.com/questions/37468788/what-is-the-right-way-to-add-data-to-an-existing-named-volume-in-docker) :
``` powershell
docker run -v coverage:/coverage --name helper busybox true
docker cp helper:/coverage coverage
docker rm helper
``` 

There are probably other and better techniques but this one works for me.

code is available on [GitHub](https://github.com/wvdd007/CodeCoverageOnIntegrationTest).

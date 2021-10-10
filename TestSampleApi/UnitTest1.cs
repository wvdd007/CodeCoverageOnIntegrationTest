using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Text.Json;
using System.Threading.Tasks;
using SampleApi.Contracts;
using Xunit;
using Xunit.Abstractions;

// Need to turn off test parallelization so we can validate the run order
[assembly: CollectionBehavior(DisableTestParallelization = true)]

namespace TestSampleApi
{
    public class UnitTest1
    {
        private readonly ITestOutputHelper _output;

        public UnitTest1(ITestOutputHelper output)
        {
            _output = output;
        }

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

      
    }

}

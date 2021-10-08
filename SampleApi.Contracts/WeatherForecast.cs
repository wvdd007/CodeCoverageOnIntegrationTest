using System;
using System.Text.Json.Serialization;

namespace SampleApi.Contracts
{
    public class WeatherForecast
    {
        [JsonPropertyName("date")]
        public DateTime Date { get; set; }

        [JsonPropertyName("temperatureC")]
        public int TemperatureC { get; set; }


        [JsonPropertyName("summary")]
        public string Summary { get; set; }
    }
}

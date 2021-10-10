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
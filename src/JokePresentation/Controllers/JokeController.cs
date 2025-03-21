namespace JokePresentation.Controllers
{
    using System.Net.Http;
    using System.Threading.Tasks;
    using Microsoft.AspNetCore.Mvc;

    public class JokeController(IHttpClientFactory httpClientFactory, IConfiguration configuration) : Controller
    {
        private readonly IHttpClientFactory _httpClientFactory = httpClientFactory;
        private readonly string _jokeProviderUrl = configuration["JokeProvider:Url"]
                ?? throw new ArgumentException("JokeProvider:Url is required");

        [ResponseCache(Duration = 5, Location = ResponseCacheLocation.Client)]
        public async Task<JokeResponse> Index()
        {
            JokeResponse jokeResponse;

            try
            {
                var requestUri = _jokeProviderUrl;
                if (requestUri.EndsWith("/"))
                {
                    requestUri = requestUri[..^1];
                }
                requestUri += "/api";

                var client = _httpClientFactory.CreateClient();
                var response = await client.GetStringAsync(requestUri);
                jokeResponse = System.Text.Json.JsonSerializer.Deserialize<JokeResponse>(response);
                if (jokeResponse is null)
                    throw new Exception("Failed to deserialize joke response");
            }
            catch (Exception ex)
            {
                jokeResponse = new JokeResponse("Failed to get joke", System.Environment.MachineName, ex.Message);
            }

            return jokeResponse;
        }

        public record JokeResponse(string joke, string server, string error);
    }
}

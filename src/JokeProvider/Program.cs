using System.Text.Json;

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddHealthChecks();

var app = builder.Build();
app.UseSwagger();
app.UseSwaggerUI();

app.MapGet("/", () =>
{
    return Results.Ok("JokeProvider API v1.0");
});

app.MapGet("/api", () =>
{
    var jokesJson = File.ReadAllText("jokes.json");
    var jokes = JsonSerializer.Deserialize<string[]>(jokesJson)
                    ?.Select(joke => joke)
                    ?.ToArray();
    var randomJoke = jokes == null ? null : jokes[new Random().Next(jokes.Length)];
    randomJoke ??= "Null não é piada.";
    var machineName = Environment.MachineName;

    return Results.Ok(new { joke = randomJoke, server = machineName });
});

app.MapHealthChecks("/health");

app.Run();
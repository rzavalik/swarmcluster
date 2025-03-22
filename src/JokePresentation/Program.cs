namespace JokePresentation;

using Microsoft.AspNetCore.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

public class Program
{
    public static void Main(string[] args)
    {
        var builder = WebApplication.CreateBuilder(args);

        // Add environment variables and other services
        builder.Configuration
            .AddJsonFile("appsettings.json", optional: true, reloadOnChange: true)
            .AddEnvironmentVariables();
        builder.Services.AddControllersWithViews();
        builder.Services.AddHttpClient();
        builder.Services.AddHealthChecks();

        var app = builder.Build();

        // Middleware for error handling and HSTS (HTTP Strict Transport Security)
        if (!app.Environment.IsDevelopment())
        {
            app.UseExceptionHandler("/Home/Error");
            app.UseHsts();
        }

        // Middleware for HTTP redirection and routing
        app.UseHttpsRedirection();
        app.UseRouting();
        app.UseAuthorization();

        // Add static assets (e.g., CSS, JS)
        app.MapStaticAssets();

        // Define the route for MVC Controllers
        app.MapControllerRoute(
            name: "default",
            pattern: "{controller=Home}/{action=Index}/{id?}")
            .WithStaticAssets();

        // Define health route
        app.MapHealthChecks("/health");

        // Run the application
        app.Run();
    }
}

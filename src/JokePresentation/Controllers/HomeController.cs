namespace JokePresentation.Controllers 
{
    using System.Diagnostics;
    using JokePresentation.Models;
    using Microsoft.AspNetCore.Mvc;

    public class HomeController(ILogger<HomeController> logger) : Controller
    {
        [ResponseCache(Duration = 30, Location = ResponseCacheLocation.Client)]
        public IActionResult Index()
        {
            return View();
        }

        [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
        public IActionResult Error()
        {
            return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
        }
    }
}
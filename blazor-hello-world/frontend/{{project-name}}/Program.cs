using Microsoft.AspNetCore.Components.WebAssembly.Hosting;
using {{ project-name | pascal_case }}.Services;

var builder = WebAssemblyHostBuilder.CreateDefault(args);
builder.RootComponents.Add<{{ project-name | pascal_case }}.App>("#app");

builder.Services.AddScoped<IcpAgentService>();

await builder.Build().RunAsync();

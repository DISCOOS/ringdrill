// Interactive API reference at /api/docs (see netlify.toml). Serves Swagger UI
// from a pinned CDN and points it at /api/openapi.json (relative, so it works
// on both ringdrill.app via the apex proxy and api.ringdrill.app directly).
const SWAGGER_VERSION = "5.17.14";

const HTML = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta name="robots" content="noindex" />
  <title>RingDrill API</title>
  <link rel="icon" type="image/png" href="https://ringdrill.app/brand/logo.png" />
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/swagger-ui/${SWAGGER_VERSION}/swagger-ui.min.css" />
  <style>body { margin: 0; } .topbar { display: none; }</style>
</head>
<body>
  <div id="swagger-ui"></div>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/swagger-ui/${SWAGGER_VERSION}/swagger-ui-bundle.min.js" crossorigin></script>
  <script>
    window.addEventListener("load", function () {
      window.ui = SwaggerUIBundle({
        url: "/api/openapi.json",
        dom_id: "#swagger-ui",
        deepLinking: true,
        tryItOutEnabled: true,
      });
    });
  </script>
</body>
</html>
`;

export default async function () {
    return new Response(HTML, {
        status: 200,
        headers: {
            "content-type": "text/html; charset=utf-8",
            "cache-control": "public, max-age=300",
        },
    });
}

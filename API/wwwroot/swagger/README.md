# Swagger UI bundle override

`swagger-ui-bundle.js` is the upstream `swagger-ui-dist` 5.35.1 bundle, vendored to replace the older bundle embedded by Swashbuckle 10.2.1. It contains DOMPurify 3.4.17 and is served before the embedded Swagger asset by `UseStaticFiles`.

The bundle's SHA-256 is `D0E0BEE93732408C91FBAD05CB0C2812E9AD37E94D12799C5503A9FE7AFA2B82`. Its adjacent license file is retained from the upstream package.

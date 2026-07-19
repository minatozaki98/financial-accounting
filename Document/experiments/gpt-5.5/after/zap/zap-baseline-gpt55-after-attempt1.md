# ZAP Scanning Report

ZAP by [Checkmarx](https://checkmarx.com/).


## Summary of Alerts

| Risk Level | Number of Alerts |
| --- | --- |
| High | 0 |
| Medium | 2 |
| Low | 1 |
| Informational | 3 |




## Insights

| Level | Reason | Site | Description | Statistic |
| --- | --- | --- | --- | --- |
| Low | Warning |  | ZAP warnings logged - see the zap.log file for details | 2    |
| Info | Informational | http://host.docker.internal:5296 | Percentage of responses with status code 2xx | 71 % |
| Info | Informational | http://host.docker.internal:5296 | Percentage of responses with status code 3xx | 14 % |
| Info | Informational | http://host.docker.internal:5296 | Percentage of responses with status code 4xx | 14 % |
| Info | Informational | http://host.docker.internal:5296 | Percentage of endpoints with content type application/javascript | 8 % |
| Info | Informational | http://host.docker.internal:5296 | Percentage of endpoints with content type image/png | 16 % |
| Info | Informational | http://host.docker.internal:5296 | Percentage of endpoints with content type text/css | 16 % |
| Info | Informational | http://host.docker.internal:5296 | Percentage of endpoints with content type text/html | 25 % |
| Info | Informational | http://host.docker.internal:5296 | Percentage of endpoints with content type text/javascript | 16 % |
| Info | Informational | http://host.docker.internal:5296 | Percentage of endpoints with method GET | 100 % |
| Info | Informational | http://host.docker.internal:5296 | Count of total endpoints | 12    |







## Alerts

| Name | Risk Level | Number of Instances |
| --- | --- | --- |
| CSP: Failure to Define Directive with No Fallback | Medium | 3 |
| Vulnerable JS Library | Medium | 1 |
| Timestamp Disclosure - Unix | Low | Systemic |
| Modern Web Application | Informational | 3 |
| Non-Storable Content | Informational | 1 |
| Storable and Cacheable Content | Informational | Systemic |




## Alert Detail



### [ CSP: Failure to Define Directive with No Fallback ](https://www.zaproxy.org/docs/alerts/10055/)



##### Medium (High)

### Description

The Content Security Policy fails to define one of the directives that has no fallback. Missing/excluding them is the same as allowing anything.

* URL: http://host.docker.internal:5296/
  * Node Name: `http://host.docker.internal:5296/`
  * Method: `GET`
  * Parameter: `Content-Security-Policy`
  * Attack: ``
  * Evidence: `default-src 'self'; frame-ancestors 'none'; base-uri 'self'; object-src 'none';`
  * Other Info: `The directive(s): form-action is/are among the directives that do not fallback to default-src.`
* URL: http://host.docker.internal:5296/swagger
  * Node Name: `http://host.docker.internal:5296/swagger`
  * Method: `GET`
  * Parameter: `Content-Security-Policy`
  * Attack: ``
  * Evidence: `default-src 'self'; frame-ancestors 'none'; base-uri 'self'; object-src 'none';`
  * Other Info: `The directive(s): form-action is/are among the directives that do not fallback to default-src.`
* URL: http://host.docker.internal:5296/swagger/index.html
  * Node Name: `http://host.docker.internal:5296/swagger/index.html`
  * Method: `GET`
  * Parameter: `Content-Security-Policy`
  * Attack: ``
  * Evidence: `default-src 'self'; frame-ancestors 'none'; base-uri 'self'; object-src 'none';`
  * Other Info: `The directive(s): form-action is/are among the directives that do not fallback to default-src.`


Instances: 3

### Solution

Ensure that your web server, application server, load balancer, etc. is properly configured to set the Content-Security-Policy header.

### Reference


* [ https://www.w3.org/TR/CSP/ ](https://www.w3.org/TR/CSP/)
* [ https://caniuse.com/#search=content+security+policy ](https://caniuse.com/#search=content+security+policy)
* [ https://content-security-policy.com/ ](https://content-security-policy.com/)
* [ https://github.com/HtmlUnit/htmlunit-csp ](https://github.com/HtmlUnit/htmlunit-csp)
* [ https://web.dev/articles/csp#resource-options ](https://web.dev/articles/csp#resource-options)


#### CWE Id: [ 693 ](https://cwe.mitre.org/data/definitions/693.html)


#### WASC Id: 15

#### Source ID: 3

### [ Vulnerable JS Library ](https://www.zaproxy.org/docs/alerts/10003/)



##### Medium (Medium)

### Description

The identified library appears to be vulnerable.

* URL: http://host.docker.internal:5296/swagger/swagger-ui-bundle.js
  * Node Name: `http://host.docker.internal:5296/swagger/swagger-ui-bundle.js`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `DOMPurify.version="3.1.4"`
  * Other Info: `The identified library DOMPurify, version 3.1.4 is vulnerable.
CVE-2025-26791
CVE-2026-41239
CVE-2026-41238
CVE-2026-0540
CVE-2026-41240
CVE-2026-49978
CVE-2025-15599
CVE-2026-49458
CVE-2026-49459
https://www.vulncheck.com/advisories/dompurify-xss-via-textarea-rawtext-bypass-in-safeforxml
https://www.vulncheck.com/advisories/dompurify-xss-via-missing-rawtext-elements-in-safeforxml
https://github.com/cure53/DOMPurify/security/advisories/GHSA-gvmj-g25r-r7wr
https://github.com/cure53/DOMPurify/commit/d18ffcb554e0001748865da03ac75dd7829f0f02
https://github.com/cure53/DOMPurify/security/advisories/GHSA-cj63-jhhr-wcxv
https://www.vulncheck.com/advisories/dompurify-xss-via-missing-rawtext-elements-in-safe-for-xml
https://github.com/cure53/DOMPurify/commit/fca0a938b4261ddc9c0293a289935a9029c049f5
https://github.com/cure53/DOMPurify/security/advisories/GHSA-39q2-94rc-95cp
https://github.com/cure53/DOMPurify/commit/c861f5a83fb8d90800f1680f855fee551161ac2b
https://github.com/cure53/DOMPurify/security/advisories/GHSA-r47g-fvhr-h676
https://github.com/cure53/DOMPurify/security/advisories/GHSA-h7mw-gpvr-xq4m
https://github.com/cure53/DOMPurify/security/advisories/GHSA-cjmm-f4jc-qw8r
https://github.com/cure53/DOMPurify/security/advisories/GHSA-cmwh-pvxp-8882
https://github.com/advisories/GHSA-vhxf-7vqr-mrjg
https://nvd.nist.gov/vuln/detail/CVE-2025-26791
https://ensy.zip/posts/dompurify-323-bypass
https://nsysean.github.io/posts/dompurify-323-bypass
https://github.com/cure53/DOMPurify/security/advisories/GHSA-rp9w-3fw7-7cwq
https://github.com/cure53/DOMPurify/releases/tag/3.2.4
https://github.com/cure53/DOMPurify/releases/tag/3.3.2
https://github.com/cure53/DOMPurify/releases/tag/3.4.0
https://github.com/cure53/DOMPurify/security/advisories/GHSA-vxr8-fq34-vvx9
https://github.com/cure53/DOMPurify/security/advisories/GHSA-v9jr-rg53-9pgp
https://www.vulncheck.com/advisories/dompurify-xss-via-textarea-rawtext-bypass-in-safe-for-xml
https://github.com/cure53/DOMPurify/security/advisories/GHSA-x4vx-rjvf-j5p4
https://github.com/cure53/DOMPurify/security/advisories/GHSA-hpcv-96wg-7vj8
https://github.com/cure53/DOMPurify/security/advisories/GHSA-h8r8-wccr-v5f2
https://github.com/cure53/DOMPurify
https://github.com/cure53/DOMPurify/security/advisories/GHSA-crv5-9vww-q3g8
https://github.com/cure53/DOMPurify/security/advisories/GHSA-76mc-f452-cxcm
`


Instances: 1

### Solution

Upgrade to the latest version of the affected library.

### Reference


* [ https://owasp.org/Top10/A06_2021-Vulnerable_and_Outdated_Components/ ](https://owasp.org/Top10/A06_2021-Vulnerable_and_Outdated_Components/)


#### CWE Id: [ 1395 ](https://cwe.mitre.org/data/definitions/1395.html)


#### Source ID: 3

### [ Timestamp Disclosure - Unix ](https://www.zaproxy.org/docs/alerts/10096/)



##### Low (Low)

### Description

A timestamp was disclosed by the application/web server. - Unix

* URL: http://host.docker.internal:5296/swagger/swagger-ui-standalone-preset.js
  * Node Name: `http://host.docker.internal:5296/swagger/swagger-ui-standalone-preset.js`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `1518500249`
  * Other Info: `1518500249, which evaluates to: 2018-02-13 05:37:29.`
* URL: http://host.docker.internal:5296/swagger/swagger-ui-standalone-preset.js
  * Node Name: `http://host.docker.internal:5296/swagger/swagger-ui-standalone-preset.js`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `1732584193`
  * Other Info: `1732584193, which evaluates to: 2024-11-26 01:23:13.`
* URL: http://host.docker.internal:5296/swagger/swagger-ui-standalone-preset.js
  * Node Name: `http://host.docker.internal:5296/swagger/swagger-ui-standalone-preset.js`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `1750603025`
  * Other Info: `1750603025, which evaluates to: 2025-06-22 14:37:05.`
* URL: http://host.docker.internal:5296/swagger/swagger-ui-standalone-preset.js
  * Node Name: `http://host.docker.internal:5296/swagger/swagger-ui-standalone-preset.js`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `1859775393`
  * Other Info: `1859775393, which evaluates to: 2028-12-07 04:16:33.`
* URL: http://host.docker.internal:5296/swagger/swagger-ui-standalone-preset.js
  * Node Name: `http://host.docker.internal:5296/swagger/swagger-ui-standalone-preset.js`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `1894007588`
  * Other Info: `1894007588, which evaluates to: 2030-01-07 09:13:08.`

Instances: Systemic


### Solution

Manually confirm that the timestamp data is not sensitive, and that the data cannot be aggregated to disclose exploitable patterns.

### Reference


* [ https://cwe.mitre.org/data/definitions/200.html ](https://cwe.mitre.org/data/definitions/200.html)


#### CWE Id: [ 497 ](https://cwe.mitre.org/data/definitions/497.html)


#### WASC Id: 13

#### Source ID: 3

### [ Modern Web Application ](https://www.zaproxy.org/docs/alerts/10109/)



##### Informational (Medium)

### Description

The application appears to be a modern web application. If you need to explore it automatically then the Client Spider may well be more effective than the standard one.

* URL: http://host.docker.internal:5296/
  * Node Name: `http://host.docker.internal:5296/`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `<script src="./swagger-ui-bundle.js" charset="utf-8"></script>`
  * Other Info: `No links have been found while there are scripts, which is an indication that this is a modern web application.`
* URL: http://host.docker.internal:5296/swagger
  * Node Name: `http://host.docker.internal:5296/swagger`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `<script src="./swagger-ui-bundle.js" charset="utf-8"></script>`
  * Other Info: `No links have been found while there are scripts, which is an indication that this is a modern web application.`
* URL: http://host.docker.internal:5296/swagger/index.html
  * Node Name: `http://host.docker.internal:5296/swagger/index.html`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `<script src="./swagger-ui-bundle.js" charset="utf-8"></script>`
  * Other Info: `No links have been found while there are scripts, which is an indication that this is a modern web application.`


Instances: 3

### Solution

This is an informational alert and so no changes are required.

### Reference




#### Source ID: 3

### [ Non-Storable Content ](https://www.zaproxy.org/docs/alerts/10049/)



##### Informational (Medium)

### Description

The response contents are not storable by caching components such as proxy servers. If the response does not contain sensitive, personal or user-specific information, it may benefit from being stored and cached, to improve performance.

* URL: http://host.docker.internal:5296/
  * Node Name: `http://host.docker.internal:5296/`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `302`
  * Other Info: ``


Instances: 1

### Solution

The content may be marked as storable by ensuring that the following conditions are satisfied:
The request method must be understood by the cache and defined as being cacheable ("GET", "HEAD", and "POST" are currently defined as cacheable)
The response status code must be understood by the cache (one of the 1XX, 2XX, 3XX, 4XX, or 5XX response classes are generally understood)
The "no-store" cache directive must not appear in the request or response header fields
For caching by "shared" caches such as "proxy" caches, the "private" response directive must not appear in the response
For caching by "shared" caches such as "proxy" caches, the "Authorization" header field must not appear in the request, unless the response explicitly allows it (using one of the "must-revalidate", "public", or "s-maxage" Cache-Control response directives)
In addition to the conditions above, at least one of the following conditions must also be satisfied by the response:
It must contain an "Expires" header field
It must contain a "max-age" response directive
For "shared" caches such as "proxy" caches, it must contain a "s-maxage" response directive
It must contain a "Cache Control Extension" that allows it to be cached
It must have a status code that is defined as cacheable by default (200, 203, 204, 206, 300, 301, 404, 405, 410, 414, 501).

### Reference


* [ https://datatracker.ietf.org/doc/html/rfc7234 ](https://datatracker.ietf.org/doc/html/rfc7234)
* [ https://datatracker.ietf.org/doc/html/rfc7231 ](https://datatracker.ietf.org/doc/html/rfc7231)
* [ https://www.w3.org/Protocols/rfc2616/rfc2616-sec13.html ](https://www.w3.org/Protocols/rfc2616/rfc2616-sec13.html)


#### CWE Id: [ 524 ](https://cwe.mitre.org/data/definitions/524.html)


#### WASC Id: 13

#### Source ID: 3

### [ Storable and Cacheable Content ](https://www.zaproxy.org/docs/alerts/10049/)



##### Informational (Medium)

### Description

The response contents are storable by caching components such as proxy servers, and may be retrieved directly from the cache, rather than from the origin server by the caching servers, in response to similar requests from other users. If the response data is sensitive, personal or user-specific, this may result in sensitive information being leaked. In some cases, this may even result in a user gaining complete control of the session of another user, depending on the configuration of the caching components in use in their environment. This is primarily an issue where "shared" caching servers such as "proxy" caches are configured on the local network. This configuration is typically found in corporate or educational environments, for instance.

* URL: http://host.docker.internal:5296/robots.txt
  * Node Name: `http://host.docker.internal:5296/robots.txt`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: ``
  * Other Info: `In the absence of an explicitly specified caching lifetime directive in the response, a liberal lifetime heuristic of 1 year was assumed. This is permitted by rfc7234.`
* URL: http://host.docker.internal:5296/sitemap.xml
  * Node Name: `http://host.docker.internal:5296/sitemap.xml`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: ``
  * Other Info: `In the absence of an explicitly specified caching lifetime directive in the response, a liberal lifetime heuristic of 1 year was assumed. This is permitted by rfc7234.`
* URL: http://host.docker.internal:5296/swagger/favicon-16x16.png
  * Node Name: `http://host.docker.internal:5296/swagger/favicon-16x16.png`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: ``
  * Other Info: `In the absence of an explicitly specified caching lifetime directive in the response, a liberal lifetime heuristic of 1 year was assumed. This is permitted by rfc7234.`
* URL: http://host.docker.internal:5296/swagger/favicon-32x32.png
  * Node Name: `http://host.docker.internal:5296/swagger/favicon-32x32.png`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: ``
  * Other Info: `In the absence of an explicitly specified caching lifetime directive in the response, a liberal lifetime heuristic of 1 year was assumed. This is permitted by rfc7234.`
* URL: http://host.docker.internal:5296/swagger/index.css
  * Node Name: `http://host.docker.internal:5296/swagger/index.css`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: ``
  * Other Info: `In the absence of an explicitly specified caching lifetime directive in the response, a liberal lifetime heuristic of 1 year was assumed. This is permitted by rfc7234.`

Instances: Systemic


### Solution

Validate that the response does not contain sensitive, personal or user-specific information. If it does, consider the use of the following HTTP response headers, to limit, or prevent the content being stored and retrieved from the cache by another user:
Cache-Control: no-cache, no-store, must-revalidate, private
Pragma: no-cache
Expires: 0
This configuration directs both HTTP 1.0 and HTTP 1.1 compliant caching servers to not store the response, and to not retrieve the response (without validation) from the cache, in response to a similar request.

### Reference


* [ https://datatracker.ietf.org/doc/html/rfc7234 ](https://datatracker.ietf.org/doc/html/rfc7234)
* [ https://datatracker.ietf.org/doc/html/rfc7231 ](https://datatracker.ietf.org/doc/html/rfc7231)
* [ https://www.w3.org/Protocols/rfc2616/rfc2616-sec13.html ](https://www.w3.org/Protocols/rfc2616/rfc2616-sec13.html)


#### CWE Id: [ 524 ](https://cwe.mitre.org/data/definitions/524.html)


#### WASC Id: 13

#### Source ID: 3



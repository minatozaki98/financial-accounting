# ZAP Scanning Report

ZAP by [Checkmarx](https://checkmarx.com/).


## Summary of Alerts

| Risk Level | Number of Alerts |
| --- | --- |
| High | 0 |
| Medium | 1 |
| Low | 5 |
| Informational | 4 |




## Insights

| Level | Reason | Site | Description | Statistic |
| --- | --- | --- | --- | --- |
| Low | Warning |  | ZAP warnings logged - see the zap.log file for details | 4    |
| Info | Informational | http://host.docker.internal:5296 | Percentage of responses with status code 2xx | 43 % |
| Info | Informational | http://host.docker.internal:5296 | Percentage of responses with status code 4xx | 56 % |
| Info | Informational | http://host.docker.internal:5296 | Percentage of endpoints with content type application/json | 59 % |
| Info | Informational | http://host.docker.internal:5296 | Percentage of endpoints with content type application/problem+json | 25 % |
| Info | Informational | http://host.docker.internal:5296 | Percentage of endpoints with method DELETE | 3 % |
| Info | Informational | http://host.docker.internal:5296 | Percentage of endpoints with method GET | 46 % |
| Info | Informational | http://host.docker.internal:5296 | Percentage of endpoints with method POST | 46 % |
| Info | Informational | http://host.docker.internal:5296 | Percentage of endpoints with method PUT | 3 % |
| Info | Informational | http://host.docker.internal:5296 | Count of total endpoints | 32    |
| Info | Informational | http://host.docker.internal:5296 | Percentage of slow responses | 12 % |







## Alerts

| Name | Risk Level | Number of Instances |
| --- | --- | --- |
| Cross-Domain Misconfiguration | Medium | Systemic |
| Server Leaks Information via "X-Powered-By" HTTP Response Header Field(s) | Low | Systemic |
| X-AspNet-Version Response Header | Low | Systemic |
| X-Backend-Server Header Information Leak | Low | Systemic |
| X-Content-Type-Options Header Missing | Low | Systemic |
| X-Debug-Token Information Leak | Low | Systemic |
| A Client Error response code was returned by the server | Informational | 18 |
| Authentication Request Identified | Informational | 2 |
| Information Disclosure - Sensitive Information in URL | Informational | 1 |
| Non-Storable Content | Informational | Systemic |




## Alert Detail



### [ Cross-Domain Misconfiguration ](https://www.zaproxy.org/docs/alerts/10098/)



##### Medium (Medium)

### Description

Web browser data loading may be possible, due to a Cross Origin Resource Sharing (CORS) misconfiguration on the web server.

* URL: http://host.docker.internal:5296/journal-entries/10
  * Node Name: `http://host.docker.internal:5296/journal-entries/10`
  * Method: `DELETE`
  * Parameter: ``
  * Attack: ``
  * Evidence: `Access-Control-Allow-Origin: *`
  * Other Info: `The CORS misconfiguration on the web server permits cross-domain read requests from arbitrary third party domains, using unauthenticated APIs on this domain. Web browser implementations do not permit arbitrary third parties to read the response from authenticated APIs, however. This reduces the risk somewhat. This misconfiguration could be used by an attacker to access data that is available in an unauthenticated manner, but which uses some other form of security, such as IP address white-listing.`
* URL: http://host.docker.internal:5296/accounts%3Ftype=type&isActive=true&search=ZAP
  * Node Name: `http://host.docker.internal:5296/accounts (isActive,search,type)`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `Access-Control-Allow-Origin: *`
  * Other Info: `The CORS misconfiguration on the web server permits cross-domain read requests from arbitrary third party domains, using unauthenticated APIs on this domain. Web browser implementations do not permit arbitrary third parties to read the response from authenticated APIs, however. This reduces the risk somewhat. This misconfiguration could be used by an attacker to access data that is available in an unauthenticated manner, but which uses some other form of security, such as IP address white-listing.`
* URL: http://host.docker.internal:5296/accounts/10
  * Node Name: `http://host.docker.internal:5296/accounts/10`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `Access-Control-Allow-Origin: *`
  * Other Info: `The CORS misconfiguration on the web server permits cross-domain read requests from arbitrary third party domains, using unauthenticated APIs on this domain. Web browser implementations do not permit arbitrary third parties to read the response from authenticated APIs, however. This reduces the risk somewhat. This misconfiguration could be used by an attacker to access data that is available in an unauthenticated manner, but which uses some other form of security, such as IP address white-listing.`
* URL: http://host.docker.internal:5296/accounts
  * Node Name: `http://host.docker.internal:5296/accounts ()({accountCode,accountName,accountType,isActive})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `Access-Control-Allow-Origin: *`
  * Other Info: `The CORS misconfiguration on the web server permits cross-domain read requests from arbitrary third party domains, using unauthenticated APIs on this domain. Web browser implementations do not permit arbitrary third parties to read the response from authenticated APIs, however. This reduces the risk somewhat. This misconfiguration could be used by an attacker to access data that is available in an unauthenticated manner, but which uses some other form of security, such as IP address white-listing.`
* URL: http://host.docker.internal:5296/journal-entries
  * Node Name: `http://host.docker.internal:5296/journal-entries ()({entryDate,description,referenceNo,lines:[{accountId,lineDescription,debit,credit}]})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `Access-Control-Allow-Origin: *`
  * Other Info: `The CORS misconfiguration on the web server permits cross-domain read requests from arbitrary third party domains, using unauthenticated APIs on this domain. Web browser implementations do not permit arbitrary third parties to read the response from authenticated APIs, however. This reduces the risk somewhat. This misconfiguration could be used by an attacker to access data that is available in an unauthenticated manner, but which uses some other form of security, such as IP address white-listing.`

Instances: Systemic


### Solution

Ensure that sensitive data is not available in an unauthenticated manner (using IP address white-listing, for instance).
Configure the "Access-Control-Allow-Origin" HTTP header to a more restrictive set of domains, or remove all CORS headers entirely, to allow the web browser to enforce the Same Origin Policy (SOP) in a more restrictive manner.

### Reference


* [ https://vulncat.fortify.com/en/detail?category=HTML5&subcategory=Overly%20Permissive%20CORS%20Policy ](https://vulncat.fortify.com/en/detail?category=HTML5&subcategory=Overly%20Permissive%20CORS%20Policy)


#### CWE Id: [ 264 ](https://cwe.mitre.org/data/definitions/264.html)


#### WASC Id: 14

#### Source ID: 3

### [ Server Leaks Information via "X-Powered-By" HTTP Response Header Field(s) ](https://www.zaproxy.org/docs/alerts/10037/)



##### Low (Medium)

### Description

The web/application server is leaking information via one or more "X-Powered-By" HTTP response headers. Access to such information may facilitate attackers identifying other frameworks/components your web application is reliant upon and the vulnerabilities such components may be subject to.

* URL: http://host.docker.internal:5296/journal-entries/10
  * Node Name: `http://host.docker.internal:5296/journal-entries/10`
  * Method: `DELETE`
  * Parameter: ``
  * Attack: ``
  * Evidence: `X-Powered-By: FinancialAccounting-Benchmark`
  * Other Info: ``
* URL: http://host.docker.internal:5296/accounts/10
  * Node Name: `http://host.docker.internal:5296/accounts/10`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `X-Powered-By: FinancialAccounting-Benchmark`
  * Other Info: ``
* URL: http://host.docker.internal:5296/accounts
  * Node Name: `http://host.docker.internal:5296/accounts ()({accountCode,accountName,accountType,isActive})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `X-Powered-By: FinancialAccounting-Benchmark`
  * Other Info: ``
* URL: http://host.docker.internal:5296/journal-entries/10/post
  * Node Name: `http://host.docker.internal:5296/journal-entries/10/post`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `X-Powered-By: FinancialAccounting-Benchmark`
  * Other Info: ``
* URL: http://host.docker.internal:5296/accounts/10
  * Node Name: `http://host.docker.internal:5296/accounts/10 ()({accountName,accountType,isActive})`
  * Method: `PUT`
  * Parameter: ``
  * Attack: ``
  * Evidence: `X-Powered-By: FinancialAccounting-Benchmark`
  * Other Info: ``

Instances: Systemic


### Solution

Ensure that your web server, application server, load balancer, etc. is configured to suppress "X-Powered-By" headers.

### Reference


* [ https://owasp.org/www-project-web-security-testing-guide/v42/4-Web_Application_Security_Testing/01-Information_Gathering/08-Fingerprint_Web_Application_Framework ](https://owasp.org/www-project-web-security-testing-guide/v42/4-Web_Application_Security_Testing/01-Information_Gathering/08-Fingerprint_Web_Application_Framework)
* [ https://www.troyhunt.com/shhh-dont-let-your-response-headers/ ](https://www.troyhunt.com/shhh-dont-let-your-response-headers/)


#### CWE Id: [ 497 ](https://cwe.mitre.org/data/definitions/497.html)


#### WASC Id: 13

#### Source ID: 3

### [ X-AspNet-Version Response Header ](https://www.zaproxy.org/docs/alerts/10061/)



##### Low (High)

### Description

Server leaks information via "X-AspNet-Version"/"X-AspNetMvc-Version" HTTP response header field(s).

* URL: http://host.docker.internal:5296/accounts/10/balance
  * Node Name: `http://host.docker.internal:5296/accounts/10/balance`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `4.0.30319`
  * Other Info: `An attacker can use this information to exploit known vulnerabilities.`
* URL: http://host.docker.internal:5296/journal-entries
  * Node Name: `http://host.docker.internal:5296/journal-entries ()({entryDate,description,referenceNo,lines:[{accountId,lineDescription,debit,credit}]})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `4.0.30319`
  * Other Info: `An attacker can use this information to exploit known vulnerabilities.`
* URL: http://host.docker.internal:5296/journal-entries/10/post
  * Node Name: `http://host.docker.internal:5296/journal-entries/10/post`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `4.0.30319`
  * Other Info: `An attacker can use this information to exploit known vulnerabilities.`
* URL: http://host.docker.internal:5296/journal-entries/bulk
  * Node Name: `http://host.docker.internal:5296/journal-entries/bulk ()({entries:[{entryDate,description,referenceNo,lines:[{accountId,lineDescription,debit,credit}]}]})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `4.0.30319`
  * Other Info: `An attacker can use this information to exploit known vulnerabilities.`
* URL: http://host.docker.internal:5296/journal-imports/validate
  * Node Name: `http://host.docker.internal:5296/journal-imports/validate ()(multipart:File,IdempotencyKey,Atomic)`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `4.0.30319`
  * Other Info: `An attacker can use this information to exploit known vulnerabilities.`

Instances: Systemic


### Solution

Configure the server so it will not return those headers.

### Reference


* [ https://www.troyhunt.com/shhh-dont-let-your-response-headers/ ](https://www.troyhunt.com/shhh-dont-let-your-response-headers/)
* [ https://learn.microsoft.com/en-us/archive/blogs/varunm/remove-unwanted-http-response-headers ](https://learn.microsoft.com/en-us/archive/blogs/varunm/remove-unwanted-http-response-headers)


#### CWE Id: [ 933 ](https://cwe.mitre.org/data/definitions/933.html)


#### WASC Id: 14

#### Source ID: 3

### [ X-Backend-Server Header Information Leak ](https://www.zaproxy.org/docs/alerts/10039/)



##### Low (Medium)

### Description

The server is leaking information pertaining to backend systems (such as hostnames or IP addresses). Armed with this information an attacker may be able to attack other systems or more directly/efficiently attack those systems.

* URL: http://host.docker.internal:5296/journal-entries/10
  * Node Name: `http://host.docker.internal:5296/journal-entries/10`
  * Method: `DELETE`
  * Parameter: ``
  * Attack: ``
  * Evidence: `benchmark-node-01`
  * Other Info: ``
* URL: http://host.docker.internal:5296/accounts
  * Node Name: `http://host.docker.internal:5296/accounts ()({accountCode,accountName,accountType,isActive})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `benchmark-node-01`
  * Other Info: ``
* URL: http://host.docker.internal:5296/journal-entries
  * Node Name: `http://host.docker.internal:5296/journal-entries ()({entryDate,description,referenceNo,lines:[{accountId,lineDescription,debit,credit}]})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `benchmark-node-01`
  * Other Info: ``
* URL: http://host.docker.internal:5296/journal-entries/10/post
  * Node Name: `http://host.docker.internal:5296/journal-entries/10/post`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `benchmark-node-01`
  * Other Info: ``
* URL: http://host.docker.internal:5296/journal-entries/10/reverse
  * Node Name: `http://host.docker.internal:5296/journal-entries/10/reverse`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `benchmark-node-01`
  * Other Info: ``

Instances: Systemic


### Solution

Ensure that your web server, application server, load balancer, etc. is configured to suppress X-Backend-Server headers.

### Reference



#### CWE Id: [ 497 ](https://cwe.mitre.org/data/definitions/497.html)


#### WASC Id: 13

#### Source ID: 3

### [ X-Content-Type-Options Header Missing ](https://www.zaproxy.org/docs/alerts/10021/)



##### Low (Medium)

### Description

The Anti-MIME-Sniffing header X-Content-Type-Options was not set to 'nosniff'. This allows older versions of Internet Explorer and Chrome to perform MIME-sniffing on the response body, potentially causing the response body to be interpreted and displayed as a content type other than the declared content type. Current (early 2014) and legacy versions of Firefox will use the declared content type (if one is set), rather than performing MIME-sniffing.

* URL: http://host.docker.internal:5296/accounts%3Ftype=type&isActive=true&search=ZAP
  * Node Name: `http://host.docker.internal:5296/accounts (isActive,search,type)`
  * Method: `GET`
  * Parameter: `x-content-type-options`
  * Attack: ``
  * Evidence: ``
  * Other Info: `This issue still applies to error type pages (401, 403, 500, etc.) as those pages are often still affected by injection issues, in which case there is still concern for browsers sniffing pages away from their actual content type.
At "High" threshold this scan rule will not alert on client or server error responses.`
* URL: http://host.docker.internal:5296/accounts/10
  * Node Name: `http://host.docker.internal:5296/accounts/10`
  * Method: `GET`
  * Parameter: `x-content-type-options`
  * Attack: ``
  * Evidence: ``
  * Other Info: `This issue still applies to error type pages (401, 403, 500, etc.) as those pages are often still affected by injection issues, in which case there is still concern for browsers sniffing pages away from their actual content type.
At "High" threshold this scan rule will not alert on client or server error responses.`
* URL: http://host.docker.internal:5296/accounts/10/balance
  * Node Name: `http://host.docker.internal:5296/accounts/10/balance`
  * Method: `GET`
  * Parameter: `x-content-type-options`
  * Attack: ``
  * Evidence: ``
  * Other Info: `This issue still applies to error type pages (401, 403, 500, etc.) as those pages are often still affected by injection issues, in which case there is still concern for browsers sniffing pages away from their actual content type.
At "High" threshold this scan rule will not alert on client or server error responses.`
* URL: http://host.docker.internal:5296/journal-entries/10
  * Node Name: `http://host.docker.internal:5296/journal-entries/10`
  * Method: `GET`
  * Parameter: `x-content-type-options`
  * Attack: ``
  * Evidence: ``
  * Other Info: `This issue still applies to error type pages (401, 403, 500, etc.) as those pages are often still affected by injection issues, in which case there is still concern for browsers sniffing pages away from their actual content type.
At "High" threshold this scan rule will not alert on client or server error responses.`
* URL: http://host.docker.internal:5296/journal-entries/10/reverse
  * Node Name: `http://host.docker.internal:5296/journal-entries/10/reverse`
  * Method: `POST`
  * Parameter: `x-content-type-options`
  * Attack: ``
  * Evidence: ``
  * Other Info: `This issue still applies to error type pages (401, 403, 500, etc.) as those pages are often still affected by injection issues, in which case there is still concern for browsers sniffing pages away from their actual content type.
At "High" threshold this scan rule will not alert on client or server error responses.`

Instances: Systemic


### Solution

Ensure that the application/web server sets the Content-Type header appropriately, and that it sets the X-Content-Type-Options header to 'nosniff' for all web pages.
If possible, ensure that the end user uses a standards-compliant and modern web browser that does not perform MIME-sniffing at all, or that can be directed by the web application/web server to not perform MIME-sniffing.

### Reference


* [ https://learn.microsoft.com/en-us/previous-versions/windows/internet-explorer/ie-developer/compatibility/gg622941(v=vs.85) ](https://learn.microsoft.com/en-us/previous-versions/windows/internet-explorer/ie-developer/compatibility/gg622941(v=vs.85))
* [ https://owasp.org/www-community/Security_Headers ](https://owasp.org/www-community/Security_Headers)


#### CWE Id: [ 693 ](https://cwe.mitre.org/data/definitions/693.html)


#### WASC Id: 15

#### Source ID: 3

### [ X-Debug-Token Information Leak ](https://www.zaproxy.org/docs/alerts/10056/)



##### Low (High)

### Description

The response contained an X-Debug-Token or X-Debug-Token-Link header. This indicates that Symfony's Profiler may be in use and exposing sensitive data.

* URL: http://host.docker.internal:5296/journal-entries/10
  * Node Name: `http://host.docker.internal:5296/journal-entries/10`
  * Method: `DELETE`
  * Parameter: ``
  * Attack: ``
  * Evidence: `X-Debug-Token: zap-v2-debug-marker`
  * Other Info: `By accessing a URL in the form https://target_host/_profiler/token_value (i.e.: https://example.com/_profiler_/123ab4), you may gain access to the profiler and further leaked information.`
* URL: http://host.docker.internal:5296/accounts/10
  * Node Name: `http://host.docker.internal:5296/accounts/10`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `X-Debug-Token: zap-v2-debug-marker`
  * Other Info: `By accessing a URL in the form https://target_host/_profiler/token_value (i.e.: https://example.com/_profiler_/123ab4), you may gain access to the profiler and further leaked information.`
* URL: http://host.docker.internal:5296/accounts
  * Node Name: `http://host.docker.internal:5296/accounts ()({accountCode,accountName,accountType,isActive})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `X-Debug-Token: zap-v2-debug-marker`
  * Other Info: `By accessing a URL in the form https://target_host/_profiler/token_value (i.e.: https://example.com/_profiler_/123ab4), you may gain access to the profiler and further leaked information.`
* URL: http://host.docker.internal:5296/journal-entries/10/post
  * Node Name: `http://host.docker.internal:5296/journal-entries/10/post`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `X-Debug-Token: zap-v2-debug-marker`
  * Other Info: `By accessing a URL in the form https://target_host/_profiler/token_value (i.e.: https://example.com/_profiler_/123ab4), you may gain access to the profiler and further leaked information.`
* URL: http://host.docker.internal:5296/accounts/10
  * Node Name: `http://host.docker.internal:5296/accounts/10 ()({accountName,accountType,isActive})`
  * Method: `PUT`
  * Parameter: ``
  * Attack: ``
  * Evidence: `X-Debug-Token: zap-v2-debug-marker`
  * Other Info: `By accessing a URL in the form https://target_host/_profiler/token_value (i.e.: https://example.com/_profiler_/123ab4), you may gain access to the profiler and further leaked information.`

Instances: Systemic


### Solution

Limit access to Symfony's Profiler, either via authentication/authorization or limiting inclusion of the header to specific clients (by IP, etc.).

### Reference


* [ https://symfony.com/doc/current/profiler.html ](https://symfony.com/doc/current/profiler.html)
* [ https://symfony.com/blog/new-in-symfony-2-4-quicker-access-to-the-profiler-when-working-on-an-api ](https://symfony.com/blog/new-in-symfony-2-4-quicker-access-to-the-profiler-when-working-on-an-api)


#### CWE Id: [ 489 ](https://cwe.mitre.org/data/definitions/489.html)


#### WASC Id: 13

#### Source ID: 3

### [ A Client Error response code was returned by the server ](https://www.zaproxy.org/docs/alerts/100000/)



##### Informational (High)

### Description

A response code of 400 was returned by the server.
This may indicate that the application is failing to handle unexpected input correctly.
Raised by the 'Alert on HTTP Response Code Error' script

* URL: http://host.docker.internal:5296/journal-entries/10
  * Node Name: `http://host.docker.internal:5296/journal-entries/10`
  * Method: `DELETE`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: http://host.docker.internal:5296/audit-logs%3Ffrom=from&to=to&userId=userId&action=action&page=1&pageSize=50
  * Node Name: `http://host.docker.internal:5296/audit-logs (action,from,page,pageSize,to,userId)`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `400`
  * Other Info: ``
* URL: http://host.docker.internal:5296/journal-entries%3FFrom=From&To=To&Status=Status&AccountId=10&Search=ZAP&Page=10&PageSize=10&Sort=Sort
  * Node Name: `http://host.docker.internal:5296/journal-entries (AccountId,From,Page,PageSize,Search,Sort,Status,To)`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `400`
  * Other Info: ``
* URL: http://host.docker.internal:5296/reconciliations/reconciliationId/exceptions
  * Node Name: `http://host.docker.internal:5296/reconciliations/reconciliationId/exceptions`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: http://host.docker.internal:5296/accounts
  * Node Name: `http://host.docker.internal:5296/accounts ()({accountCode,accountName,accountType,isActive})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `400`
  * Other Info: ``
* URL: http://host.docker.internal:5296/auth/login
  * Node Name: `http://host.docker.internal:5296/auth/login ()({username,password})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `401`
  * Other Info: ``
* URL: http://host.docker.internal:5296/journal-entries
  * Node Name: `http://host.docker.internal:5296/journal-entries ()({entryDate,description,referenceNo,lines:[{accountId,lineDescription,debit,credit}]})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `400`
  * Other Info: ``
* URL: http://host.docker.internal:5296/journal-entries/10/post
  * Node Name: `http://host.docker.internal:5296/journal-entries/10/post`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: http://host.docker.internal:5296/journal-entries/bulk
  * Node Name: `http://host.docker.internal:5296/journal-entries/bulk ()({entries:[{entryDate,description,referenceNo,lines:[{accountId,lineDescription,debit,credit}]}]})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `400`
  * Other Info: ``
* URL: http://host.docker.internal:5296/journal-imports/importId/commit
  * Node Name: `http://host.docker.internal:5296/journal-imports/importId/commit`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: http://host.docker.internal:5296/journal-imports/validate
  * Node Name: `http://host.docker.internal:5296/journal-imports/validate ()(multipart:File,IdempotencyKey,Atomic)`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `400`
  * Other Info: ``
* URL: http://host.docker.internal:5296/periods/10/close
  * Node Name: `http://host.docker.internal:5296/periods/10/close ()({requestId,expectedVersion})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `400`
  * Other Info: ``
* URL: http://host.docker.internal:5296/reconciliations
  * Node Name: `http://host.docker.internal:5296/reconciliations ()({periodId,bankAccountId,dateFrom,dateTo,transactions:[{transactionDate,amount,referenceNo,description}]})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `400`
  * Other Info: ``
* URL: http://host.docker.internal:5296/reconciliations/reconciliationId/auto-match
  * Node Name: `http://host.docker.internal:5296/reconciliations/reconciliationId/auto-match`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: http://host.docker.internal:5296/reconciliations/reconciliationId/confirm
  * Node Name: `http://host.docker.internal:5296/reconciliations/reconciliationId/confirm ()({bankTransactionId,journalEntryId,expectedVersion})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: http://host.docker.internal:5296/reconciliations/reconciliationId/finalize
  * Node Name: `http://host.docker.internal:5296/reconciliations/reconciliationId/finalize ()({requestId,expectedVersion})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `404`
  * Other Info: ``
* URL: http://host.docker.internal:5296/users
  * Node Name: `http://host.docker.internal:5296/users ()({username,email,password,role})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `400`
  * Other Info: ``
* URL: http://host.docker.internal:5296/accounts/10
  * Node Name: `http://host.docker.internal:5296/accounts/10 ()({accountName,accountType,isActive})`
  * Method: `PUT`
  * Parameter: ``
  * Attack: ``
  * Evidence: `400`
  * Other Info: ``


Instances: 18

### Solution



### Reference



#### CWE Id: [ 388 ](https://cwe.mitre.org/data/definitions/388.html)


#### WASC Id: 20

#### Source ID: 4

### [ Authentication Request Identified ](https://www.zaproxy.org/docs/alerts/10111/)



##### Informational (High)

### Description

The given request has been identified as an authentication request. The 'Other Info' field contains a set of key=value lines which identify any relevant fields. If the request is in a context which has an Authentication Method set to "Auto-Detect" then this rule will change the authentication to match the request identified.

* URL: http://host.docker.internal:5296/users
  * Node Name: `http://host.docker.internal:5296/users ()({username,email,password,role})`
  * Method: `POST`
  * Parameter: `email`
  * Attack: ``
  * Evidence: `password`
  * Other Info: `userParam=email
userValue=zaproxy@example.com
passwordParam=password`
* URL: http://host.docker.internal:5296/auth/login
  * Node Name: `http://host.docker.internal:5296/auth/login ()({username,password})`
  * Method: `POST`
  * Parameter: `username`
  * Attack: ``
  * Evidence: `password`
  * Other Info: `userParam=username
userValue=John Doe
passwordParam=password`


Instances: 2

### Solution

This is an informational alert rather than a vulnerability and so there is nothing to fix.

### Reference


* [ https://www.zaproxy.org/docs/desktop/addons/authentication-helper/auth-req-id/ ](https://www.zaproxy.org/docs/desktop/addons/authentication-helper/auth-req-id/)



#### Source ID: 3

### [ Information Disclosure - Sensitive Information in URL ](https://www.zaproxy.org/docs/alerts/10024/)



##### Informational (Medium)

### Description

The request appeared to contain sensitive information leaked in the URL. This can violate PCI and most organizational compliance policies. You can configure the list of strings for this check to add or remove values specific to your environment.

* URL: http://host.docker.internal:5296/audit-logs%3Ffrom=from&to=to&userId=userId&action=action&page=1&pageSize=50
  * Node Name: `http://host.docker.internal:5296/audit-logs (action,from,page,pageSize,to,userId)`
  * Method: `GET`
  * Parameter: `userId`
  * Attack: ``
  * Evidence: `userId`
  * Other Info: `The URL contains potentially sensitive information. The following string was found via the pattern: user
userId`


Instances: 1

### Solution

Do not pass sensitive information in URIs.

### Reference



#### CWE Id: [ 598 ](https://cwe.mitre.org/data/definitions/598.html)


#### WASC Id: 13

#### Source ID: 3

### [ Non-Storable Content ](https://www.zaproxy.org/docs/alerts/10049/)



##### Informational (Medium)

### Description

The response contents are not storable by caching components such as proxy servers. If the response does not contain sensitive, personal or user-specific information, it may benefit from being stored and cached, to improve performance.

* URL: http://host.docker.internal:5296/journal-entries/10
  * Node Name: `http://host.docker.internal:5296/journal-entries/10`
  * Method: `DELETE`
  * Parameter: ``
  * Attack: ``
  * Evidence: `DELETE `
  * Other Info: ``
* URL: http://host.docker.internal:5296/accounts%3Ftype=type&isActive=true&search=ZAP
  * Node Name: `http://host.docker.internal:5296/accounts (isActive,search,type)`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `authorization:`
  * Other Info: ``
* URL: http://host.docker.internal:5296/journal-entries%3FFrom=From&To=To&Status=Status&AccountId=10&Search=ZAP&Page=10&PageSize=10&Sort=Sort
  * Node Name: `http://host.docker.internal:5296/journal-entries (AccountId,From,Page,PageSize,Search,Sort,Status,To)`
  * Method: `GET`
  * Parameter: ``
  * Attack: ``
  * Evidence: `authorization:`
  * Other Info: ``
* URL: http://host.docker.internal:5296/journal-entries
  * Node Name: `http://host.docker.internal:5296/journal-entries ()({entryDate,description,referenceNo,lines:[{accountId,lineDescription,debit,credit}]})`
  * Method: `POST`
  * Parameter: ``
  * Attack: ``
  * Evidence: `authorization:`
  * Other Info: ``
* URL: http://host.docker.internal:5296/accounts/10
  * Node Name: `http://host.docker.internal:5296/accounts/10 ()({accountName,accountType,isActive})`
  * Method: `PUT`
  * Parameter: ``
  * Attack: ``
  * Evidence: `PUT `
  * Other Info: ``

Instances: Systemic


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

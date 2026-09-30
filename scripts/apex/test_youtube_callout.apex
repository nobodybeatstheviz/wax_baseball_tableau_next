// Smoke test: Named Credential chain (NC -> EC principal -> X-Goog-Api-Key header) -> YouTube Data API v3.
HttpRequest req = new HttpRequest();
req.setEndpoint('callout:YouTube_Data_API/youtube/v3/search?part=snippet&q=yankees+red+sox+2003+alcs+highlights&type=video&maxResults=1');
req.setMethod('GET');
HttpResponse res = new Http().send(req);
System.debug('STATUS=' + res.getStatusCode());
System.debug('BODY=' + res.getBody().left(300));

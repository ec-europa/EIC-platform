xquery version "3.0";
(: --------------------------------------
   SMEi ccmatch

   Creation: Franck Leplé <franck.leple@amplexor.com>
   Contributor:     
   
   Description:
    Drupal Web services module

   June 2018 - European Union Public Licence EUPL
   ----------------------------------------------- :)

module namespace drupal = "http://oppidoc.com/ns/application/drupal";
import module namespace request = "http://exist-db.org/xquery/request";

declare namespace xdb="http://exist-db.org/xquery/xmldb";
import module namespace http = "http://expath.org/ns/http-client";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace template = "http://oppidoc.com/ns/cctracker/template" at "../../lib/template.xqm";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
    Description:
    Magic function used to displayed xml from Web service response
   ====================================================================== 
:)
declare function drupal:serialize( $e as element() ) {
  <pre>
    { 
    fn:serialize(
      $e,
      <output:serialization-parameters>
        <output:indent value="yes"/>
      </output:serialization-parameters>
    )
    }
  </pre>
};

(: ======================================================================
   Get Authorization Basic if this element is in the Service declaration 
   See services.xml
   ======================================================================
:)
declare function drupal:get-authorization-basic ( $service as element() ) as element()? {
  if (exists($service/AuthorizationBasic)) then
    let $value := concat("Basic ", $service/AuthorizationBasic/text())
    return
      <http:header name="Authorization" value="{ $value }"/>
  else ()
};


(: ======================================================================
   Get Authorization Token if this element is in the Service declaration 
   See services.xml
   ======================================================================
:)
declare function drupal:get-authorization-token ($service-name as xs:string) as element()? {
  let $service := fn:doc($globals:services-uri)//Consumers/Service[Id eq $service-name]
  return
    if (exists($service/AuthorizationToken)) then
      <AuthorizationToken>{ $service/AuthorizationToken/text() }</AuthorizationToken>
    else ()
};

(: ======================================================================
   Internal utility to generate a service label for error messages
   ======================================================================
:)
declare function drupal:gen-service-name( $service as xs:string?, $end-point as xs:string? ) as xs:string {
  concat('"', $end-point, '" end-point of service "', $service, '"')
};

(: ======================================================================
   Marshalls a single element payload content to invoke a given service using
   the service API model (i.e. including authorization token as per services.xml)
   ======================================================================
:)
declare function drupal:marshall( $service as element()?, $payload as item()* ) as element() {
  $payload
};

(: ======================================================================
   Log on demand (see settings.xml) and return service response
   FIXME: log anyway in case of failure ?
   ====================================================================== 
:)
declare function drupal:log( $service as element(), $end-point as element(), $method as xs:string, $urlextension as xs:string, $payload as element()?, $res as element()? ) as element()? {
  let $debug := globals:doc('settings-uri')/Settings/Services/Debug
  let $log := $debug/Service[Name eq $service/Id][not(EndPoint) or EndPoint eq $end-point/Id]
  return
    if (exists($log)) then
      if (fn:doc-available('/db/debug/services.xml')) then
        let $archive := 
          <service date="{ current-dateTime() }">
            {
            attribute { 'status' } { 
              if (exists(globals:doc('settings-uri')/Settings/Services/Disallow/Service[Name eq $service/Id][not(EndPoint) or EndPoint eq $end-point/Id])) then
                'unplugged'
              else if (local-name($res) eq 'error') then
                'error'
              else
                'done'
            },
            <To>{ $service/Id/text() } / { $end-point/Id/text() }</To>,
            <Request method="{ $method }" url="{ concat($end-point/URL, $urlextension) }">{ drupal:marshall($service, $payload) }</Request>,
            <Response>
              {
              if (exists($log/Logger/Assert)) then (: implements Logger syntax - only 1 for now :)
                if (util:eval($log/Logger/Assert)) then
                  try { util:eval($log/Logger/Format) } catch * { $res }
                else
                  $res
              else
                $res
              }
            </Response>
            }
          </service>
        return (
          try { update insert $archive into fn:doc('/db/debug/services.xml')/Debug }
          catch * { () },
          $res
          )
      else
        $res
    else
      $res
};

(: ======================================================================
   POST XML payload to an URL address. Low-level implementation

   Returns an Oppidum error in case service is not configured properly
   in services.xml or is not listening or if the response payload contains
   an error raised with oppidum:throw-error (whatever its status code)
   or, finally, if the response from the POST returns a status code not expected

   TODO:
   - better differentiate error messages (incl. 404)
   - detect XQuery errors dumps in responses (like oppidum.js) and relay them
   - actually oppidum:throw-error in the service with a status code not in 200 
     results in an <httpclient:body type="text" encoding="URLEncoded"/>
     and a statusCode="500" !
   ======================================================================
:)

declare function drupal:post-to-address ( $address as xs:string, $payload as item()?, $expected as xs:string+, $debug-name as xs:string , $headers, $timeout as xs:string) as element()? {
  if ($address castable as xs:anyURI) then
    try{
      let $uri := xs:anyURI($address)
      (:let $res := httpclient:post($uri, $payload, false(), $headers):)
      let $request := 
      <http:request href="{$uri}" method="post" timeout="{$timeout}">
        {$headers/*}
        <http:body media-type="text/xml">{ $payload }</http:body>
      </http:request>
      let $response := http:send-request($request)
      let $response-header := $response[1]
      let $response-body := $response[2]
      let $res := <response statusCode="{$response-header/@status}" message="{$response-header/@message}">
        <httpclient:header name="Date">{ current-dateTime() }</httpclient:header>
        <httpclient:body>
          <result>{(
            if (exists($response-header/@message)) then
            <message>{$response-header/@message}</message>
            else ()
            ,
            if (contains($response-body,'?xml')) then 
              parse-xml($response-body)
            else
              $response-body
          )}</result></httpclient:body></response>
      
      return
        $res
      }
      catch *
      {
        let $res := <response statusCode="504">
        <httpclient:header name="Date">{ current-dateTime() }</httpclient:header>
        <httpclient:body><result><error>{$err:description} timeout: {$timeout}</error></result></httpclient:body></response>
        return  $res

    }
  
  else
    oppidum:throw-error('SERVICE-MALFORMED-URL', ($debug-name, $address))
};


(: ======================================================================
   PUT XML payload to an URL address. Low-level implementation

   Returns an Oppidum error in case service is not configured properly
   in services.xml or is not listening or if the response payload contains
   an error raised with oppidum:throw-error (whatever its status code)
   or, finally, if the response from the POST returns a status code not expected

   TODO:
   - better differentiate error messages (incl. 404)
   - detect XQuery errors dumps in responses (like oppidum.js) and relay them
   - actually oppidum:throw-error in the service with a status code not in 200 
     results in an <httpclient:body type="text" encoding="URLEncoded"/>
     and a statusCode="500" !
   ======================================================================
:)

declare function drupal:put-to-address ( $address as xs:string, $payload as item()?, $expected as xs:string+, $debug-name as xs:string , $headers, $timeout as xs:string) as element()? {
  if ($address castable as xs:anyURI) then
   try{
    let $uri := xs:anyURI($address)
    (:let $res := httpclient:put($uri, $payload, false(), $headers)
    let $status := string($res/@statusCode):)
    let $request := 
      <http:request href="{$uri}" method="put" timeout="{$timeout}">
        {$headers/*}
        <http:body media-type="text/xml">{ $payload }</http:body>
      </http:request>
      let $response := http:send-request($request)
      let $response-header := $response[1]
      let $response-body := $response[2]
      let $res := <response statusCode="{$response-header/@status}" message="{$response-header/@message}">
        <httpclient:header name="Date">{ current-dateTime() }</httpclient:header>
        <httpclient:body>
          <result>{(
            if (exists($response-header/@message)) then
            <message>{$response-header/@message}</message>
            else ()
            ,
            if (contains($response-body,'?xml')) then 
              parse-xml($response-body)
            else
              $response-body
          )}</result></httpclient:body></response>
      
      return
        $res
      }
      catch *
      {
        let $res := <response statusCode="504">
        <httpclient:header name="Date">{ current-dateTime() }</httpclient:header>
        <httpclient:body><result><error>{$err:description} timeout: {$timeout}</error></result></httpclient:body></response>
        return  $res

    }
  else
    oppidum:throw-error('SERVICE-MALFORMED-URL', ($debug-name, $address))
};


(: ======================================================================
   Create headers for:
     - Basic authentification
   
   TODO:
    - Digest mode
   ======================================================================
:)
declare function drupal:get-headers($service as element()?) { 
    <http:headers>
      <http:header name="Content-Type" value="application/xml"/>
      { drupal:get-authorization-basic ( $service) }
      <http:header name="Accept" value="*/*"/>
    </http:headers>
};

(: ======================================================================
   POST XML payload to a service and an end-point elements
   ======================================================================
:)
declare function drupal:post-to-service-imp ( $service as element()?, $end-point as element()?, $payload as item()?, $expected as xs:string+ ) as element()? {
  if ($service and $end-point) then
    let $service-name := drupal:gen-service-name($service/Name/text(), $end-point/Name/text())
    let $headers  := drupal:get-headers($service)
    let $envelope := drupal:marshall($service, $payload)
    return drupal:post-to-address($end-point/URL/text(), $envelope, $expected, $service-name, $headers, $service/Timeout/text())
  else
    oppidum:throw-error('SERVICE-MISSING', 'undefined')
};

(: ======================================================================
   PUT XML payload to a service and an end-point elements
   ======================================================================
:)
declare function drupal:put-to-service-imp ( $service as element()?, $end-point as element()?, $payload as item()?, $expected as xs:string+, $urlextension as xs:string ) as element()? {
  if ($service and $end-point) then
    let $service-name := drupal:gen-service-name($service/Name/text(), $end-point/Name/text())
    let $headers  := drupal:get-headers($service)
    let $envelope := drupal:marshall($service, $payload)
    return drupal:put-to-address(concat($end-point/URL/text(), $urlextension), $envelope, $expected, $service-name, $headers, $service/Timeout/text())
  else
    oppidum:throw-error('SERVICE-MISSING', 'undefined')
};

(: ======================================================================
   POST XML payload to named end point of named service
   ======================================================================
:)
declare function drupal:post-to-service ( $service-name as xs:string, $end-point-name as xs:string, $payload as element()?, $expected as xs:string+ ) as element()? {
  let $service := fn:doc($globals:services-uri)//Consumers/Service[Id eq $service-name]
  let $end-point := $service/EndPoint[Id eq $end-point-name]
  let $block := globals:doc('settings-uri')/Settings/Services/Disallow
  return
    if ($service and $end-point) then
      (: filters service call through settings.xml :)
      if ($block/Service[Name eq $service-name][not(EndPoint) or EndPoint eq $end-point-name]) then
        (: fake success - only useful for services that do not return payload :)
        drupal:log($service, $end-point, 'POST', '', $payload, <success status="unplugged"/>)
      else
        drupal:log($service, $end-point,  'POST', '', $payload,
        drupal:post-to-service-imp($service, $end-point, $payload, $expected))
    else
      oppidum:throw-error('SERVICE-MISSING', drupal:gen-service-name($service-name, $end-point-name))
};

(: ======================================================================
   PUT XML payload to named end point of named service
   $urlextension: contains complements of the web service URL (ids, etc.)
   ======================================================================
:)
declare function drupal:put-to-service ( $service-name as xs:string, $end-point-name as xs:string, $payload as element()?, $expected as xs:string+, $urlextension as xs:string  ) as element()? {
  let $service := fn:doc($globals:services-uri)//Consumers/Service[Id eq $service-name]
  let $end-point := $service/EndPoint[Id eq $end-point-name]
  let $block := globals:doc('settings-uri')/Settings/Services/Disallow
  return
    if ($service and $end-point) then
      (: filters service call through settings.xml :)
      if ($block/Service[Name eq $service-name][not(EndPoint) or EndPoint eq $end-point-name]) then
        (: fake success - only useful for services that do not return payload :)
        drupal:log($service, $end-point, 'PUT', $urlextension, $payload, <success status="unplugged"/>)
      else
        drupal:log($service, $end-point, 'PUT', $urlextension, $payload,
        drupal:put-to-service-imp($service, $end-point, $payload, $expected, $urlextension))
    else
      oppidum:throw-error('SERVICE-MISSING', drupal:gen-service-name($service-name, $end-point-name))
};

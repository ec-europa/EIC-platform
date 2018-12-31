xquery version "1.0";
(: --------------------------------------
   XQuery Business Application Development Framework

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Nonce (authorization token)

   Actually this service may be called only from third party applications
   to get a nonce to get an access to a private resource

   Protocol:
    
   POST  <Nonce><Resource>name</Resource></Nonce>
   returns <Nonce For="name">nonce</Nonce>

   Pre-condition: Authorization token registered in services.xml

   Feb 2017 - European Union Public Licence EUPL
   -------------------------------------- :)

declare namespace request = "http://exist-db.org/xquery/request";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../lib/globals.xqm";
import module namespace services = "http://oppidoc.com/ns/services" at "../lib/services.xqm";
import module namespace nonce = "http://oppidoc.com/oppidum/nonce" at "../lib/nonce.xqm";

declare option exist:serialize "method=xml media-type=application/xml";

let $cmd := request:get-attribute('oppidum.command')
let $user := oppidum:get-current-user()
let $envelope := oppidum:get-data()
return
  if (($user eq 'guest') and (local-name($envelope) eq 'Service')) then
    let $errors := services:validate('ccmatch-public', 'ccmatch.nonce', $envelope)
    return
      if (empty($errors)) then
        let $resource := services:unmarshall($envelope)
        return
          if (exists($resource/Resource)) then
            <Nonce For="{$resource/Resource}">{ nonce:generate($resource/Resource) }</Nonce>
          else
            oppidum:throw-error('VALIDATION-FORMAT-ERROR', ())
      else
        $errors
  else
    oppidum:throw-error('BAD-REQUEST', ())


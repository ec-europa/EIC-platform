xquery version "1.0";
(: --------------------------------------
   XQuery Business Application Development Framework

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Nonce (authorization token)

   Feb 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

module namespace nonce = "http://oppidoc.com/oppidum/nonce";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "globals.xqm";

(: ======================================================================
   TODO: factorize somewhere ?
   ====================================================================== 
:)
declare function local:assert-property( $name as xs:string, $value as xs:string ) as xs:boolean {
  let $prop := 
fn:doc(oppidum:path-to-config('settings.xml'))/Settings/Module[Name eq 'nonce']/Property[Key eq $name]/Value
  return 
    exists($prop) and ($prop eq $value)
};

(: ======================================================================
   Generates a unique certificate which can be used to give access to a resource
   Stores the certificate inside the nonces collection
   ====================================================================== 
:)
declare function nonce:generate ( $resource as element() ) as xs:string {
  let $date := current-dateTime()
  let $id := util:hash(concat($resource, $date), "md5")
  return (
    update insert <Nonce TS="{$date}" Resource="{string($resource)}">{ $id }</Nonce> into fn:doc($globals:nonce-uri)/Nonces,
    $id
    )
};

(: ======================================================================
   Checks the given token corresponds to a certificate already stored inside 
   the nonces collection and delete it
   ====================================================================== 
:)
declare function nonce:validate ( $token as xs:string ) as element() {
  let $nonce := fn:doc($globals:nonce-uri)/Nonces/Nonce[. eq $token]
  return
    if ($nonce and empty($nonce/@Views)) then (
      if (local:assert-property('log', 'on')) then
        update insert attribute { 'Views' } { '1' } into $nonce
      else
        update delete $nonce,
      <success/>
      )
    else
      oppidum:throw-error('FORBIDDEN', ())
};

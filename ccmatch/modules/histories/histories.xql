xquery version "1.0";
(: ------------------------------------------------------------------
   CCMATCH - EIC Coach Match Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Return histories for all categories sorted by category

   August 2016 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

declare variable $local:max-days := 20;

let $start-from := string(current-dateTime() - xs:dayTimeDuration(concat("P", $local:max-days, "D")))
return
  <Histories Max="{ $local:max-days }">
    {
    for $cat in distinct-values(fn:collection($globals:histories-uri)//Category/@Name)
    return 
      <Category Name="{ $cat }">
      {
      for $digest in fn:collection($globals:histories-uri)//Category[@Name eq $cat]//Digest
      where string($digest/@Timestamp) >= $start-from
      order by $digest/@Timestamp descending
      return $digest
      }
      </Category>
    }
  </Histories>

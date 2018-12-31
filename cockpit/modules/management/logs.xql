xquery version "3.1";
(: ------------------------------------------------------------------
   SMEIMKT SME Dashboard application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Logs dumping

   2018 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

import module namespace request="http://exist-db.org/xquery/request";

declare option exist:serialize "method=xml media-type=text/xml";

declare variable $local:services-uri := '/db/debug/services.xml';

(: ======================================================================
   Return the latest $count service logs from services.xml log file
   ====================================================================== 
:)
declare function local:get-latest-logs( $count as xs:double ) as element() {
  <Debug Tail="{ $count }" File="{ $local:services-uri }">
    { 
    fn:doc($local:services-uri)/Debug/service[count(following-sibling::service) lt $count] 
    }
  </Debug>
};

let $latest-logs := request:get-parameter('tail', ())
return
  if ($latest-logs castable as xs:double) then
    local:get-latest-logs(number($latest-logs))
  else
    <Debug>
      Syntax: ?tail={{number}}
    </Debug>

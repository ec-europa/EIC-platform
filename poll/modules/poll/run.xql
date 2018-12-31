xquery version "1.0";
(: ------------------------------------------------------------------
   POLL - EIC Poll Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Generates data model for form editing page for a given order 

   June 2015 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

declare namespace request = "http://exist-db.org/xquery/request";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace poll = "http://oppidoc.com/ns/poll" at "../../lib/poll.xqm";

declare function local:gen-date( $date as element()? ) as element()? {
  if ($date) then 
    element { local-name($date) }
      {
      $date/@*,
      concat(substring($date,9,2), '/', substring($date,6,2), '/', substring($date,1,4))
      }
  else
    ()
};

(: ======================================================================
   Generates payload to assert a feedback questionnaire order is still opened
   ====================================================================== 
:)
declare function local:gen-assert( $order as element() ) as element() {
  <Assess>
    <Order>
      { $order/Id }
    </Order>
  </Assess>
};

let $order := poll:get-order()
return
  if (local-name($order) eq 'Order') then
    let $spec := fn:collection($globals:questionnaires-uri)//Poll[Id eq $order/Questionnaire]
    let $submit := empty($order/Closed) and empty($order/Cancelled) and empty($order/Submitted)
    let $assess := 
      if ($submit) then (: pre-check 3rd part hook using XML Assess protocol :)
        poll:post-to-hook-for($order/Questionnaire, local:gen-assert($order)) 
      else
        ()
    return
      <Run>
        { $spec/Title,
          $assess//ProjectName,
          $assess//CompanyName
        }
        <Order>
          { 
          $order/Id,
          $order/Questionnaire,
          local:gen-date($order/Date),
          (: local database - 1st chance to get an explanation :)
          local:gen-date($order/Closed),
          local:gen-date($order/Cancelled),
          local:gen-date($order/Submitted),
          (: third party pre-check - 2nd chance to get an explanation exclusive from 1st chance :)
          local:gen-date($assess//Closed),
          local:gen-date($assess//Cancelled),
          local:gen-date($assess//Submitted)
          }
        </Order>
        { 
        if ($submit) then
          if (empty($assess) or exists($assess//Running)) then 
            <Submit/>
          else if (empty($assess//Assess)) then
            $assess (: error ? :)
          else
            ()
        else
          ()
        }
      </Run>
  else
    $order

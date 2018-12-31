xquery version "1.0";
(: ------------------------------------------------------------------
   CCMATCH - EIC Coach Match Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Returns recent login

   Trick: use ?full to get User-Agent string

   December 2015 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

import module namespace request="http://exist-db.org/xquery/request";

declare option exist:serialize "method=xml media-type=text/xml";

declare function local:gen-login-log ( $date as xs:string, $tag as xs:string ) as element() {
  element { $tag } {
    let $count := count(distinct-values(fn:doc('/db/debug/login.xml')//Login[starts-with(@TS, $date)][. = ('ecas success', 'success')]/@User))
    return (
      attribute { 'UniCount' } { $count },
      for $l in fn:doc('/db/debug/login.xml')//(Login[starts-with(@TS, $date)][(@User ne '')] | Hold[starts-with(@TS, $date)] | Logout[starts-with(@TS, $date)])
      order by $l/@TS descending
      return $l
      )
  }
};

let $today := substring(string(current-date()), 1, 10)
let $yesterday := substring(string(current-date() - xs:dayTimeDuration("P1D")), 1, 10)
let $time := substring(string(current-time()), 1, 5)
let $full := request:get-parameter-names() = 'full'
return
  <Logs Time="{$time}">
    { if ($full) then attribute Full { 'on' } else ()}
    { local:gen-login-log($today, 'Today') }
    { local:gen-login-log($yesterday, 'Yesterday') }
  </Logs>

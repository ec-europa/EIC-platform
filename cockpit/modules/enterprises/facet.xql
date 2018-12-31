xquery version "3.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Generic CRUD controller to manage facet documents inside Enterprise

   March 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace template = "http://oppidoc.com/ns/cctracker/template" at "../../lib/template.xqm";
import module namespace misc = "http://oppidoc.com/ns/misc" at "../../lib/util.xqm";
import module namespace access = "http://oppidoc.com/ns/xcm/access" at "../../../xcm/lib/access.xqm";
import module namespace ajax = "http://oppidoc.com/ns/xcm/ajax" at "../../../xcm/lib/ajax.xqm";
import module namespace enterprise = "http://oppidoc.com/ns/enterprise" at "enterprise.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   MVP version (see SMEIMKT-768): it is not possible to invalidate company 
   if the investor contact has been defined (token allocated) 
   ====================================================================== 
:)
declare function local:validate-scaleupeu( $submitted as element(), $enterprise as element() ) as element()? {
  if (($submitted/StatusFlagRef ne '2') 
       or (every $p in $submitted//Project satisfies exists($p/TerminationFlagRef))
       ) then
    let $last-token := enterprise:get-last-scaleup-request($enterprise)[TokenStatusRef eq '3']
    return
      if ($last-token) then
        let $member := $enterprise//Member[PersonRef eq $last-token/PersonKey]
        return
          oppidum:throw-error('WITHDRAW-TOKEN-FIRST', concat($member/Information/Name/FirstName, ' ', $member/Information/Name/LastName, ' <', $last-token/Email,'>'))
      else
        ()
  else
    ()
};

(: ======================================================================
   Validates submitted data.
   Returns a list of errors to report or the empty sequence.
   ======================================================================
:)
declare function local:validate-submission( $facet as xs:string, $submitted as element(), $enterprise as element() ) as element()* {
  let $errors := (
    if ($facet eq 'cie-status') then
      local:validate-scaleupeu($submitted, $enterprise)
    else
      ()
    )
  return $errors
};

let $m := request:get-method()
let $cmd := oppidum:get-command()
let $lang := string($cmd/@lang)
let $enterprise-no := tokenize($cmd/@trail, '/')[2]
let $enterprise := fn:collection($globals:enterprises-uri)//Enterprise[Id eq $enterprise-no]
let $goal := request:get-parameter('goal', 'read')
let $facet := request:get-attribute('xquery.facet')
return
  if (access:check-tab-permissions($goal, $facet, $enterprise)) then
    if ($m = 'POST') then
      let $submitted := oppidum:get-data()
      let $errors := local:validate-submission($facet, $submitted, $enterprise)
      return
        if (empty($errors)) then
          let $update := template:update-resource($facet, $enterprise, $submitted)
          return
            if ($facet ne 'cie-status') then
              (: TODO: call only if significant delta :)
              enterprise:update-scaleup($enterprise, $update)
            else
              $update
        else
          ajax:report-validation-errors($errors)
    else (: assumes GET :)
      template:gen-read-model($facet, $enterprise, $lang)
  else
    oppidum:throw-error('FORBIDDEN', ())

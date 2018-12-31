xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Public Case information extraction to display in modal window

   April 2015 - (c) Copyright may be reserved
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Returns Case description for display in modal window
   ======================================================================
:)
declare function local:gen-case( $case as element(), $lang as xs:string ) as element() {
  let $data := $case/Information
  return
    if ($data) then
      let $e := $data/ClientEnterprise
      return
        <Case>
          {(
          $data/Title,
          $data/Acronym,
          $data/Summary,
          misc:unreference($data/Call),
          if ($e) then
            <ClientEnterprise>
              {
              $e/(CreationYear | WebSite),
              <Country>{ display:gen-name-for('Countries', $e/Address/Country, $lang) }</Country>,
              misc:unreference($e/SizeRef)
              }
            </ClientEnterprise>
          else
            ()
          )}
        </Case>
    else (: unlikely :)
      <NotFound/>
};

let $cmd := oppidum:get-command()
let $lang := string($cmd/@lang)
let $case-no := string($cmd/resource/@name)
let $case := fn:collection($globals:cases-uri)/Case[No eq $case-no]
return
  (: no access control beyond mapping, this is public information :)
  local:gen-case($case, $lang)

xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Public Case information extraction to display in modal window

   April 2015 - European Union Public Licence EUPL
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
declare function local:gen-project( $project as element(), $lang as xs:string ) as element() {
  let $data := $project/Information
  return
    if ($data) then
        <Project>
          {(
          $data/( Title | Acronym | Summary ),
          <Program>{ string(misc:unreference($data/Call/FundingProgramRef)/@_Display) }</Program>,
          <CallRef>{ string(misc:unreference($data/Call/(SMEiCallRef | FTICallRef | FETCallRef ))/@_Display) }</CallRef>,
          <FundingRef>{ string(misc:unreference($data/Call/(SMEiFundingRef | FETActionRef))/@_Display) }</FundingRef>,
          misc:unreference( $data/Call/(CallTopics | EICPanels | FETTopics) ),
          <Enterprises>
          {
          for $e in $data/Beneficiaries/*
          return
            <Enterprise>
              {
              $e/(Name | CreationYear | WebSite),
              <Country>{ display:gen-name-for('Countries', $e/Address/Country, $lang) }</Country>,
              misc:unreference($e/SizeRef)
              }
            </Enterprise>
          }
          </Enterprises>
          )}
        </Project>
    else (: unlikely :)
      <NotFound/>
};

let $cmd := oppidum:get-command()
let $lang := string($cmd/@lang)
let $pid := string($cmd/resource/@name)
let $p := fn:collection($globals:projects-uri)/Project[Id eq $pid]
return
  (: no access control beyond mapping, this is public information :)
  local:gen-project($p, $lang)

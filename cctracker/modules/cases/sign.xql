xquery version "1.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Grant signature updating

   May 2015 - (c) Copyright may be reserved
   ------------------------------------------------------------------ :)
declare option exist:serialize "method=xml media-type=application/xml";

import module namespace request="http://exist-db.org/xquery/request";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";

(: ======================================================================
   Updates grant signature date in contract in case persisting every other
   information if it exists
   See also information.xql
   ======================================================================
:)
declare function local:update-grant-signature( $case as element(), $date as xs:string ) {
  if ($case/Information) then
    if ($case/Information/Contract) then
      if ($case/Information/Contract/Date) then
        update value $case/Information/Contract/Date with $date
      else
        update insert <Date>{ $date }</Date> into $case/Information/Contract
    else
      update insert <Contract><Date>{ $date }</Date></Contract> into $case/Information
  else (: sanity check although impossible per-construction in import.xql :)
    ()
};

let $m := request:get-method()
let $cmd := request:get-attribute('oppidum.command')
let $case-no := string($cmd/resource/@name)
let $case := fn:collection($globals:cases-uri)/Case[No eq $case-no]
let $errors := access:pre-check-case($case, $m, 'update', 'Information')
return
  if ($m eq 'POST') then
    if (empty($errors)) then
      let $data := oppidum:get-data()
      return (
        local:update-grant-signature($case, $data/Date/text()),
        <success>
          <message>Grant date saved for { $case/Information/Acronym }</message>
          <date>{ $data/Date/text() }</date>
          <case>{ $case-no }</case>
        </success>
        )
    else
      $errors
  else
    oppidum:throw-error('URI-NOT-SUPPORTED', ())

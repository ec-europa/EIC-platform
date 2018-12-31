xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   CRUD controller to manage ClientEnterprise model inside a case

   Only GET supported, enterprise editing is done through
   information.xql and needs-analysis.xql controllers

   This is distinct from the enterprise module since the beneficiaries
   are directly stored within cases to simplify evolving enterprise
   statistical fields for enterprises with multiple-cases

   July 2015 - (c) Copyright may be reserved
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Returns the Enterprise with No $ref with a representation depending on $goal
   ======================================================================
:)
declare function local:gen-enterprise-for-case( $pid as xs:string, $case-no as xs:string, $lang as xs:string ) as element()* {
  let $case := fn:collection($globals:projects-uri)//Project[Id eq $pid]/Cases/Case[No eq $case-no]
  let $e := $case/../../Information/Beneficiaries/(Coordinator | Partner)[PIC eq $case/PIC]
  return
    if ($case) then
      <Enterprise>
        {
        $e/(Name | ShortName | CreationYear),
        misc:unreference($e/(SizeRef | DomainActivityRef)),
        $e/WebSite,
        $e/MainActivities,
        misc:unreference($e/TargetedMarkets),
        misc:unreference($e/Address)
        }
      </Enterprise>
    else
      oppidum:throw-error('URI-NOT-FOUND', ())

};


(: *** MAIN ENTREY POINT *** :)
let $m := request:get-method()
let $cmd := oppidum:get-command()
let $pid := tokenize($cmd/@trail, '/')[2]
let $case-no := tokenize($cmd/@trail, '/')[4]
let $lang := string($cmd/@lang)
return
  local:gen-enterprise-for-case($pid, $case-no, $lang)

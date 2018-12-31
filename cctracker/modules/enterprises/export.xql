xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Exports enterprises 
   To be called from third party applications like SMEi cockpit

   WARNING: exports client enterprises directly stored inside Cases 
   and not the content of the enterprises collection !

   XML protocol

   <Export [Letter="X"]><Call><Date>YYYY-MM-DD</Date><PhaseRef>1|2</PhaseRef></Call></Export> :
   - get enterprises, optional filter by name first letter

   Ex: <Export><Call><Date>2016-09-07</Date></Call></Export>
   (using CASE-TRACKER-KEY)

   April 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";
declare namespace request = "http://exist-db.org/xquery/request";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace services = "http://oppidoc.com/ns/services" at "../../lib/services.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Returns Enterprise sample
   ======================================================================
:)
declare function local:gen-enterprise-sample( $case as element() ) as element() {
  let $e := $case/Information/ClientEnterprise
  return
    <Enterprise> 
      {
      $e/@EnterpriseId,
      $case/@ProjectId,
      $case/Information/Acronym,
      <UID>{ $case/No/text() }</UID>,
      <Information>
        {
        $e/*
        }
      </Information>,
      let $po := fn:collection($globals:persons-uri)//Person[Id eq $case//ProjectOfficerRef]/UserProfile/Remote[@Name eq 'ECAS']
      return 
        if ($po) then
          <ProjectOfficerKey>{ $po/text() }</ProjectOfficerKey>
        else
          ()
    }
    </Enterprise>
};

(: ======================================================================
   Builds regular expression to filters names starting with letter
   or the empty sequence. If letter is not a single letter, then returns 
   a regexp that should match noting.
   ====================================================================== 
:)
declare function local:get-letter-re( $letter as xs:string ) as xs:string? {
  if ($letter ne '') then 
    if (matches($letter, "^[a-zA-Z]$")) then 
      let $l := concat('[', upper-case($letter), lower-case($letter), ']')
      return concat('^', $l, '|(.*\s', $l, ')')
    else
      "^$" (:no name should be empty:)
  else 
    ()
};

(: *** MAIN ENTRY POINT *** :)
let $submitted := oppidum:get-data()
let $errors := services:validate('cctracker', 'cctracker.enterprises', $submitted)
return
  if (empty($errors)) then
    let $search := services:unmarshall($submitted)
    let $re := if ($search/@Letter) then local:get-letter-re(string($search/@Letter)) else ()
    return
      <Enterprises Re="{$re}">
        {
        for $case in fn:collection($globals:cases-uri)//Case[Information/Call/Date = $search/Call/Date]
        where (empty($re) or matches($case/Information/ClientEnterprise/Name, $re))
        return local:gen-enterprise-sample($case)
        }
      </Enterprises>
  else
    $errors

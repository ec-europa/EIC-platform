xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   CRUD controller to manage NeedsAnalysis document into Case workflow.

   DEPRECATED

   November 2014 - (c) Copyright may be reserved
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Validates submitted data.
   Returns a list of errors to report or the empty sequence.
   ======================================================================
:)
declare function local:validate-submission( $submitted as element() ) as element()* {
  let $errors := (
    )
  return $errors
};

declare function local:gen-information-for-writing( $submitted as element(), $case as element() ) {
  <NeedsAnalysis LastModification="{ current-dateTime() }">
    {( 
    $submitted/(DateOfContact | DateOfNeedsAnalysis | Context | Impact),
    <ContactPerson>{ $submitted/ContactPerson/PersonRef }</ContactPerson>,
    $submitted/(CompanyExpectations | MethodsForAnalysis)
    )}
  </NeedsAnalysis>
};

(: ======================================================================
   Updates Information document inside Case
   ======================================================================
:)
declare function local:save-information( $lang as xs:string, $submitted as element(), $case as element() ) {
  let $found := $case/NeedsAnalysis
  let $data := local:gen-information-for-writing($submitted, $case)
  return
    if ($found) then (
      update replace $found with $data,
      ajax:report-success('ACTION-UPDATE-SUCCESS', ())
    ) else (
      update insert $data into $case,
      ajax:report-success('ACTION-CREATE-SUCCESS', ())
    )
};

(: ======================================================================
   Returns Information document model either for viewing or editing
   depending on goal 'read' or 'update'
   
   FIXME: unreference contexts and impact vectors 
   ======================================================================
:)
declare function local:gen-information-for( $goal as xs:string, $case as element(), $lang as xs:string ) as element() {
  let $data := $case/NeedsAnalysis
  return
    if ($data) then
      <NeedsAnalysis>
        {( 
        $data/*
        )}
      </NeedsAnalysis>
    else (: should not happen ? :)
      <NeedsAnalysis>
        { $case/Information/ContactPerson }
      </NeedsAnalysis>
};

let $m := request:get-method()
let $cmd := oppidum:get-command()
let $lang := string($cmd/@lang)
let $case-no := tokenize($cmd/@trail, '/')[2]
return
  let $case := fn:collection($globals:cases-uri)/Case[No eq $case-no]
  return
    if ($case) then
      if ($m = 'POST') then
        let $submitted := oppidum:get-data()
        let $errors := local:validate-submission($submitted)
        return
          if (empty($errors)) then
              local:save-information($lang, $submitted, $case)
          else
            ajax:report-validation-errors($errors)
      else (: assumes GET :)
        local:gen-information-for(request:get-parameter('goal', 'read'), $case, $lang)
    else
      ajax:throw-error('CASE-NOT-FOUND', ())

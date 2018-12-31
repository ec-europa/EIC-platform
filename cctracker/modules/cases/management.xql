xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   CRUD controller to manage KAM assignment document into Case workflow

   See also formulars/case-management.xml

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
declare function local:validate-submission( $data as element() ) as element()* {
  let $errors := (
    )
  return $errors
};

(: ======================================================================
   Returns a forward element to include in Ajax response 
   FIXME: hard coded status, l14n
   ======================================================================
:)
declare function local:gen-forward-notification( $case as element(), $data as element() ) as element()* {
  if (access:assert-transition($case, '2', '3', $data)) then (
    <forward command="autoexec">ae-advance</forward>,
    <confirmation>Do you want to move to Needs Analysis now ?</confirmation>
    )
  else 
    ()
};

declare function local:gen-information-for-writing( $submitted as element(), $case as element(), $legacy as element()? ) {
  (:let $kam-ref := if ($submitted/SuggestedManagerRef) then $submitted/SuggestedManagerRef else $submitted/AccountManagerRef:)
  let $kam-ref := $submitted/AccountManagerRef
  return
    <Management LastModification="{ current-dateTime() }">
      {(
      if ($kam-ref) then
        <AccountManagerRef>{$kam-ref/text()}</AccountManagerRef>
      else
        (),
      if ($legacy/AccountManagerRef eq $kam-ref/text()) then (: no change, perists timestamp :)
        $legacy/(AssignedByRef | Date)
      else (
        misc:gen-current-person-id('AssignedByRef'),
        misc:gen-current-date('Date')
        ),
      $submitted/Comments,
      $submitted/Conformity
      )}
    </Management>
};

(: ======================================================================
   Updates Information document inside Case
   ======================================================================
:)
declare function local:save-information( $lang as xs:string, $submitted as element(), $case as element() ) {
  let $found := $case/Management
  let $data := local:gen-information-for-writing($submitted, $case, $found)
  let $forward := local:gen-forward-notification($case, $data)
  return
    if ($found) then (
      update replace $found with $data,
      ajax:report-success('ACTION-UPDATE-SUCCESS', (), (), $forward)
    ) else (
      update insert $data into $case,
      ajax:report-success('ACTION-CREATE-SUCCESS', (), (), $forward)
    )
};

(: ======================================================================
   Returns Information document model either for viewing or editing
   depending on goal 'read' or 'update'
   ======================================================================
:)
declare function local:gen-information-for( $goal as xs:string, $case as element(), $lang as xs:string ) as element() {
  let $data := $case/Management
  return
    if ($data) then
      <Management>
        {
        if ($goal eq 'read') then
          misc:unreference($data/*)
        else
          $data/*
        }
      </Management>
    else (: Lazy creation :)
      <Management/>
};

let $m := request:get-method()
let $cmd := oppidum:get-command()
let $lang := string($cmd/@lang)
let $goal := request:get-parameter('goal', 'read')
let $pid := tokenize($cmd/@trail, '/')[2]
let $project := fn:collection($globals:projects-uri)/Project[Id eq $pid]
let $case-no := tokenize($cmd/@trail, '/')[4]
let $case := $project/Cases/Case[No eq $case-no]
let $errors := access:pre-check-case($project, $case, $m, $goal, 'Management')
return
  if (empty($errors)) then
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
    $errors

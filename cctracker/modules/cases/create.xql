xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   CRUD controller for Case creation

   November 2014 - (c) Copyright may be reserved
   ----------------------------------------------- :)
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace compat = "http://oppidoc.com/oppidum/compatibility" at "../../../oppidum/lib/compat.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";
import module namespace workflow = "http://platinn.ch/coaching/workflow" at "../workflow/workflow.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Returns a confirmation message with eventually some warnings in case
   the need analysis is uncomplete. This allows to implement a two steps
   protocol for activity creation.
   ======================================================================
:)
declare function local:confirm-case-submission( $project as element(), $lang as xs:string ) as element()* {
  (: CRITERIA TO BE DEFINED :)
  let $all := $project/Information/Beneficiaries//PIC
  let $assigned := $all[. = $project/Cases/Case/PIC]
  return
    if (count($assigned) eq count($all)) then
      oppidum:throw-error("ALL_BENEF_HAVE_CASES", ())
    else if (count($project/Cases/Case) eq count($all)) then
      oppidum:throw-error("CUSTOM", "We cannot create more cases than the number of beneficiaries. Please use those already created." )
    else
      ()
      
  (:if (empty($needs)) then
    oppidum:throw-error("ACTIVITY-CREATE-MISS-NEED-ANALYSIS", ())
  else
    let $check := count($needs/Impact/*/*)
    let $author := display:gen-person-name($case/Management/AccountManagerRef/text(), $lang)
    return
      if ($check > 0) then
        oppidum:throw-message("ACTIVITY-CREATE-OK-CONFIRM", $author)
      else
        oppidum:throw-message("ACTIVITY-CREATE-MISS-CONFIRM", $author) :)
};

(: ======================================================================
   Returns a new Activity model
   Duplicates the needs analysis document for archiving purposes
   ======================================================================
:)
declare function local:gen-case-for-writing( $index as xs:integer, $case as element() ) {
  let $now := current-dateTime()
  let $date :=  substring(string($now),1,10)
  let $year := substring($date, 1, 4)
  return
    <Case>
      <No>{ $index }</No>
      <CreationDate>{ $date }</CreationDate>
      <StatusHistory>
        <CurrentStatusRef>1</CurrentStatusRef>
        <Status>
          <Date>{ $date }</Date>
          <ValueRef>1</ValueRef>
        </Status>
      </StatusHistory>
    </Case>
};

(: ======================================================================
   Creates an empty coaching activity inside case with a duplicated NeedsAnalysis from the Case
   ======================================================================
:)
declare function local:create-case( $lang as xs:string, $project as element(), $baseUrl as xs:string ) {
  let $cases := $project/Cases
  return
    if ($cases) then (: simple insertion into list :)
      let $index :=
        if ($cases/@LastIndex castable as xs:integer) then
          number($cases/@LastIndex) + 1
        else (: unlikely :)
          1
      let $case := local:gen-case-for-writing($index, $project)
      return
        (
        update insert $case into $cases,
        update value $cases/@LastIndex with $index,
        ajax:report-success-redirect('CASE-CREATED', string($index), concat($baseUrl, '/', $index))
        )
    else (: first one, creation of list of Activities :)
      let $case := local:gen-case-for-writing( 1, $project)
      let $cases :=
        <Cases LastIndex="1">
          { $case }
        </Cases>
      return
        (
        update insert $cases into $project,
        ajax:report-success-redirect('CASE-CREATED', '1', concat($baseUrl, '/1'))
        )
};

let $m := request:get-method()
let $cmd := oppidum:get-command()
let $lang := string($cmd/@lang)
let $pid := tokenize($cmd/@trail, '/')[2]
let $project := fn:collection($globals:projects-uri)/Project[Id eq $pid]
return
  if ($project) then
    let $transition := workflow:get-transition-for('Project', '1', '-1')
    let $omissions := workflow:validate-transition($transition, $project, (), ())
    return
      if (count($omissions) eq 0) then
        if (($m = 'POST') and access:check-user-can('create', 'Information', $project, (), ())) then
          (: uses current NeedsAnalysis data inside Case which should be the similar to submitted data :)
          let $confirm :=
            if (request:get-parameter('_confirmed', '0') = '0') then
              local:confirm-case-submission($project, $lang)
            else
              ()
          return
            if (empty($confirm)) then
              local:create-case($lang, $project, concat($cmd/@base-url, $cmd/@trail))
            else
              $confirm
        else
          oppidum:throw-error('FORBIDDEN', ())
      else if (count($omissions) gt 1) then
        let $explain :=
          string-join(
            for $o in $omissions
            let $e := ajax:throw-error($o, ())
            return $e/message/text(), '&#xa;&#xa;')
        return
          oppidum:throw-error(string($transition/@GenericError), concat('&#xa;&#xa;',$explain))
      else if (count($omissions) eq 1) then
        ajax:throw-error($omissions, ())
      else
        ()
  else
    ajax:throw-error('PROJECT-NOT-FOUND', ())

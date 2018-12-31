xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   CRUD controller to manage Assignment document inside Activity workflow.

   November 2014 - (c) Copyright may be reserved
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace persons = "http://oppidoc.com/ns/cctracker/persons" at "../persons/persons.xqm";
import module namespace services = "http://oppidoc.com/ns/services" at "../../lib/services.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Very first initialization of the FinalReportApproval model
   ====================================================================== 
:)
declare function local:bootstrap-final-report( $activity as element()) {
  let $report := $activity/FinalReportApproval
  return
    if ($report) then
      $report
    else
      update insert <FinalReportApproval/> into $activity
};

(: ======================================================================
  Update assigned coach (which is an email here) with the coach'id after the import
  
  Parameters:
    - Submitted: Content from the formular
    - Coach account
   ======================================================================
:)
declare function local:update-submitted-coach-assigned($submitted as element(), $coach as element()) {
  (:update replace $submitted/ResponsibleCoachRef with <ResponsibleCoachRef>{ $coach/Id/text() }</ResponsibleCoachRef>:)
  <Assignement>
    {
      $submitted/*[local-name(.) ne 'ResponsibleCoachRef'],
      <ResponsibleCoachRef>{ $coach/Id/text() }</ResponsibleCoachRef>
    }
  </Assignement>
};

(: ======================================================================
   Automatic coatch import process
   Happen when a coach is not imported yet
   It's triggered after the user click on save button in the editor form
   
   Parameters:
      - $submitted: The informations filled in the editor by the KAM
   ======================================================================
:)
declare function local:import-coach( $submitted as element() ) as element()? {  
  if ($submitted/ResponsibleCoachRef[contains(text(),'@')]) then
    let $payload := <Export Format="profile"><Email>{ normalize-space($submitted/ResponsibleCoachRef/text()) }</Email></Export>
    let $coaches := services:post-to-service('ccmatch-public', 'ccmatch.export', $payload, "200")
    return
      if (local-name($coaches) ne 'error') then
        if (exists($coaches//Coach)) then 
          let $imported := $coaches//Coach[1]
          let $newkey := 
            max(for $key in fn:collection($globals:persons-uri)//Person/Id
            return if ($key castable as xs:integer) then number($key) else 0) + 1
          let $person :=
          <Person>
            <Id>{ $newkey }</Id>
            { 
            $imported/(Sex | Civility | Name | Contacts),
            if ($imported/Country) then
             <Address>{ $imported/Country }</Address>
            else
             (),
            <External><Remote>{ $imported/Remote/text() }</Remote><Realm>{ string($imported/Remote/@Name) }</Realm></External>
            }
            <UserProfile>
              <Roles>
                <Role>
                  <FunctionRef>4</FunctionRef>                    
                </Role>
              </Roles>
            </UserProfile>
          </Person>
          return
            (: Creation of the person in database :)
            let $creation := persons:create-person-in-collection($person, $newkey)
            let $createdPerson := fn:collection($globals:persons-uri)//Person[Id/text() = string($newkey)]
            return              
              $createdPerson
        else
          oppidum:throw-error('CUSTOM', concat('Coach import failure from CoachMatch using the following e-mail address "', $submitted/ResponsibleCoachRef/text(),'"'))
      else
        oppidum:throw-error('CUSTOM', concat('Coach import failure - CoachMatch unreachable'))
  else
    ()
};


(: ======================================================================
   Validates submitted data.
   Proceed to the automatic import of a coach if it's needed
   Returns a list of errors to report or the empty sequence.
   ======================================================================
:)
declare function local:validate-submission( $submitted as element() ) as element()* {
  if (string-length(normalize-space(string-join($submitted/Description/Text, ' '))) > 1000) then
    let $length := string-length(normalize-space(string-join($submitted/Description/Text, ' ')))
    return
      oppidum:throw-error('CUSTOM', concat("The commentary associated to the SME's expectation contains ", $length, ' characters; you must remove at least ', $length - 1000, ' characters to remain below 1000 characters'))
  else
    let $createdCoach := local:import-coach($submitted)
        return
          if (local-name($createdCoach) eq 'error') then
            $createdCoach
          else if (exists($createdCoach)) then (: New coach :)
            local:update-submitted-coach-assigned($submitted, $createdCoach)
          else (: existing coach return the original $submitted :)
            $submitted
};

(: ======================================================================
   Returns a forward element to include in Ajax response
   FIXME: hard coded status, l14n
   ======================================================================
:)
declare function local:gen-forward-notification( $case as element(), $activity as element(), $data as element() ) as element()* {
  if (access:assert-transition($case, $activity, '1', '2', $data)) then
    (
    <forward command="autoexec">ae-advance</forward>,
    <confirmation>Do you want to move to Coaching plan now ?</confirmation>
    )
  else 
    ()
};

(: ======================================================================
   Returns Assignment document for saving from submission
   ======================================================================
:)
declare function local:gen-assignment-for-writing( $submitted as element() ) {
  <Assignment LastModification="{ current-dateTime() }">
   {
    misc:filter($submitted/*[not(local-name() = 'KAMReportCAProxy')], ('SuggestedCoachRef')),
    misc:gen-current-person-id('AssignedByRef'),
    misc:gen-current-date('Date')
   }
  </Assignment>
};

(: ======================================================================
   Replaces Assignment document inside existing activity inside case
   FIXME: pass $forward to misc:save-content
   ======================================================================
:)
declare function local:save-assignment( $lang as xs:string, $submitted as element(), $case as element(), $activity as element() ) {
  let $data := local:gen-assignment-for-writing($submitted)
  let $forward := local:gen-forward-notification($case, $activity, $data)
  let $report := local:bootstrap-final-report($activity)
  let $res_ass := misc:save-content($activity, $activity/Assignment, $data)
  let $res_prof := misc:save-proxy($activity, $submitted/KAMReportCAProxy) 
  return 
    if (local-name($res_ass) eq 'success') then
      <success>
       {
         $res_ass/*,
         $forward
       }
      </success>
    else
      $res_ass (: one can do better : mix both <error/> possibly returned :)
      
};

(: ======================================================================
   Returns Assignment document model either for viewing or editing
   depending on goal 'read' or 'update'

   FIXME: unreference contexts and impact vectors
   ======================================================================
:)
declare function local:gen-assignment-for( $goal as xs:string, $activity as element(), $lang as xs:string ) as element() {
  <Assignment>
   { misc:unreference($activity/Assignment/*) }
   { misc:read-proxy-doc($activity,'KAMReportCAProxy') }
  </Assignment>
};

let $m := request:get-method()
let $cmd := oppidum:get-command()
let $lang := string($cmd/@lang)
let $pid := tokenize($cmd/@trail,'/')[2]
let $case-no := tokenize($cmd/@trail,'/')[4]
let $activity-no := tokenize($cmd/@trail,'/')[6]
let $project := fn:collection($globals:projects-uri)//Project[Id eq $pid]
let $case := $project/Cases/Case[No eq $case-no]
let $activity := $case/Activities/Activity[No = $activity-no]
let $goal := request:get-parameter('goal', 'read')
let $errors := access:pre-check-activity($project, $case, $activity, $m, $goal, 'Assignment')
return
  if (empty($errors)) then
    if ($m = 'POST') then
      let $submitted := oppidum:get-data()
      let $newSubmitted := local:validate-submission($submitted)
      return
        if (local-name($newSubmitted) eq 'error') then
          ajax:report-validation-errors($errors)
        else
          local:save-assignment($lang, $newSubmitted, $case, $activity)
    else (: assumes GET on assignment :)
        local:gen-assignment-for(request:get-parameter('goal', 'read'), $activity, $lang)
  else
    $errors

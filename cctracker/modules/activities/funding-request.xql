xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Simple CRUD controller to manage FundingRequest document into Activity workflow.

   November 2014 - (c) Copyright may be reserved
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Returns information to display in document's ContractData
   not directly found in FundingRequest

   <MaxContractValue>60000</MaxContractValue>
   <MaxNbOfDays>120</MaxNbOfDays>
   <MaxNbOfHours>8</MaxNbOfHours>
   <DailyRate>450</DailyRate>
   ======================================================================
:)
declare function local:gen-contract-data( $case as element(), $activity as element(), $lang as xs:string ) as element()* {
  <ContractData>
    <HourlyRate>56.25</HourlyRate>
  </ContractData>
};

(: ======================================================================
   Validates submitted data.
   Returns a list of errors to report or the empty sequence.
   ======================================================================
:)
declare function local:validate-submission( $case as element(), $activity as element(), $submitted as element() ) as element()* {
  if (string-length(normalize-space(string-join($submitted/Objectives/Text, ' '))) > 1000) then
    let $length := string-length(normalize-space(string-join($submitted/Objectives/Text, ' ')))
    return
      oppidum:throw-error('CUSTOM', concat('The description of the coaching objectives contains ', $length, ' characters; you must remove at least ', $length - 1000, ' characters to remain below 1000 characters'))
  else 
    for $t in $submitted/Budget//Task
    let $l := string-length(normalize-space($t/Description))
    where $l > 200
    return 
      oppidum:throw-error('CUSTOM', concat('The task n°', index-of($submitted/Budget//Task, $t),' contains ', $l, ' characters; you must remove at least ', $l - 200, ' characters to remain below 200 characters'))
};

(: ======================================================================
   Generates a new document to write from submitted and legacy data

   REMOVED
   <FinancialStatement LastModification="{ current-dateTime() }">
     {
     $submitted/FinancialStatement/CurrentActivity/(Hours | Fee | Travel | Allowance | Accomodation | Total)
     }
   </FinancialStatement>
   ======================================================================
:)
declare function local:gen-document-for-writing( $case as element(), $activity as element(), $submitted as element() ) {
  <FundingRequest LastModification="{ current-dateTime() }">
    { $submitted/(Conformity | ConformitySimplified) }
    { $submitted/Objectives }
    { $submitted/Budget }
    <SME-Agreement>
      {
      $activity/FundingRequest/SME-Agreement/(Date | SentByRef),
      $submitted/SME-Agreement/YesNoScaleRef
      }
    </SME-Agreement>
    { $submitted/Comments }
  </FundingRequest>
};

(: ======================================================================
   Updates document inside Activity
   Note: systematically returns a forward element without asserting 
   that transition is possible, this is on purpose so that user will 
   get an error message with explanation if s/he confirms the transition
   ======================================================================
:)
declare function local:save-document( $case as element(), $activity as element(), $submitted as element(), $lang as xs:string ) {
  let $data := local:gen-document-for-writing($case, $activity, $submitted)
  let $forward := 
    if ('submit' = request:get-parameter-names()) then 
      <forward command="autoexec">ae-advance</forward>
    else
      ()
  return
      misc:save-content($activity, $activity/FundingRequest, $data, $forward)
};

(: ======================================================================
   Returns document model either for viewing or editing based on 'read' or 'update' goal
   ======================================================================
:)
declare function local:gen-document-for( $case as element(), $activity as element(), $goal as xs:string, $lang as xs:string ) as element() {
  let $data := $activity/FundingRequest
  return
    if ($data) then
      <FundingRequest>
        { misc:unreference($data/( Conformity | ConformitySimplified) ) }
        { $data/Objectives }
        { $data/Budget }
        { local:gen-contract-data($case, $activity, $lang) }
        { misc:unreference($data/SME-Agreement) }
        { $data/Comments }
      </FundingRequest>
    else (: lazy creation :)
      <FundingRequest>
        { local:gen-contract-data($case, $activity, $lang) }
      </FundingRequest>
};

(: *** MAIN ENTRY POINT *** :)
let $m := request:get-method()
let $cmd := oppidum:get-command()
let $lang := string($cmd/@lang)
let $pid := tokenize($cmd/@trail, '/')[2]
let $project := fn:collection($globals:projects-uri)/Project[Id eq $pid]
let $case-no := tokenize($cmd/@trail, '/')[4]
let $case := $project/Cases/Case[No eq $case-no]
let $activity-no := tokenize($cmd/@trail,'/')[6]
let $activity := $case/Activities/Activity[No = $activity-no]
let $goal := request:get-parameter('goal', 'read')
let $errors := access:pre-check-activity($project, $case, $activity, $m, $goal, 'FundingRequest')
return
  if (empty($errors)) then
    if ($m = 'POST') then
      let $submitted := oppidum:get-data()
      let $errors := local:validate-submission($case, $activity, $submitted)
      return
        if (empty($errors)) then
            local:save-document($case, $activity, $submitted, $lang)
        else
          ajax:report-validation-errors($errors)
    else (: assumes GET :)
      local:gen-document-for($case, $activity, $goal, $lang)
  else
    $errors

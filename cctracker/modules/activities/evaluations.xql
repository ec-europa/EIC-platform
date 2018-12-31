xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creation: Frédéric Dumonceaux <fred.dumonceaux@gmail.com>

   Simple CRUD controller to manage SME feedback process 
   (with Order and Answers documents) into Activity workflow.

   April 2016 - (c) Copyright may be reserved
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace xdb = "http://exist-db.org/xquery/xmldb";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace account = "http://platinn.ch/coaching/account" at "../users/account.xqm";
import module namespace evaluation = "http://oppidoc.com/ns/cctracker/evaluation" at "evaluation.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   COPIED from Poll application (!)
   ======================================================================
:)
declare function local:genPollDataForEditing ( $nodes as item()* ) as item()* {
  for $node in $nodes
  return
    typeswitch($node)
      case text()
        return $node
      case attribute()
        return $node
      case element() return
        if ($node/@For) then
          let $suffix := string($node/@For)
          return
            if (local-name($node) eq 'Comment') then
              element { concat(local-name($node), '_', $suffix) }
                {
                $node/text()
                }
            else (: Assuming entry node is amongst (RatingScaleRef, SupportScaleRef, CommunicationAdviceRef) :)
              element { concat('Likert_', local-name($node), '_', $suffix) }
                {
                $node/text()
                }
        else
          element { local-name($node) }
            { local:genPollDataForEditing($node/(attribute()|node())) }
      default return $node
};

(: ======================================================================
   Returns KAM report document model either for viewing or editing
   based on 'read' or 'update' goal
   ======================================================================
:)
declare function local:gen-final-report-approval-for( $case as element(), $activity as element(), $lang as xs:string ) as element() {
  let $data := $activity/FinalReportApproval
  return
    <FinalReportApproval>
      {
      if ($data) then
        misc:unreference($data/*[not(local-name(.) = ('CoachingAssistantVisa', 'CoachingManagerVisa'))])
      else (: lazy creation :)
        ()
      }
    </FinalReportApproval>
};

(: ======================================================================
   Returns Coaching Report document model either for viewing or editing 
   based on 'read' or 'update' goal
   ======================================================================
:)
declare function local:gen-final-report-for( $case as element(), $activity as element(), $lang as xs:string ) as element() {
  let $data := $activity/FinalReport
  return
    <FinalReport>
      {
      if ($data) then misc:unreference($data/*) else (),
      misc:unreference($case/Information/ClientEnterprise/TargetedMarkets[TargetedMarketRef])
      }
    </FinalReport>
};

(: ======================================================================
   Returns Order or Answers document model depending on root and Activity status
   ======================================================================
:)
declare function local:gen-document-for( $case as element(), $activity as element(), $lang as xs:string ) as element() {
  <Evaluations>
    {
    local:gen-final-report-for($case, $activity, $lang),
    local:gen-final-report-approval-for($case, $activity, $lang),
    let $data := $activity/Evaluation
    return
      local:genPollDataForEditing($data/Order[Questionnaire/text() eq 'cctracker-sme-feedback']/Answers)
    }
  </Evaluations>
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
let $goal := 'read' (: simple read :)
let $errors := access:pre-check-activity($project, $case, $activity, 'GET', $goal, 'Evaluations')
return
  if (empty($errors)) then
    local:gen-document-for($case, $activity, $lang)
  else
    $errors

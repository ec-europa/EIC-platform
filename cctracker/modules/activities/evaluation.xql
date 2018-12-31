xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Simple CRUD controller to manage SME feedback process 
   (with Order and Answers documents) into Activity workflow.

   February 2015 - (c) Copyright may be reserved
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
   Returns Order or Answers document model depending on root and Activity status
   ======================================================================
:)
declare function local:gen-document-for( $case as element(), $activity as element(), $root as xs:string, $lang as xs:string ) as element() {
  let $data := $activity/Evaluation
  return
    if ($data) then
      if ($root eq 'Order') then
        let $sme-evaluated := $data/Order[Questionnaire/text() eq 'cctracker-sme-feedback']/Answers
        let $kam-evaluated := $data/Order[Questionnaire/text() eq 'cctracker-kam-feedback']/Answers
        return
          <Order>
            <TitleSME>{ if ($sme-evaluated) then 'SME Completed' else if ($data/Order[Questionnaire/text() eq 'cctracker-sme-feedback']) then 'SME In progress...' else 'No feedback questionnaire sent to SME contact' }</TitleSME>
            <TitleKAM>{ if ($kam-evaluated) then 'KAM Completed' else if ($data/Order[Questionnaire/text() eq 'cctracker-kam-feedback']) then 'KAM In progress...' else 'No feedback questionnaire sent to KAM' }</TitleKAM>
            <SentSME>
              {
              $data/Order[Questionnaire/text() eq 'cctracker-sme-feedback']/Email,
              misc:unreference($data/Order[Questionnaire/text() eq 'cctracker-sme-feedback']/Date)
              }
            </SentSME>
            {
              if ($sme-evaluated) then
                <CompletedSME>
                  <Email>{ $sme-evaluated/ContactEmail/text() }</Email>
                  <Date>{ display:gen-display-date(substring($sme-evaluated/@LastModification, 1, 10), 'en') }</Date>
                </CompletedSME>
              else
                ()
            }
            <SentKAM>
              {
              $data/Order[Questionnaire/text() eq 'cctracker-kam-feedback']/Email,
              misc:unreference($data/Order[Questionnaire/text() eq 'cctracker-kam-feedback']/Date)
              }
            </SentKAM>
            {
              if ($kam-evaluated) then
                <CompletedKAM>
                  <Email>{ $kam-evaluated/ContactEmail/text() }</Email>
                  <Date>{ display:gen-display-date(substring($kam-evaluated/@LastModification, 1, 10), 'en') }</Date>
                </CompletedKAM>
              else
                ()
            }
          </Order>
      else if ($root and $data/Order[Questionnaire/text() eq concat('cctracker-',$root)]/Answers) then (: assuming any root different from 'Order': either 'sme-feedback' or 'kam-feedback' answers :) 
          local:genPollDataForEditing($data/Order[Questionnaire/text() eq concat('cctracker-',$root)]/Answers)
      else (: order sent but no reply from poll :)
          <Answers/>
    else (: lazy creation :)
      if ($root eq 'Order') then
        <Order>
          <TitleSME>No feedback questionnaire sent to SME contact</TitleSME>
          <TitleKAM>No feedback questionnaire sent to KAM</TitleKAM>
        </Order>
      else
        <Answers/>
};

(: *** MAIN ENTRY POINT *** :)
let $m := request:get-method()
let $cmd := oppidum:get-command()
return
  if ($m = 'POST') then (: Oppidum TODO: test at mapping level :)
    if ($cmd/resource/@name = ('sme-feedback','kam-feedback')) then
      let $submitted := oppidum:get-data()
      return
        (: FIXME: store credentials in settings in database and not in code ? :)
        if (local-name($submitted) eq 'Order') then
          system:as-user(account:get-secret-user(), account:get-secret-password(), evaluation:submit-answers($submitted))
        else if (local-name($submitted) eq 'Assess') then
          system:as-user(account:get-secret-user(), account:get-secret-password(), evaluation:assess-order($submitted/Order))
        else
          oppidum:throw-error("VALIDATION-FORMAT-ERROR", ())
    else
      oppidum:throw-error("URI-NOT-FOUND", ())
  else (: assumes GET :)
    let $lang := string($cmd/@lang)
    let $pid := tokenize($cmd/@trail, '/')[2]
    let $project := fn:collection($globals:projects-uri)/Project[Id eq $pid]
    let $case-no := tokenize($cmd/@trail, '/')[4]
    let $case := $project/Cases/Case[No eq $case-no]
    let $activity-no := tokenize($cmd/@trail,'/')[6]
    let $activity := $case/Activities/Activity[No = $activity-no]
    let $goal := 'read' (: simple read :)
    let $root := if ($cmd/resource/@name = ('sme-feedback','kam-feedback')) then string($cmd/resource/@name) else 'Order'
    let $errors := access:pre-check-activity($project, $case, $activity, 'GET', $goal, $root)
    return
      if (empty($errors)) then
        local:gen-document-for($case, $activity, $root, $lang)
      else
        $errors

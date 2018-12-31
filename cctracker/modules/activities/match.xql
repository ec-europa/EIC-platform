xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Adapter controller to generate payload to call 3rd party Coach Match
   coach suggestion tunnel with a given coach assignment configuration
   from an Activity

   The generated payload is inserted in an HTML input form by case tracker
   client side code, then submitted via a POST to CoachMatch to open
   the coach suggestion tunnel in a new window.

   NOTE: insert Analytics/UID (SMEIMNT-310) to save request in CoachMatch
   analytics

   October 2015 - (c) Copyright may be reserved
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
import module namespace services = "http://oppidoc.com/ns/services" at "../../lib/services.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Converts coach Assignment Weights preferences to Ratings to serve as
   input for Coach Match coach suggestion tunnel
   Converts <Weights><{Root}-X>Z</{Root}-X>*</Weights>
   to <CaseImpacts><Rating_X_Y>Z</Rating_X_Y>*</CaseImpacts>
   FIXME: directly convert to Skills matrix (see CoachMatch suggest/match.xqm) ?
   ======================================================================
:)
declare function local:weights-to-ratings( $weights as element() ) as element() {
  <CaseImpacts>
    {
    for $w in $weights/*
    let $root := substring-before(local-name($w), '-')
    let $subsection := substring-after(local-name($w), '-')
    let $section := fn:collection($globals:global-info-uri)//Description[@Lang = 'en']/CaseImpact/Sections/Section[SectionRoot eq $root]
    return
      element { concat('Rating_', $section/Id, '_', $subsection) } {
        $w/text()
      }
    }
  </CaseImpacts>
};

(: *** MAIN ENTRY POINT *** :)
let $submitted := oppidum:get-data()
let $cmd := oppidum:get-command()
let $lang := string($cmd/@lang)
let $project-no := tokenize($cmd/@trail, '/')[2]
let $case-no := tokenize($cmd/@trail, '/')[4]
let $activity-no := tokenize($cmd/@trail, '/')[6]
let $project := fn:collection($globals:projects-uri)/Project[Id eq $project-no]
let $case := $project/Cases/Case[No eq $case-no]
let $activity := $case/Activities/Activity[No = $activity-no]
let $errors := () (:access:pre-check-activity($case, $activity, 'GET', $goal, $root):)
return
  if (empty($errors)) then
    services:gen-envelope-for('ccmatch-public', 'ccmatch.suggest',
      <Match>
        { services:get-key-for('ccmatch-public', 'ccmatch.suggest') }
        <SearchByFit>
          { $project/Information/Title }
          { $project/Information/Acronym }
          { local:weights-to-ratings($submitted/Weights) }
          <Stats>
            {
            (: since there is one Case per beneficiary stats are stored at the Project level :)
            let $cie := $project/Information/Beneficiaries/(Coordinator|Partner)[PIC eq $case/PIC]
            return $cie/(DomainActivityRef | TargetedMarkets)
            }
          </Stats>
          <Context>
            { $case/NeedsAnalysis/Context/(InitialContextRef | TargetedContextRef) }
          </Context>
          { $submitted/ServiceRef }
        </SearchByFit>
        <Analytics>
          <UID>{ collection($globals:persons-uri)//Person[UserProfile/Remote = oppidum:get-current-user()]/Id/text() }</UID>
          <Project>{ $project-no }</Project>
          <Case>{ $case-no }</Case>
          <Activity>{ $activity-no }</Activity>
        </Analytics>
      </Match>
      )
  else
    $errors

(:
    Sample input :

    <Assignment>
      <Weights>
        <Vectors-2>3</Vectors-2>
        <Resources-1>3</Resources-1>
        <Resources-2>3</Resources-2>
        <Resources-10>2</Resources-10>
        <Resources-9>2</Resources-9>
      </Weights>
      <ServiceRef>2</ServiceRef>
    </Assignment>
:)

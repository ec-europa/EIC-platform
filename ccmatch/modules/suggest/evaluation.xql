xquery version "1.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Returns individual coach evaluation against SME Profile

   To be called from third party applications like Case Tracker

   Implements XML protocol via services API :

   POST
      <Match>
        <Key>host key</Key>
        <SearchByFit>
          <CaseImpacts>
          <Stats>
            <DomainActivityRef>
            <TargetedMarkets>
              <TargetedMarketRef>*
          <Context>
            <InitialContextRef>
            <TargetedContextRef>
          <ServiceRef>

   September 2015 - (c) Copyright may be reserved
   ----------------------------------------------- :)

declare namespace json="http://www.json.org";

declare namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace match = "http://oppidoc.com/ns/match" at "match.xqm";
import module namespace misc = "http://oppidoc.com/ns/misc" at "../../lib/util.xqm";
import module namespace analytics = "http://oppidoc.com/ns/analytics" at "../../../excm/modules/analytics/analytics.xqm";

declare option exist:serialize "method=json media-type=application/json";

let $user := oppidum:get-current-user()
let $submitted := match:get-data($user, 'ccmatch.suggest')
let $cmd := request:get-attribute('oppidum.command')
let $uuid := request:get-parameter('uuid', ())
let $coach-id := string($cmd/resource/@name)
let $person := fn:collection($globals:persons-uri)//Person[Id eq $coach-id] (: TODO: fine grain access control by Host :)
return
  if ($person) then
    if (exists($submitted/SearchByFit)) then (: Validation - FIXME: weak :)
      <MatchResults>
        <Coach>
          <Id>{ $coach-id }</Id>
          { 
          analytics:record-event($uuid, 'Evaluate', $coach-id),
          $person/Information/Name,
          if ($person/CurriculumVitae/Summary) then (: normalizes to avoid JSON chars parsing error :)
            <Summary>{ normalize-space($person/CurriculumVitae/Summary) }</Summary>
          else (: this should be done when saving misc:sanitize ? :)
            (),
          misc:gen-link($person/Knowledge/CV_Link | $person/Knowledge/CV-Link),  (: FIXME: remove CV_Link :)
          if ($person/Resources/CV-File) then 
            <CV-File>{ $coach-id }/cv/{ $person/Resources/CV-File/text() }</CV-File>
          else
            (),
          (: Generates competences dimension :)
          let $weights := $submitted//CaseImpacts
          let $competences := match:weights-to-skills-matrix($weights)
          return
            match:get-competences-fit('competence', $person, $competences),
          (: Generates experiences (sme context) dimension :)
          let $sme := $submitted/SearchByFit
          let $experiences := match:sme-context-to-skills-matrix($sme)
          return
            match:get-experiences-fit('experience', $person, $experiences)
          }
        </Coach>
      </MatchResults>
    else
      oppidum:throw-error('BAD-REQUEST', ())
  else
    oppidum:throw-error('URI-NOT-FOUND', ())

xquery version "1.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Implements Ajax protocol to display a handout for coaches in a shortlist 
   evaluated against an SME context. 

   Returns a handout XML model to be transformed into printable HTML code 
   with handout.xsl

   Input when called as a service (cm-suggest.js) :

      <Match>
        <Key>host key</Key>
        <Handout>
          <ShortList>...</ShortList>
          <SearchByFit>...SME context...</SearchByFit>
        </Handout>
      </Match>

   Input when called directly from Coach Match (authentified user, cm-search.js) :

        <Handout>
          <ShortList>...</ShortList>
          <SearchByFit>...SME context...</SearchByFit>
        </Handout>

   TODO:
   - create minimalistic match:get-competences-fit to compute only axis

   October 2015 - (c) Copyright may be reserved
   ----------------------------------------------- :)

declare namespace request = "http://exist-db.org/xquery/request";
declare namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace util="http://exist-db.org/xquery/util";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace misc = "http://oppidoc.com/ns/misc" at "../../lib/util.xqm";
import module namespace match = "http://oppidoc.com/ns/match" at "match.xqm";
import module namespace analytics = "http://oppidoc.com/ns/analytics" at "../../../excm/modules/analytics/analytics.xqm";

(: ======================================================================
   Generates coach XML data for handout display
   ====================================================================== 
:)
declare function local:gen-coach( $coach-ref as xs:string, $competences as element()? ) as element() {
  <Coach>
    {
    let $person := fn:collection($globals:persons-uri)//Person[Id eq $coach-ref]
    return
      if ($person) then (
        if ($person/Resources/Photo) then 
          <Photo>{ $coach-ref }/photo/{ $person/Resources/Photo/text() }</Photo>
        else
          <Photo/>,
        $person/Information/Civility,
        <Name>{ display:gen-person-name($person, 'en') }</Name>,
        $person/CurriculumVitae/Summary,
        $person/Information/Contacts/(Email | Phone | Mobile | Skype),
        (: FIXME: CV_Link in import :)
        if ($person/Knowledge/CV_Link) then
          <CV-Link>{ $person/Knowledge/CV_Link/text() }</CV-Link>
        else if ($person/Knowledge/CV-Link) then
          <CV-Link>{ $person/Knowledge/CV-Link/text() }</CV-Link>
        else
          (),
        if ($person/Knowledge//ServiceYearRef[. ne '']) then
          <Experience>
            {
            misc:gen_display_name($person/Knowledge/IndustrialManagement/ServiceYearRef, 'IndustrialManagement'),
            misc:gen_display_name($person/Knowledge/BusinessCoaching/ServiceYearRef, 'BusinessCoaching')
            }
          </Experience>
        else
          (),
        misc:unreference($person/Information/Address),
        <Languages>{ display:gen-name-for('EU-Languages', $person//EU-LanguageRef, 'en') }</Languages>,
        <Competence>
          {
            let $axis := <Radar>{ match:get-competences-fit('competence', $person, $competences)//Axis }</Radar>
            return util:serialize($axis, 'method=json')
          }
        </Competence>
        )
      else
        <Unkown>{ $coach-ref }</Unkown>
    }
  </Coach>
};

(: ======================================================================
   Generates handout XML model
   TODO: check each coach preferences to avoid Javascript CoachRef injection (!)
   ====================================================================== 
:)
declare function local:gen-handout ( $shortlist as element(), $sme-profile as element(), $host-ref as xs:string ) as element() {
  (: Generates competences dimension :)
  let $weights := $sme-profile/CaseImpacts
  let $competences := match:weights-to-skills-matrix($weights)
  return
    <Handout>
      {
      $sme-profile/(Acronym | Title),
      for $c in $shortlist/CoachRef
      return local:gen-coach($c, $competences)
      (:oppidum:throw-error('CUSTOM', 'no short list !'):)
    }
    </Handout>
};

let $user := oppidum:get-current-user()
let $request := match:get-data($user, 'ccmatch.suggest')
let $uuid := request:get-parameter('uuid', ())
return
  if (local-name($request) ne 'error') then
    let $host := match:get-host($user, $request/Key)
    return
      if (local-name($host) ne 'error') then
        if ($host ne '0') then (: handout in a case tracker suggestion for coaching :) 
          (
          analytics:record-event($uuid, 'Handout', string-join($request/Handout/ShortList/CoachRef, " ")),
          local:gen-handout($request/Handout/ShortList, $request/Handout/SearchByFit, $host)
          )
        else (: handout in coach match search context :)
          local:gen-handout($request/ShortList, $request/SearchByFit, $host)
      else
        $host
  else
    $request

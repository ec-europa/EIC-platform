xquery version "1.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Returns coach profile model for display into coach search tunnel

   November 2015 - (c) Copyright may be reserved
   ----------------------------------------------- :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";
declare namespace request = "http://exist-db.org/xquery/request";

import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace match = "http://oppidoc.com/ns/match" at "match.xqm";
import module namespace misc = "http://oppidoc.com/ns/misc" at "../../lib/util.xqm";

declare function local:localize-iter( $skills as element(), $dico as element() ) as element()? {
  let $id-name := string($dico/@Value)
  let $group := $dico/Group[*[local-name(.) eq $id-name][. eq $skills/@For]]
  let $name := $group/Name
  return
    if ($skills//Skill[. = ('2', '3')]) then
      <Skills For="{$name}">
        {
        for $c in $skills/Skill[ . = ('2', '3')]
        return
          let $name := $group//Option[*[local-name(.) eq $id-name][. eq $c/@For]]/Name
          return
            <Skill For="{$name}">{ $c/text() }</Skill>
        }
      </Skills>
    else
      ()
};

(: ======================================================================
   Localizes a Skills matrix
   ======================================================================
:)
declare function local:localize-skills-skills( $skills as element()?, $title as xs:string ) {
  let $dico := fn:collection($globals:global-info-uri)//Description[@Lang eq 'en']/Selector[@Name eq $skills/@For]
  return
    <Skills Title="{$title}">
      {
      $skills/@For,
      for $c in $skills/Skills
      return local:localize-iter($c, $dico)
      }
    </Skills>
};

declare function local:localize-skills( $skills as element()?, $title as xs:string ) as element()? {
  let $group := fn:collection($globals:global-info-uri)//Description[@Lang eq 'en']/Selector[@Name eq $skills/@For]
  return
    <Skills Title="{$title}">
      {
      if ($skills/Skill[. = ('2', '3')]) then
        for $c in $skills/Skill[ . = ('2', '3')]
        return
          let $name := $group//Option[Id eq $c/@For]/Name
          return
            <Skill For="{$name}">{ $c/text() }</Skill>
      else
        ()
      }
    </Skills>
};

declare function local:gen-coach( $coach-ref as xs:string, $person as element(), $mode as xs:string? ) as element() {
  <Inspect>
    { if ($mode) then attribute { 'Mode' } { $mode } else () }
    <Coach>
      <Id>{ $coach-ref }</Id>
      <Name>{ display:gen-person-name($person, 'en') }</Name>
      {
      $person/CurriculumVitae/Summary,
      misc:gen-link($person/Knowledge/CV_Link | $person/Knowledge/CV-Link),  (: FIXME: remove CV_Link :)
      $person/Resources/CV-File,
      misc:gen_display_name($person/Knowledge/SpokenLanguages/EU-LanguageRef, 'SpokenLanguages'),
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
      local:localize-skills-skills($person/Skills[@For = 'CaseImpacts'], "Competences related to the business innovation system"),
      local:localize-skills-skills($person/Skills[@For = 'DomainActivities'], "Experience related to industrial sectors (Nace code)"),
      local:localize-skills-skills($person/Skills[@For = 'TargetedMarkets'], "Experience related to targeted markets (Thomson Reuters classification)"),
      local:localize-skills($person/Skills[@For = 'LifeCycleContexts'], "Experience related to company's life cycle stages"),
      local:localize-skills($person/Skills[@For = 'Services'], "Experience related to coaching services")
    }
    </Coach>
  </Inspect>
};

declare function local:gen-coach-from-host( $id as xs:string?, $user as xs:string, $groups as xs:string*, $host as xs:string, $mode as xs:string? ) {
  if ($id) then
    let $person := fn:collection($globals:persons-uri)//Person[Id eq $id]
    return
    if (match:assert-coach($person, $host)) then
        local:gen-coach($id, $person, $mode)
      else
        oppidum:throw-error('FORBIDDEN', ())
  else
    oppidum:throw-error('NOT-FOUND', ())
};

let $cmd := request:get-attribute('oppidum.command')
let $m := request:get-method()
let $user := oppidum:get-current-user()
let $groups := oppidum:get-user-groups($user, oppidum:get-current-user-realm())
let $target := $cmd/resource/@name
return
  if (($target eq 'inspect') and ($m eq 'POST')) then  (: calling from 3rd party application :)
    let $request := match:get-data('guest', 'ccmatch.inspect')
    return
      if (local-name($request) ne 'error') then
        let $host := match:get-host($user, $request/Key) (: TODO: 'ccmatch.inspect' :)
        return
          if (local-name($host) ne 'error') then
            local:gen-coach-from-host($request/CoachRef, 'guest', (), $host, ())
          else
            $host
      else
        $request
  else if (($user ne 'guest') and not(ends-with(request:get-header('Referer'), '/suggest'))) then 
    (: authentified user calling from Coach Match search by criteria :)
    local:gen-coach-from-host($target, $user, $groups, '0', ())
  else 
    (: guest or user calling from third party application :)
    (: TODO : use service API for access control ! Referer :)
    let $person := access:get-person($target, $user, $groups)
    return 
      if (local-name($person) ne 'error') then
        local:gen-coach($target, $person, 'embed')
      else
        $person

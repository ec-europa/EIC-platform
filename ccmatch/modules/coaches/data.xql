xquery version "1.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Read and write controller for coach profile editing

   TODO: ajouter LastModification to every facet ?

   September 2015 - (c) Copyright may be reserved
   ----------------------------------------------- :)

declare namespace request = "http://exist-db.org/xquery/request";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace misc = "http://oppidoc.com/ns/misc" at "../../lib/util.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace person = "http://oppidoc.com/ns/ccmatch/person" at "../../lib/person.xqm";
import module namespace data = "http://oppidoc.com/ns/ccmatch/data" at "../../lib/data.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: TODO: share with home.xql, store in config/profile.xml :)
declare variable $local:config := 
  <Facets>
    <Facet Name="contact" Elements="Information"/>
    <Facet Name="experiences" Elements="Knowledge" Skills="LifeCycleContexts DomainActivities TargetedMarkets Services" Prefix="Rating"/>
    <Facet Name="competences" Elements="CurriculumVitae" Skills="CaseImpacts" Prefix="Rating"/>
    <Facet Name="availabilities" Elements="Coaching"/>
    <Facet Name="visibilities" Elements="Visibility"/>
  </Facets>;

(: ======================================================================
   Converts Skills elements to prefixed elements for editing
   ======================================================================
:)
declare function local:decode-1-skills( $name as xs:string, $prefix as xs:string, $skills as element()* ) as element() {
  element { $name } {
    for $s in $skills/Skill
    return
      element { concat($prefix, '_', $s/@For) } {
        $s/text()
      }
  }
};

declare function local:decode-2-skills( $name as xs:string, $prefix as xs:string, $skills as element()* ) as element() {
  element { $name } {
    for $s in $skills/Skills
    return
      for $ss in $s/Skill
      return
        element { concat($prefix, '_', $s/@For, '_', $ss/@For) } {
          $ss/text()
        }
  }
};

declare function local:decode-skills( $prefix as xs:string, $skills as element()? ) as element()? {
  if (empty($skills)) then
    ()
  else if ($skills/Skills) then
    local:decode-2-skills($skills/@For, $prefix, $skills)
  else
    local:decode-1-skills($skills/@For, $prefix, $skills)
};

(: ======================================================================
   Normalizes a string to compare it with another one
   TODO: handle accentuated characters (canonical form ?)
   ======================================================================
:)
declare function local:normalize( $str as xs:string? ) as xs:string {
  upper-case(normalize-space($str))
};

(: ======================================================================
   Validates submitted data.

   @param $id The database user identifier (integer number)
   @return A list of errors to report or the empty sequence.
   ======================================================================
:)
declare function local:validate-submission( $facet as xs:string, $submitted as element(), $person as element() ) as element()* {
  if ($facet eq 'competences') then
    let $length := string-length(normalize-space($submitted/CurriculumVitae/Summary))
    return
      if ($length > 500) then
        let $fat := $length - 500
        return
          oppidum:throw-error('CUSTOM', concat('Your executive summary contains ', $length, ' characters; you must remove at least ', $fat, ' characters to remain below 500 characters'))
      else
        ()
  else if ($facet eq 'experiences') then
    if ($person//Host and string-length(normalize-space($submitted//CV-Link/text())) = 0 and count($person/Resources/CV-File) = 0) then
      oppidum:throw-error('APPLICATION-KEEP-EITHER-CV', fn:collection($globals:global-info-uri)//Description[@Lang = 'en']//Selector[@Name eq 'Hosts']/Option[Id eq $person//Host[1]/@For]/Name)
    else
      ()
  else if ($facet eq 'contact') then
    let $key1 := local:normalize($submitted/Information/Contacts/Email/text())
    let $ckey1 := fn:collection($globals:persons-uri)//Person[local:normalize(Information/Contacts/Email) eq $key1][not(Id eq $person/Id)]
    let $rem := $submitted/External/Remote/text()[. ne '']
    let $rel := $submitted/External/Realm/text()[. ne '']
    return
      if ((exists($rem) and empty($rel)) or (empty($rem) and exists($rel))) then
        ajax:throw-error('REMOTE-PROFILE-MISSING-DATA', ())
      else if ($ckey1) then
        ajax:throw-error('PERSON-EMAIL-CONFLICT', (display:gen-person-name($ckey1[1], 'en'), $key1))
      else
        ()
  else
    ()
};

declare function local:update-remote( $person as element(), $remote as element()) {
  let $cur := $person/UserProfile/Remote[@Name eq $remote/Realm/text()]
  return
    if (local:normalize($cur) != '') then
        update value $cur/text() with $remote/Remote/text()
    else
      let $rem := $remote/Remote/text()[. ne '']
      let $rel := $remote/Realm/text()[. ne '']
      return
        if (empty($rel) and empty($rem)) then
          ()
        else
          update insert <Remote Name="{$remote/Realm/text()}">{$remote/Remote/text()}</Remote> into $person/UserProfile
};

(: ======================================================================
   Coach facet(s) updating
   ====================================================================== 
:)
declare function local:update-coach-profile( 
  $facet as xs:string, 
  $person as element(),
  $submitted as element(),
  $redirect as xs:string
  ) as element()?
{
  let $model := $local:config/Facet[@Name eq $facet]
  let $elementals := 
    for $e in tokenize($model/@Elements, ' ')
    return
      if ($e = ('Coaching','Visibility')) then
        let $prefs := if ($person/Preferences) then () else update insert <Preferences/> into $person
        return
          for $el in $submitted//*[contains(local-name(.), concat($e, '_'))]
          let $rec := local:recode($el)
          return
            person:save-facet($person/Preferences, $person//*[local-name(.) eq $e][@For eq $rec/@For], $rec)
      else if ($e eq 'Information') then
        (
        let $external := $submitted/*[local-name(.) eq 'External']
        return
          if ($external) then
            local:update-remote($person, $submitted/*[local-name(.) eq 'External'])
          else
            (),
        person:save-facet($person, $person/*[local-name(.) eq $e], $submitted/*[local-name(.) eq $e])
        )[last()]
      else
        person:save-facet($person, $person/*[local-name(.) eq $e], $submitted/*[local-name(.) eq $e ])
  let $skills := 
    for $s in tokenize($model/@Skills, ' ')
    return 
      person:save-facet($person, $person/Skills[@For eq $s],
      data:encode-skills($submitted/*[local-name(.) eq $s]))
  let $timestamp := person:update-log-entry($person, $facet)
  return
    let $payload := <p id="cm-{$facet}-update">{ display:gen-log-message-for($person, $facet)}</p>
    return
      ajax:report-success('ACTION-PROFILE-UPDATE-SUCCESS', $facet, $payload)
};

(: ======================================================================
   Injects CV-File resource into knowledge model 
   Filters CV-File Date attribute in knowledge element to display last 
   modification date message with data-input property of 'file' plugin
   ====================================================================== 
:)
declare function local:gen-knowledge( $person as element() ) {
  if ($person/Resources/CV-File) then
    <Knowledge>
      {
      $person/Knowledge/*,
      let $d := string($person/Resources/CV-File/@Date)
      return
        <CV-File data-input="{$person/Resources/CV-File} uploaded on {display:gen-display-date($d,'en')} at {substring($d, 12, 2)}:{substring($d, 15, 2)}">
          { $person/Resources/CV-File/text() }
        </CV-File>
      }
    </Knowledge>
    else
      $person/Knowledge
};

declare function local:filter-subset( $person as element(), $e as xs:string) as element()* {
  for $c in $person//*[local-name(.) eq $e]
  return
    if ($c/@For) then
      element { concat(local-name($c), '_', string($c/@For)) } { $c/* }
    else
      $c
};

declare function local:recode($e as element()) as element()* {
  let $toks := tokenize(local-name($e), '_')
  return 
    element { $toks[1] }
    {
      attribute For { $toks[2] },
      $e/*
    }
};
(: ======================================================================
   Coach facet reading
   ====================================================================== 
:)
declare function local:read-coach-facet( $person as element()?, $facet as xs:string ) as element()? 
{
  let $model := $local:config/Facet[@Name eq $facet]
  return
    <Profile>
    {
    for $e in tokenize($model/@Elements, ' ')
    return 
      if ($e eq 'Information') then
        (
        person:gen-information($person),
        person:gen-external-login($person)
        )
      else if ($e eq 'Knowledge') then
        local:gen-knowledge($person)
      else if ($e = ('Coaching','Visibility')) then
        element { $e } { local:filter-subset($person, $e) }
      else
        $person/*[local-name(.) eq $e],
    for $s in tokenize($model/@Skills, ' ')
    return 
      local:decode-skills($model/@Prefix, $person/Skills[@For eq $s])
    }
    </Profile>
};

let $m := request:get-method()
let $cmd := request:get-attribute('oppidum.command')
let $user := oppidum:get-current-user()
let $token := tokenize($cmd/@trail, '/')[1]
let $facet := string(oppidum:get-resource($cmd)/@name)
let $groups := oppidum:get-current-user-groups()
let $person := access:get-person($token, $user, $groups)
return
  if (local-name($person) ne 'error') then
    if ($m eq 'POST') then 
      if (access:can-edit-profile($person, $user, $groups)) then
        let $submitted := oppidum:get-data()
        let $errors := local:validate-submission($facet, $submitted, $person)
        return
          if (empty($errors)) then (: validation :)
            let $redirect := concat($cmd/@base-url, $token)
            return
              local:update-coach-profile($facet, $person, $submitted, $redirect)
          else
            oppidum:throw-error('VALIDATION-FAILED',
              string-join(for $e in $errors return $e/message/text(), ', '))
      else
        oppidum:throw-error('FORBIDDEN', ())
    else (: assume GET :)
      local:read-coach-facet($person, $facet)
  else
    $person

(: SANDBOX TEST -> Move to Unit Testing

let $a :=
  <CaseImpacts>
    <Innovation_Expertise_1_1>1</Innovation_Expertise_1_1>
    <Innovation_Expertise_1_2>1</Innovation_Expertise_1_2>
    <Innovation_Expertise_1_3>2</Innovation_Expertise_1_3>
    <Innovation_Expertise_2_1>2</Innovation_Expertise_2_1>
    <Innovation_Expertise_2_9>2</Innovation_Expertise_2_9>
    <Innovation_Expertise_3_1>2</Innovation_Expertise_3_1>
    <Innovation_Expertise_4_5>2</Innovation_Expertise_4_5>
    <Innovation_Expertise_4_4>3</Innovation_Expertise_4_4>
    <Innovation_Expertise_4_6>3</Innovation_Expertise_4_6>
  </CaseImpacts>

let $b :=
<InitialContexts>
    <LifeCycle_Expertise_1>1</LifeCycle_Expertise_1>
    <LifeCycle_Expertise_3>2</LifeCycle_Expertise_3>
    <LifeCycle_Expertise_2>1</LifeCycle_Expertise_2>
    <LifeCycle_Expertise_4>2</LifeCycle_Expertise_4>
    <LifeCycle_Expertise_6>2</LifeCycle_Expertise_6>
    <LifeCycle_Expertise_5>3</LifeCycle_Expertise_5>
  </InitialContexts>

return
  (
  local:decode-skills($a),
  local:decode-skills($b)
  )
:)

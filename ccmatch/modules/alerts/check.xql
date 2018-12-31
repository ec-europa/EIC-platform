xquery version "1.0";
(: ------------------------------------------------------------------
   CCMATCH - EIC Coach Match Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Periodical TODO list computation

   FIXME: currently the period depends of a $freshness module variable
   and of the last time some user have called that functionality.
   This could be replaced by a trigger.

   May 2015 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace xdb = "http://exist-db.org/xquery/xmldb";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace misc = "http://oppidoc.com/ns/misc" at "../../lib/util.xqm";

declare variable $local:dac := 4; (: nace codes limit :)
declare variable $local:tc := 4; (: thomson reuters markets limit :)
declare variable $local:sc := 2; (: services limit :)
declare variable $local:cic := 8; (: case impacts limit :)

declare function local:gen-person-sample( $tag as xs:string, $p as element(), $lifecycle as xs:double, $domainactivities as xs:double, $targets as xs:double, $services as xs:double, $summary as element()?, $impacts as xs:double) {
    element { $tag } {
      $p/Id,
      $p//Name,
      $p//Email,
      <Experiences>
        <RenewalPlusConsolidationExpert>{ $lifecycle }</RenewalPlusConsolidationExpert>
        <DomainActivitiesCount Inc="{$domainactivities gt $local:dac}">{ $domainactivities }</DomainActivitiesCount>
        <TargetsCount Inc="{$targets gt $local:tc}">{ $targets }</TargetsCount>
        <ServicesCount Inc="{$services gt $local:sc}">{ $services }</ServicesCount>
      </Experiences>,
      <Competences>
        <Summary Inc="{not($summary)}">{normalize-space($summary)}</Summary>
        <CaseImpacts Inc="{$impacts gt $local:cic}">{$impacts}</CaseImpacts>
      </Competences>,
      <AS>{ $p/Hosts/Host[@For = '1']/AccreditationRef/text() }</AS>,
      <WS>{ $p/Hosts/Host[@For = '1']/WorkingRankRef/text() }</WS>
    }
};

declare function local:fetch-all ( $user-ref as xs:string?, $all as xs:boolean) as element()* {
  let $watched := '3'
  let $coaches := fn:collection($globals:persons-uri)//Person[UserProfile//FunctionRef = '4']
  let $accepted := $coaches[Hosts/Host[@For eq '1'][AccreditationRef eq '4']]
  let $activated := $accepted[Hosts/Host[@For eq '1'][WorkingRankRef eq '1']]
  let $available := $activated[not(Preferences/Coaching[@For eq '1']) or (Preferences/Coaching[@For eq '1']/YesNoAvailRef eq '1')]
  let $noskills := count($available[not(Skills)])
  return
    <Batch All="{ $all }" Max="{ count(fn:collection($globals:persons-uri)//Person) }" Total="{ count($coaches) }" Accepted="{ count($accepted) }" Activated="{ count($activated) }" Available="{ count($available) }" NoSkills="{ $noskills }">
      <Thresholds>
        <DomainActivities>{ $local:dac }</DomainActivities>
        <TargetMarkets>{ $local:tc }</TargetMarkets>
        <Services>{ $local:sc }</Services>
        <CaseImpacts>{ $local:cic }</CaseImpacts>
      </Thresholds>
    {
      for $p in fn:collection($globals:persons-uri)//Person
      let $lifecycle := count($p//Skills[string(@For) = "LifeCycleContexts"]//Skill[string(@For) = ('5','6') and text() = $watched])
      let $domainactivities := count($p//Skills[string(@For) = "DomainActivities"]//Skill[text() = $watched])
      let $targets := count($p//Skills[string(@For) = "TargetedMarkets"]//Skill[text() = $watched])
      let $services := count($p//Skills[string(@For) = "Services"]//Skill[text() = $watched])
      let $summary := $p//Summary
      let $impacts := count($p//Skills[string(@For) = "CaseImpacts"]//Skill[text() = $watched])
      let $iscoach := $p/UserProfile//FunctionRef = '4'
      where $all or $iscoach
      (:order by number($p/Id):)
      return
        if ($all) then  (: full dump :)
          if ($iscoach) then
            if ( $domainactivities gt $local:dac
                   or $targets gt $local:tc
                   or $services gt $local:sc
                   or not($summary)
                   or $impacts gt $local:cic )
            then
              local:gen-person-sample('Inconsistent', $p, $lifecycle, $domainactivities, $targets, $services, $summary, $impacts)
            else
              local:gen-person-sample('Consistent', $p, $lifecycle, $domainactivities, $targets, $services, $summary, $impacts)
          else
            local:gen-person-sample('Person', $p, $lifecycle, $domainactivities, $targets, $services, $summary, $impacts)
        else (: only inconsistent coaches :)
          if ( $iscoach and
               ( $domainactivities gt $local:dac
                 or $targets gt $local:tc
                 or $services gt $local:sc
                 or not($summary)
                 or $impacts gt $local:cic )
             )
          then
            local:gen-person-sample('Inconsistent', $p, $lifecycle, $domainactivities, $targets, $services, $summary, $impacts)
          else
            ()
    }
    </Batch>
};



declare function local:acceptances( $user-ref as xs:string?, $all as xs:boolean) as element()* {
  let $coaches := fn:collection($globals:persons-uri)//Person[UserProfile//FunctionRef = '4'][Hosts/Host[@For eq '1']]
  return
    <BatchAccr>
    {
      for $p in $coaches
      let $host := $p/Hosts/Host[@For = '1']
      return
        <Coach>
        {
          $p/Id,
          $p//Name,
          $p/Information/Contacts/Email,
          $p/Information/Address/Country,
          $p/Knowledge/CV-Link,
          <Summary>{normalize-space($p/CurriculumVitae/Summary/text())}</Summary>,
          <HasPDFCV>{ $p/Resources/CV-File/text() }</HasPDFCV>,
          <AS>{ display:gen-name-for('Acceptances', $host/AccreditationRef, 'en') }</AS>,
          <WS>{ if ($host/WorkingRankRef) then display:gen-name-for('WorkingRanks', $host/WorkingRankRef, 'en') else '---' }</WS>,
          <CS>{ if ($host/ContactRef) then display:gen-person-name-for-ref($host/ContactRef/text(), 'en') else '---' }</CS>,
          if ($host/ManagerNotes/ExpertNumber) then $host/ManagerNotes/ExpertNumber else <ExpertNumber>---</ExpertNumber>,
          if ($host/ManagerNotes/Comment) then $host/ManagerNotes/Comment else <Comment><Text>---</Text></Comment>,
          for $pr in $p/Preferences/*
          return
            element { local-name($pr) }
            {
              attribute For { display:gen-name-for('Hosts', <Tag>{ string($pr/@For) }</Tag>, 'en') },
              misc:unreference($pr/*)
            },
          <ILogin>{ $p/UserProfile/Username/text() }</ILogin>,
          <EULogin>{ $p/UserProfile/Remote[@Name eq 'ECAS']/text() }</EULogin>
        }
        </Coach>
    }
    </BatchAccr>
};


let $cmd := oppidum:get-command()
let $target := string($cmd/resource/@name)
let $all := request:get-parameter-names() = 'all'
return
    if ($target eq 'alerts') then
      local:fetch-all("", $all)
    else if ($target eq 'acceptances') then
      local:acceptances("", $all)
    else
      ()



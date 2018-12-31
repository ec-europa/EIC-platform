xquery version "3.0";
(: ------------------------------------------------------------------
   ------------------------------------------------------------------ :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace xdb = "http://exist-db.org/xquery/xmldb";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace account = "http://platinn.ch/coaching/account" at "../users/account.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";
import module namespace console="http://exist-db.org/xquery/console";

declare variable $local:projects := collection($globals:projects-uri);
declare variable $local:persons := collection($globals:persons-uri);

declare variable $local:separator := ";;";

declare variable $local:kams := display:gen-map-for-roles('5');
declare variable $local:mask := (: for generating table columns in report.xsl :)
  <Mask>
    <Group Matchable="1" Scope="Business" Color="#d7f442">
      <Field Match="Vectors">Vectors</Field>
      <Field Match="Ideas">Ideas</Field>
      <Field Match="Resources">Resources</Field>
      <Field Match="Partners">Partners</Field>
    </Group>
    <Group Matchable="1" Scope="SME" Color="#efa81a">
      <Field Match="DomainActivityRef">DomainActivities</Field>
      <Field Match="TargetedMarkets">TargetedMarkets</Field>
      <Field Match="InitialContextRef">InitialContexts</Field>
      <Field Match="TargetedContextRef">TargetedContexts</Field>
    </Group>
    <Group Matchable="1" Scope="Coaching" Color="#19cfef">
      <Field Match="ServiceRef">Services</Field>
    </Group>
    <Group Scope="Coach" Color="#838dfc">
      <Field>Coaches</Field>
      <Field>SpokenLanguages</Field>
      <Field>Countries</Field>
      <Field>Expertise</Field>
    </Group>
  </Mask>;

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Assert that $target-ref is a real KAM
   ======================================================================
:)
declare function local:is-kam($target-ref as xs:string) as xs:boolean {
  if (collection($globals:persons-uri)//Person[Id eq $target-ref]) then
    count(collection($globals:persons-uri)//Person[Id eq $target-ref]//Role[FunctionRef = '5']) > 0
  else
    false()
};

(: ======================================================================
   Information about work due by the KAM at the moment of the search
   Cannot rely on current todo-list
   ======================================================================
:)
declare function local:get-likely-background( $assigned as element()*, $id as xs:string, $timestamp as xs:string, $history as element() ) as element()* {
  for $assigned-case in collection('/db/sites/cctracker/projects')//Project/Cases/Case[Management/AccountManagerRef = $id]
  let $p := $assigned-case/ancestor::Project
  (:where $p/Information/Contract/Duration ne '' and xs:date(Information/Contract/Start) + xs:yearMonthDuration(concat('P', Information/Contract/Duration, 'M')) gt current-date():)
  let $case-sample :=
    <Case Project="{ $assigned-case/ancestor::Project/Id }">
      {
      $assigned-case/PIC,
      for $a in $assigned-case//Activity[StatusHistory[CurrentStatusRef eq '1' or Status[ValueRef eq '2']/Date ge $timestamp]]
      return
        element {
          if ($a/Assignment/Date and $a/Assignment/ResponsibleCoachRef) then
            'Possible' 
        else
            'ToDo'
        }
        { 
        attribute Case { $assigned-case/No }, attribute Activity { $a/No }, 
        local:matching-criteria( local:criteria( $p, $assigned-case, $a ), $history/Request)
        }
      }
    </Case>
  return
    if ($case-sample/(Possible|ToDo)) then
      $case-sample
    else
      ()
};

(: ======================================================================
   Trivial BG (CM Tunnel search)
   ======================================================================
:)

declare function local:in-top-k( $coach-id as xs:string, $results as element() ) as xs:boolean {
  let $full := collection($globals:persons-uri)//Person[Id eq $coach-id]/Name
  return
    exists($results/Coaches[
      Name
        [fn:lower-case(FirstName) eq fn:lower-case($full/FirstName)]
        [fn:lower-case(LastName) eq fn:lower-case($full/LastName)]
      ])
};

(: ======================================================================
  Merge query given in CA wrt. criteria defined in NA to rely on the latter
  data model.
   ======================================================================
:)
declare function local:compute-eq-query( $na as element()?, $weights as element()? ) as element()? {
  let $impact := $na/Impact
  return
    if ($na/Impact and $weights) then
      <Impact>
        {
        for $f in ('Vectors', 'Ideas', 'Resources', 'Partners')
        let $wf := $weights/*[contains(local-name(.),$f)]
        return
          if ($wf) then
            element { $f } 
            {
              let $fref := concat(substring($f, 1, string-length($f) - 1), 'Ref')
              return
                for $w in $wf
                return element { $fref } { attribute Expertise { if ($w ne '') then $w/text() else 'Unknown' }, substring-after(local-name($w), '-') }
            
            }
          else $weights
        }
      </Impact>
    else if ($na/Impact) then
      $na/Impact
    else
      ()
};

(: ======================================================================
  Returns all relevant stats (Impact, Service, SME)
   ======================================================================
:)
declare function local:criteria( $p as element(), $c as element(), $a as element() ) as element()+ {
  let $cri := 
    (
    let $ctx := $c/NeedsAnalysis/Context/( InitialContextRef | TargetedContextRef )
    return
      if ($ctx) then
        <Context>{ $ctx }</Context>
      else
        (),
    local:compute-eq-query( $c/NeedsAnalysis, $a/Assignment/Weights ),
    $a/Assignment/ServiceRef,
    let $sme := $p/Information/Beneficiaries/*[PIC eq $c/PIC]/( DomainActivityRef | TargetedMarkets)
    return
      if ($sme) then
        <Beneficiary>
        { $sme }
        </Beneficiary>
      else
        ()
    )
  return
    if ($cri) then
      <Criteria>{ $cri }</Criteria>
    else
      ()
};

(: ======================================================================
  Returns matching criteria with the current query
   ======================================================================
:)
declare function local:matching-criteria( $criteria as element()?, $query as element() ) as element() {
  if ($criteria) then
    if (local-name($query) eq 'Request') then
      if ($criteria) then
        <Criteria>
          <Context>
            { if ($query/InitialContexts/(InitialContextRef | ContextRef)= $criteria/Context/InitialContextRef) then <InitialContextRef Match="1">{ $criteria//InitialContextRef/text() }</InitialContextRef> else $criteria//InitialContextRef }
            { if ($query/TargetedContexts/(TargetedContextRef | InitialContextRef | ContextRef) = $criteria/Context/TargetedContextRef) then <TargetedContextRef Match="1">{ $criteria//TargetedContextRef/text() }</TargetedContextRef>  else $criteria//TargetedContextRef }
          </Context>
          <Impact>
            { if ($query/Vectors/VectorRef = $criteria//Vectors/VectorRef) then <Vectors Match="1">{ $criteria//Vectors/VectorRef }</Vectors> else $criteria//Vectors }
            { if ($query/Ideas/IdeaRef = $criteria//Ideas/IdeaRef) then <Ideas Match="1">{ $criteria//Ideas/IdeaRef }</Ideas> else $criteria//Ideas }
            { if ($query/Resources/ResourceRef = $criteria//Resources/ResourceRef) then <Resources Match="1">{ $criteria//Resources/ResourceRef }</Resources> else $criteria//Resources }
            { if ($query/Partners/PartnerRef = $criteria//Partners/PartnerRef) then <Partners Match="1">{ $criteria//Partners/PartnerRef }</Partners> else $criteria//Partners }
          </Impact>
          { if ($query/ServiceRef = $criteria//ServiceRef) then <ServiceRef Match="1">{ $criteria//ServiceRef/(@*|*) }</ServiceRef> else $criteria//ServiceRef }
          <Beneficiary>
            { if ($query//DomainActivityRef = $criteria//DomainActivityRef) then <DomainActivityRef Match="1">{ $criteria//DomainActivityRef/text() }</DomainActivityRef> else $criteria//DomainActivityRef }
            { if ($query/TargetedMarkets/TargetedMarketRef = $criteria//TargetedMarketRef) then <TargetedMarkets Match="1">{ $criteria//TargetedMarketRef }</TargetedMarkets> else $criteria//TargetedMarkets }
          </Beneficiary>
        </Criteria>
      else ()
    else (: others to do :)
      $criteria
  else
    ()
};


(: ======================================================================
  Compute KAMs activities
   ======================================================================
:)
declare function local:get-formal-background( $history as element() ) as element()* {
  let $ctx := $history/Request/Analytics
  let $ts := string($history/@TS)
  return
    let $p := $local:projects//Project[Id eq $ctx/Project]
    return
      let $c := $p/Cases/Case[No eq $ctx/Case]
      return
        if ($c) then
          <Case Project="{ $p/Id }">
          {
            $c/PIC,
            let $a := $c/Activities/Activity[No eq $ctx/Activity]
            return
              if ($a) then
                let $date := $a/Assignment/Date
                let $coach := $a/Assignment/ResponsibleCoachRef
                return
                  if ($coach) then
                    if ($ts le $date) then
                      element { if (local:in-top-k( $coach, $history/Response )) then 'Match' else 'Trial' }
                      {
                        attribute Delay { xs:dateTime($date) - xs:dateTime($ts) },
                        attribute DP {days-from-duration(xs:dateTime($date)  - xs:dateTime($ts))},
                        attribute Case { $c/No }, attribute Activity { $a/No }, 
                        local:matching-criteria( local:criteria( $p, $c, $a ), $history/Request)
                      }
                    else
                      <After Delay="{xs:dateTime($ts)  - xs:dateTime($date)}" DP="{days-from-duration(xs:dateTime($ts)  - xs:dateTime($date))}" Case="{ $c/No }" Activity="{ $a/No }">
                      { local:matching-criteria( local:criteria( $p, $c, $a ), $history/Request) }
                      </After>
                  else
                    <Todo Case="{ $c/No }" Activity="{ $a/No }">
                    { local:matching-criteria( local:criteria( $p, $c, $a ), $history/Request) }
                    </Todo>
              else
                <error Project="{ $p/Id }" Deleted="Activity"/>
          }
          </Case>
        else
          <error Project="{ $p/Id }" Case="{ $c/No }" Deleted="Case"/>
};

(: ======================================================================
  CM or CT? If CT, background is needed to narrow the scope of the meaning
  If CM, query is known
   ======================================================================
:)
declare function local:get-general-context( $id as xs:string, $history as element(), $force as xs:boolean ) as element() {
  if ($history/Purpose and not($force)) then
    $history/Purpose
  else
    let $del := if ($force) then system:as-user(account:get-secret-user(), account:get-secret-password(), update delete $history/Purpose) else ()
    let $which :=
      if ($history/@Purpose = ("coach-fit-search", "coach-refine-fit-search")) then
        <Purpose What="Coach Assignment" Sub="{ $history/@Purpose }" Timestamp="{ display:gen-display-date($history/@TS, 'en') } { substring($history/@TS,12,8) }">
        { local:get-formal-background( $history ) }
        </Purpose>
      else
        <Purpose What="Standalone" Timestamp="{ display:gen-display-date($history/@TS, 'en') } { substring($history/@TS,12,8) }">
        { local:get-likely-background( collection('/db/sites/cctracker/projects')//Project/Cases/Case[Management/AccountManagerRef = $id], $id, $history/@TS, $history ) }
        </Purpose>
    return
      let $record := system:as-user(account:get-secret-user(), account:get-secret-password(), update insert $which preceding $history/Request)
      return
        $which
};

(: ======================================================================

   ======================================================================
:)
declare function local:test() as element() {
  collection('/db/sites/cctracker/global-information')//GlobalInformation/Description/CaseImpact/Sections/Section[SectionRoot eq 'Vectors']
};

(: ======================================================================

   ======================================================================
:)
declare function local:unreference( $e as item()*, $response as element() ) {
  if ($e) then
    if ($e instance of element() and local-name($e) eq 'Coaches') then
      let $new := element { local-name($e) }
      {
        let $display := string-join( for $c in $e/element() return string-join($response/Coaches[Id = $c]/Name/*, ' '), ', ')
        return attribute _Display { $display },
        $e/element()
      }
      return $new
    else
      misc:unreference($e, $local:separator)
  else
    ()
};

(: ======================================================================

   ======================================================================
:)
declare function local:update( $old as element(), $new as element() ) as element()* {
  let $update := system:as-user(account:get-secret-user(), account:get-secret-password(), update replace $old with $new)
  return
    $new
};

(: ======================================================================

   ======================================================================
:)
declare function local:gen-name( $pid as element() ) as attribute()+ {
  let $cached := display:gen-map-name-for('5', $pid, $local:kams)
  return
    if ($cached) then
      (
      attribute Name { $cached },
      attribute KAM {'1'} 
      )
    else
      attribute Name { string-join( $local:persons//Person[Id eq $pid]//Name/*, ' ') }
};

(: ======================================================================

   ======================================================================
:)
declare function local:assigned-coaches( $histories as element()* ) as element() {
  let $min := min(for $ts in $histories/History/@TS return xs:dateTime($ts))
  return
    <CoachAssigned Min="{ display:gen-display-date($min, 'en') } { substring($min,12,8)  }">
    {
    for $act in collection('/db/sites/cctracker/projects')//Case/Activities/Activity
      [StatusHistory/CurrentStatusRef ne '1']
      [Assignment[ResponsibleCoachRef ne ''][Date > $min]]
    group by $kam := $act/../../Management/AccountManagerRef
    return 
      <KAM>
        <Id>{$kam/text()}</Id>
        <Count>{count($act)}</Count>
        <List>{ for $a in $act return <Code P="{ $a/ancestor::Project/Id }" C="{ $a/../../No }" A="{ $a/No }"/> }</List>
      </KAM>
    }
    </CoachAssigned>
};

(: ======================================================================

   ======================================================================
:)
declare function local:ci-to-fit-part-of-request( $impact as element()? ) as element()* {
  if ($impact) then
    let $v := $impact/*[starts-with(local-name(.),'Rating_1')]
    let $i := $impact/*[starts-with(local-name(.),'Rating_2')]
    let $r := $impact/*[starts-with(local-name(.),'Rating_3')]
    let $p := $impact/*[starts-with(local-name(.),'Rating_4')]
    return
      (
      if ($v) then
        <Vectors>{ for $e in $v return <VectorRef Expertise="{ $e/text() }">{ let $s := local-name($e) return substring($s, string-length($s), 1) }</VectorRef>}</Vectors>
      else(),
      if ($i) then
        <Ideas>{ for $e in $i return <IdeaRef Expertise="{ $e/text() }">{ let $s := local-name($e) return substring($s, string-length($s), 1) }</IdeaRef>}</Ideas>
      else(),
      if ($r) then
        <Resources>{ for $e in $r return <ResourceRef Expertise="{ $e/text() }">{ let $s := local-name($e) return substring($s, string-length($s), 1) }</ResourceRef>}</Resources>
      else(),
      if ($p) then
        <Partners>{ for $e in $p return <PartnerRef Expertise="{ $e/text() }">{ let $s := local-name($e) return substring($s, string-length($s), 1) }</PartnerRef>}</Partners>
      else()
      )
  else
    ()
};

(: ======================================================================

   ======================================================================
:)
declare function local:pretty-uniform-request( $history as element(), $force as xs:boolean ) as element()* {
  let $request := $history/Request
  return
  if (not($request/@Displayable) or $force) then
    let $transform :=
      if ($request/Analytics and $request/SearchByFit and not($request/SearchByCriteria)) then
       <Request Was="SbF">
         {
         let $sbf := $request/SearchByFit
         return
           (
           $request/Analytics,
           local:ci-to-fit-part-of-request( $sbf/CaseImpacts ),
           <DomainActivities>{ $sbf/Stats/DomainActivityRef }</DomainActivities>,
           $sbf/Stats/TargetedMarkets,
           <InitialContexts>{ $sbf//InitialContextRef }</InitialContexts>,
           <TargetedContexts>{ $sbf//TargetedContextRef }</TargetedContexts>,
           $sbf/ServiceRef
           )
         }
       </Request>
      else if ($request/Analytics and $request/SearchByCriteria) then
        let $sbc := $request/SearchByCriteria
        return
          <Request Was="RSbF">
          {
          $request/Analytics,
          $sbc/*[not(local-name(.) = ('InitialContexts', 'TargetedContexts'))],
          <InitialContexts>{ for $c in $sbc/InitialContexts/ContextRef return <InitialContextRef>{ $c/text() }</InitialContextRef> }</InitialContexts>,
          <TargetedContexts>{ for $c in $sbc/TargetedContexts/ContextRef return <TargetedContextRef>{ $c/text() }</TargetedContextRef> }</TargetedContexts>
          }
          </Request>
      else
        $request
    return
      let $m := $local:mask//Field[../@Scope eq 'Business']/text()
      return
        let $user-friendly :=
          <Request Displayable="1">
            {
            $transform/@Was,
            for $e in $transform/*[local-name(.) = $m]
            let $o := collection($globals:global-info-uri)//CaseImpact/Sections/Section[./SectionRoot eq local-name($e)]//SubSection[Id = $e/*]/SubSectionName
            return element { local-name($e) } { attribute _Display { string-join($o, $local:separator)} , $e/element() }
            ,
            for $e in $transform/*[not(local-name(.) = $m)]
            return local:unreference($e, $history/Response)
            }
          </Request>
        return
          local:update( $request, $user-friendly )
  else
    $request
};

(: ======================================================================

   ======================================================================
:)
declare function local:fetch-all( $config as xs:string* ) as element()* {
  let $assigned := local:assigned-coaches(collection('/db/analytics/ccmatch')//Histories)
  return
  <Analytics>
  {
  $local:mask,
  $assigned,
  for $histories in collection('/db/analytics')//Histories
  group by $pid := $histories/Id
  return
    <Person>
    { local:gen-name( $pid ) }
    {
    $pid,
    for $history in $histories/History
    return
      <Row>
        {
        local:pretty-uniform-request($history, 'request' = $config),
        local:get-general-context( $pid, $history, 'purpose' = $config ) (: context of search: the current track list of the KAM in a case of a standalone/tunnel search :)
        }
        <Count>{ string($history/Response/@Count) }</Count>
      </Row>
    }
    </Person>
  }
  </Analytics>
};

(: ======================================================================

   ======================================================================
:)
declare function local:export( $type as xs:string ) {
  <root fn="test{current-dateTime()}">
  {
  for $histories in collection('/db/analytics')//Histories
  let $attrs := <E>{local:gen-name( $histories/Id )}</E>
  let $cc := console:log($attrs)
  return
    for $h in $histories/History
    let $ctx := $h/Purpose/Case/*[not(local-name(.) eq 'PIC')]
    let $p := $h/Purpose
    let $req := $h/Request
    return
      if ($ctx) then
        for $a in $ctx
        let $c := $a/..
        let $crit := $a/Criteria
        return
          <row>
            <col explicit="WHO">{ if ($type eq '2') then $histories/Id/text() else string($attrs/@Name) }</col>
            <col explicit="KAM">
            {
            if ($type eq '2') then
              if (string($attrs/@KAM)) then '1' else '0'
            else
              if (string($attrs/@KAM)) then 'Yes' else 'No'
            }
            </col>
            <col explicit="#Query">{ count($h/preceding-sibling::History) + 1}</col>
            <col explicit="WHEN">{ string($p/@Timestamp) }</col>
            <col explicit="TYPE">{ string($p/@What) } { if ($p/@Sub) then concat('(',string($p/@Sub),')') else ()}</col>
            <col explicit="Activity (#P)">{ string($c/@Project) }</col>
            <col explicit="Activity (#C)">{ string($a/@Case) }</col>
            <col explicit="Activity (#A)">{ string($a/@Activity) }</col>
            <col explicit="Coach">
              {
              if ($h/Response/@Count eq '0' and local-name($a) = ('Match','Trial')) then
                'Yes (Unrelated)'
              else if (local-name($a) = 'Trial') then
                'Yes (Not first 20)'
              else if (local-name($a) = 'Match') then
                'Yes'
              else if (local-name($a) = 'Possible') then
                'Yes (Possible)'
              else if (local-name($a) = 'After') then
                'Already assigned'
              else
                'No'
              }
            </col>
            <col explicit="Interval (Days)">{ if ($a/@DP) then string($a/@DP) else 'N/A' }</col>
            <col explicit="Matching BI Criteria (defined)">
            {
            let $def := $local:mask//Group[@Scope eq "Business"]
            let $inst := $crit/Impact/*
            return
              ( count($inst/@Match), ' (',  count($inst), '/', count($def/Field), ')' )
            }
            </col>
            <col explicit="Matching SME Criteria (defined)">
            {
            let $def := $local:mask//Group[@Scope eq "SME"]
            let $inst := ($crit/(Context | Beneficiary)/*)
            return
              ( count($inst/@Match), ' (',  count($inst), '/', count($def/Field), ')' )
            }
            </col>
            <col explicit="Matching Coaching Service (defined)">
            {
            let $def := $local:mask//Group[@Scope eq "Coaching"]
            let $inst := $crit/ServiceRef
            return
              ( count($inst/@Match), ' (',  count($inst), '/', count($def/Field), ')' )
            }
            </col>
            <col explicit="#RESULTS">{ string($h/Response/@Count) }</col>
            {
            for $f in $local:mask//Group/Field
            return
              <col explicit="{$f/text()}">
              {
              let $r := $req/*[local-name(.) = $f/text()]
              return
                if ($type eq '2') then
                  string-join($r/*, ';;')
                else
                  if ($r/@_Display) then string($r/@_Display) else if ($r//@_Display) then string-join($r//@_Display,';;') else $r//text()
              }
              </col>
            }
          </row>
      else
        <row>
          <col explicit="WHO">{ if ($type eq '2') then $histories/Id/text() else string($attrs/@Name) }</col>
          <col explicit="KAM">
          {
          if ($type eq '2') then
            if (string($attrs/@KAM)) then '1' else '0'
          else
            if (string($attrs/@KAM)) then 'Yes' else 'No'
          }
          </col>
          <col explicit="#Query">{ count($h/preceding-sibling::History) + 1}</col>
          <col explicit="WHEN">{ string($p/@Timestamp) }</col>
          <col explicit="TYPE">{ string($p/@What) }</col>
          <col explicit="Activity (#P)">N/A</col>
          <col explicit="Activity (#C)">N/A</col>
          <col explicit="Activity (#A)">N/A</col>
          <col explicit="Coach">N/A</col>
          <col explicit="Interval (Days)">N/A</col>
          <col explicit="Matching BI Criteria (defined)">N/A</col>
          <col explicit="Matching SME Criteria (defined)">N/A</col>
          <col explicit="Matching Coaching Service (defined)">N/A</col>
          <col explicit="#RESULTS">{ string($h/Response/@Count) }</col>
          {
          for $f in $local:mask//Group/Field
          return
            <col explicit="{$f/text()}">
            {
              let $r := $req/*[local-name(.) = $f/text()]
              return
                if ($type eq '2') then
                  string-join($r/*, ';;')
                else
                  if ($r/@_Display) then string($r/@_Display) else if ($r//@_Display) then string-join($r//@_Display,';;') else $r//text()
            }
            </col>
          }
        </row>
  }
  </root>
};
let $cmd := oppidum:get-command()
let $config := tokenize(request:get-parameter('config', ()), ',')
let $export-type := request:get-parameter('export', '1') (: 1: values; 2: labels :)
let $export := string($cmd/@format) eq 'xlsx' and $export-type = ('1', '2')
return
  if ($export) then
    local:export($export-type)
  else
    local:fetch-all($config)

xquery version "3.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Coach Matching Algorithm 
   including helper functions to decode Ajax submission

   September 2015 - (c) Copyright may be reserved
   ----------------------------------------------- :)

module namespace match = "http://oppidoc.com/ns/match";

declare namespace json="http://www.json.org";
declare namespace request = "http://exist-db.org/xquery/request";
import module namespace kwic = "http://exist-db.org/xquery/kwic";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace services = "http://oppidoc.com/ns/services" at "../../lib/services.xqm";
import module namespace data = "http://oppidoc.com/ns/ccmatch/data" at "../../lib/data.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";


declare function local:index-of-match-first( $arg as xs:string?, $pattern as xs:string ) as xs:integer? {
  if (matches($arg, $pattern)) then
    string-length(tokenize($arg, $pattern)[1]) + 1
  else
    ()
};

declare function local:substring-before-match( $arg as xs:string?, $regex as xs:string ) as xs:string {
    tokenize($arg,$regex)[1]
};
 
declare function local:substring-after-match( $arg as xs:string?, $regex as xs:string ) as xs:string? {
    replace($arg,concat('^.*?',$regex),'')
};

declare function local:wildcard-to-regex( $q as xs:string ) as xs:string {
    replace($q,"([\?\*\+]{1})","[0-9a-záàâäéèêëíìîïóòôöúùûü\\-]$1")
};

declare function local:expand( $arg as xs:string?, $pattern as xs:string ) as item()* {
  let $idx := local:index-of-match-first(lower-case($arg), lower-case($pattern))
  return
    if ($idx) then
      let $match := substring($arg, $idx)
      return
        (
        if ($idx -1 > 0) then <txt>{ substring($arg, 1, $idx - 1) }</txt> else (),
        <txt match="1">{ local:substring-before-match($match, '\s')}</txt>,
        local:expand(concat(' ', local:substring-after-match($match, '\s')), $pattern)
        )
    else
      <txt>{ $arg }</txt>
};

declare function local:filter( $q as xs:string? ) as xs:string? {
  replace($q, "[^0-9a-zA-ZäöüßÄÖÜ\-. ]", "")
};

(: ======================================================================
   Reads POST data unmarshalling it through the service library 
   if it comes from a guest user, or directly returning it otherwise
   ======================================================================
:)
declare function match:get-data( $user as xs:string, $service as xs:string ) as element()? {
  let $envelope := oppidum:get-data()
  return
    (: local-name test handles the situation where the user is logged into Coach Match
       and into Case Tracker from the same browser at the same time :)
    if (($user eq 'guest') or (local-name($envelope) eq 'Service')) then (: must be a remote service invocation :)
      let $errors := services:validate('ccmatch-public', $service, $envelope)
      return
        if (empty($errors)) then
          services:unmarshall($envelope)
        else
          $errors
    else (: must be a direct request w/o Service / Key :)
      $envelope
};

(: ======================================================================
   Returns Host KeyRef element for host issuing the request or throws an Oppidum error
   LIMITATION: actually since we need to test on Key to distinguish between 
   a remote service invocation and a local service invocation, that means 
   you CANNOT put a Key element at second level in your payload !
   ====================================================================== 
:)
declare function match:get-host( $user as xs:string, $key as element()? ) as element()? {
  (: key test handles the situation where the user is logged into Coach Match 
     and into Case Tracker from the same browser at the same time :)
  if (($user eq 'guest') or $key) then (: must be a remote service invocation :)
    let $key-ref := services:get-key-ref-for('ccmatch-public', 'ccmatch.suggest', $key)
    return
      if ($key-ref) then
        $key-ref
      else
        oppidum:throw-error('CUSTOM', concat('Wrong host parameter "', $key ,'" in request, please contact an administrator !'))
  else (: default for local service invocation from Coach Match :)
    if (access:check-user-can('search', 'Coach')) then
      <KeyRef>0</KeyRef>
    else
      oppidum:throw-error('FORBIDDEN', ())
};

(: ======================================================================
   Returns true if the coach can be listed in search criteria 
   or can appear in a search result (internal coach match search by criteria,
   remote search by criteria or remote search by fit)
   NOTE: since 12/2016 lean preferences, the goal of the search (to propose
   a coaching activity or not) is no more significant, only the host is
   TODO: restrict internal search to curret host of current user
   QUESTION: also restrict internal search to coaches in working order ?
   ====================================================================== 
:)
declare function match:assert-coach( $c as element(), $host-ref as xs:string ) {
  if ($host-ref eq '0') then (: internal coach match search :)
    $c/Preferences/Visibility[@For eq $host-ref]/YesNoAcceptRef eq '1' (: implicitly invisible :)
  else if ($c/Hosts/Host[@For eq $host-ref][WorkingRankRef eq '1']) then (: must be accepted :)
    let $avail := $c/Preferences/Coaching[@For eq $host-ref]/YesNoAvailRef 
    return
      if (exists($avail)) then
        $avail eq '1'
      else
        true() (: implicitly available :)
  else 
    false()
};

(: FIXME: to be moved to stats :)
declare function match:gen-variable( $name as xs:string ) {
  let $set := fn:collection($globals:global-info-uri)/GlobalInformation/Description[@Lang = 'en']/Selector[@Name eq $name]
  let $id-node-name := if ($set/@Value) then string($set/@Value) else 'Id'
  let $id-node-label := if ($set/@Label) then string($set/@Label) else 'Name'
  return
    element { $name } {
      (
      for $v in $set/Option
      return
        <Labels>
          {
          let $token := $v/*[local-name(.) eq $id-node-label]/text()
          return
            if (contains($token, ' (')) then
              substring-before($token, ' (')
            else
              $token
          }
        </Labels>,
      for $v in $set/Option
      return
        <Values>{ $v/*[local-name(.) eq $id-node-name]/text() }</Values>
      )
    }
};

(: ======================================================================
   Utility to generate a matching block of a matching skill matrix
   from a sequence of values. The matching skill matrix is used as input
   for the experience match algorithm.
   ======================================================================
:)
declare function local:render-skill( $name as xs:string, $real-name as xs:string?, $refs as xs:string* ) as element()? {
  let $nb := count($refs)
  return
    if ($nb > 1) then
      <Matches For="{$name}">
        {
        if ($real-name) then attribute { 'From' } { $real-name } else (),
        for $r in $refs
        return <Match>{ $r}</Match>
        }
      </Matches>
    else if ($nb eq 1) then
      <Match For="{$name}">
        {
        if ($real-name) then attribute { 'From' } { $real-name } else (),
        $refs
        }
      </Match>
    else
      <Matches For="{$name}">
        { if ($real-name) then attribute { 'From' } { $real-name } else () }
      </Matches>
};

(: ======================================================================
   Converts criteria model (see seach-criteria.xml formular) to matching skills matrix
   DEPRECATED: criteria are now interpreted as binary criteria (no score)
   ======================================================================
:)
declare function match:criteria-to-skills-matrix( $criteria as element() ) as element() {
  <Skills For="SME-Context">
    {
    local:render-skill('DomainActivities', (), $criteria//DomainActivityRef/text()),
    local:render-skill('TargetedMarkets', (), $criteria//TargetedMarketRef/text()),
    local:render-skill('LifeCycleContexts', 'InitialContexts', $criteria/InitialContexts/ContextRef/text()),
    local:render-skill('LifeCycleContexts', 'TargetedContexts', $criteria/TargetedContexts/ContextRef/text()),
    local:render-skill('Services', (), $criteria//ServiceRef/text())
    }
  </Skills>
};

(: ======================================================================
   Converts SME needs analysis (see sme-profile.xml formular) to matching skills matrix
   ======================================================================
:)
declare function match:sme-context-to-skills-matrix( $needs-analysis as element() ) as element()? {
  let $nace-ref := $needs-analysis//DomainActivityRef
  let $targeted-mkt-refs := $needs-analysis//TargetedMarketRef
  let $initial-ctx-ref := $needs-analysis/Context/InitialContextRef
  let $targeted-ctx-ref := $needs-analysis/Context/TargetedContextRef
  let $service-ref := $needs-analysis//ServiceRef
  return
    <Skills For="SME-Context">
      {
      local:render-skill('DomainActivities', (), $nace-ref),
      local:render-skill('TargetedMarkets', (), $targeted-mkt-refs),
      local:render-skill('LifeCycleContexts', 'InitialContexts', $initial-ctx-ref),
      local:render-skill('LifeCycleContexts', 'TargetedContexts', $targeted-ctx-ref),
      local:render-skill('Services', (), $service-ref)
      }
    </Skills>
};

(: ======================================================================
   Converts CaseImpacts weights into a skills matrix. The skill matrix
   is used as input for the competence match algorithm.
   ======================================================================
:)
declare function match:weights-to-skills-matrix( $case-impacts as element()? ) as element()? {
  let $depth := count(tokenize(local-name($case-impacts/*[1]), '_'))
  return
    if ($depth eq 3) then (: <prefix_X_Y> encoded format :)
      data:encode-skills($case-impacts)
    else (: <root_Y> encoded format :)
      <Skills For="CaseImpacts">
      {
        for $model in fn:collection($globals:global-info-uri)//GlobalInformation/Description[@Lang = 'en']/CaseImpact/Sections/Section
        let $root := $model/SectionRoot/text()
        return
          <Skills For="{$model/Id}">
          {
            for $variable in $case-impacts/*[starts-with(local-name(.), $root)][. ne '']
            return
              <Skill For="{substring-after(local-name($variable), '-')}">{$variable/text()}</Skill>
          }
          </Skills>
      }
      </Skills>
};

(: ======================================================================
   Competence match algorithm iteration
   ======================================================================
:)
declare function local:competence-fit-iter( $iter as xs:string, $wanted as element(), $own as element()? ) as xs:float? {
  let $cur-w := $wanted/Skills[@For eq $iter]
  let $cur-o := $own/Skills[@For eq $iter]
  return
    if (empty($cur-w) or empty($cur-w/Skill)) then
      ()
    else
      let $fit :=
        avg(
          for $w in $cur-w/Skill[. ne '1']
          let $o := $cur-o/Skill[@For eq $w/@For]
          return
            let $effective-fit :=
              if ($w eq '3') then
                if ($o eq '3') then
                  4
                else if ($o eq '2') then
                  1
                else
                  0
              else (: assumes $w eq '2' :)
                if ($o eq '3') then
                  3
                else if ($o eq '2') then
                  2
                else
                  0
              let $theoritical-max :=
                if ($w eq '3') then
                  4
                else (: assumes $w eq '2' :)
                  3
            return
              $effective-fit div $theoritical-max
        )
      return
        if (empty($fit)) then () else $fit
};

(: ======================================================================
   Competence match algorithm
   ======================================================================
:)
declare function match:competence-fit( $wanted as element(), $own as element()? ) as xs:float {
  let $res :=
    avg((
      local:competence-fit-iter('1', $wanted, $own),
      local:competence-fit-iter('2', $wanted, $own),
      local:competence-fit-iter('3', $wanted, $own),
      local:competence-fit-iter('4', $wanted, $own)
    ))
  return
    if (empty($res)) then 1 else $res
};

(: ======================================================================
   Experience match algorithm effective fit
   ======================================================================
:)
declare function local:context-fit-value( $val as xs:string? ) as xs:float?
{
  if ($val) then
    let $effective-fit := (: assumes wanted skill is 3 :)
      if ($val eq '3') then
        4
      else if ($val eq '2') then
        1
      else
        0
    return
      $effective-fit div 4
  else
    0
};

(: ======================================================================
   Experience match algorithm iteration
   ======================================================================
:)
declare function local:context-fit-iter( $wanted as element(), $own as element()? ) as xs:float?
{
  if (exists($wanted/*)) then (: multiple values : Matches :)
    let $o := $own/Skills[@For eq $wanted/@For]
    return
      avg(
        for $each in $wanted/*
        let $match := $o//Skill[@For eq string($each)]/text()
        return local:context-fit-value($match)
      )
  else (: single value : Match :)
    if ($wanted eq '') then
      ()
    else
      let $match := $own/Skills[@For eq $wanted/@For]//Skill[@For eq string($wanted)]/text()
      return local:context-fit-value($match)
};

(: ======================================================================
   Experience match algorithm
   ======================================================================
:)
declare function match:context-fit( $wanted as element(), $own as element()? ) as xs:float? 
{
  let $res :=
    avg(
      for $m in $wanted/*
      return local:context-fit-iter($m, $own)
    )
  return
    if (empty($res)) then 1 else $res
};

(: ======================================================================
   Returns list of coaches with their match scores
   The host-ref and coaching parameters are used to implement coach preferences

   OPTIMIZATION:
   - double sort client-side (?)

   TODO:
   - hard-coded Coach role '4'
   - add $thresholds to filter coaches
   - normalize root name for challenges weights (CaseImpacts tabular vs. Weights needs analysis)
   ======================================================================
:)
declare function match:search-by-fit ( $sme-profile as element(), $host-ref as xs:string ) as element()* {
  let $match-competences := match:weights-to-skills-matrix($sme-profile/CaseImpacts) (: or Weights ? :)
  let $match-context := match:sme-context-to-skills-matrix($sme-profile)
  return
    for $c in fn:collection($globals:persons-uri)//Person[Skills][UserProfile//FunctionRef = '4']
    let $competence := round(match:competence-fit($match-competences, $c/Skills[@For eq 'CaseImpacts']) * 100)
    let $context := round(match:context-fit($match-context, $c) * 100)
    where match:assert-coach($c, $host-ref)
    order by $competence descending, $context descending
    return
      <Coaches>
      {
        $c/Id,
        if ($c/Information/Name/*) then $c/Information/Name else (),
        <Competence>{ $competence }</Competence>,
        (:<Performance>-</Performance>,:)
        (:<Languages>{ display:gen-name-for('EU-Languages', $c//EU-LanguageRef, 'en') }</Languages>,:)
        <Languages>{ string-join($c//EU-LanguageRef, ',') }</Languages>,
        <Context>{ $context }</Context>,
        <Country>{ $c/Information/Address/Country/text() }</Country>,
        <Perf>{ match:get-sme-rating($c, $host-ref) (:match:get-performance-score($c):) }</Perf>
      }
      </Coaches>
};

(: ======================================================================
   Classification of one coach own competence skill according to a given skill request
   Returns 3 (High), 2 (Medium) or 1 (None)
   Fallback to 1 in case no Skill
   ======================================================================
:)
declare function local:get-competence-detail-for(
  $wanted as xs:string,
  $section as xs:string,
  $subsection as xs:string,
  $own as element()?
  ) as xs:integer
{
  let $match := $own/Skills[@For eq $section]/Skill[@For eq $subsection]
  return
    if ($wanted eq '3') then
      if ($match eq '3') then
        3
      else  if ($match eq '2') then
        1
      else
        1
    else (: assumes $wanted eq '2' :)
      if ($match eq '3') then
        3
      else  if ($match eq '2') then
        2
      else
        1
};

(: TODO: move to display.xqm :)
declare function local:gen-name-for-competence( $section as xs:string, $subsection as xs:string? ) as xs:string {
  let $s-model := fn:collection($globals:global-info-uri)//GlobalInformation/Description[@Lang = 'en']/CaseImpact/Sections/Section[Id eq $section]
  return
    if ($subsection) then
      let $sub-model := $s-model/SubSections/SubSection[Id eq $subsection]
      return $sub-model/SubSectionName/text()
    else
      $s-model/SectionName/text()
};

(: ======================================================================
   Returns individual coach competences (Summary and Details)
   against wanted SME request

   TODO: read labels from Global-Information
   ======================================================================
:)
declare function match:get-competences-fit ( $key as xs:string, $coach as element(), $wanted as element() ) as element()* {
  let $own := $coach/Skills[@For eq 'CaseImpacts']
  let $fit1 := local:competence-fit-iter('1', $wanted, $own)
  let $fit2 := local:competence-fit-iter('2', $wanted, $own)
  let $fit3 := local:competence-fit-iter('3', $wanted, $own)
  let $fit4 := local:competence-fit-iter('4', $wanted, $own)
  return
    <Dimension Key="{ $key }">
      <Summary For="Competence fit indicators">
        <Average>
          { 
          let $avg := round(avg(($fit1, $fit2, $fit3, $fit4 )) * 100)
          return if (empty($avg)) then 'n/a' else $avg
          }
        </Average>
        <Axis For="Business innovation vectors">
          <Score>{ if (exists($fit1)) then round($fit1 * 100) else 'x' }</Score>
        </Axis>
        <Axis For="Source of business ideas">
          <Score>{ if (exists($fit2)) then round($fit2 * 100) else 'x' }</Score>
        </Axis>
        <Axis For="Internal resources">
          <Score>{ if (exists($fit3)) then round($fit3 * 100) else 'x' }</Score>
        </Axis>
        <Axis For="Partnerships">
          <Score>{ if (exists($fit4)) then round($fit4 * 100) else 'x' }</Score>
        </Axis>
      </Summary>
      {
        for $skills in $wanted/Skills
        return
          <Details For="{local:gen-name-for-competence($skills/@For, ())}">
          {
            for $skill in $skills/Skill[. ne '1']
            return
              <Skills For="{local:gen-name-for-competence($skills/@For, $skill/@For)}">
                <Fit json:literal='true'>{ local:get-competence-detail-for($skill/text(), $skills/@For, $skill/@For, $own) }</Fit>
              </Skills>
          }
          </Details>
      }
    </Dimension>
};

(: TODO: move to display.xqm - store localized names in dictionary instead of @Legend ? :)
declare function local:gen-name-for-selector( $name as xs:string, $lang as xs:string ) as xs:string {
  string(fn:collection($globals:global-info-uri)//GlobalInformation/Description[@Lang = 'en']/Selector[@Name eq $name]/@Legend)
};

(: ======================================================================
   Returns individual coach competences (Summary and Details)
   against wanted SME request

   FIXME: Summary for debug purpose only (?)
   TODO: read labels from Global-Information
   TODO: normalize root name for challenges weights (CaseImpacts tabular vs. Weights needs analysis)
   ======================================================================
:)
declare function match:get-experiences-fit ( $key as xs:string, $coach as element(), $wanted as element() ) as element()* {
  <Dimension Key="{ $key }">
    <Summary For="SME context fit indicators">
      {
      for $match in $wanted/*
      return
        <Axis For="{local:gen-name-for-selector(if ($match/@From) then $match/@From else $match/@For, 'en')}">
          <Score>
            {
              let $fit := local:context-fit-iter($match, $coach)
              return
                if (empty($fit)) then 'x' else round($fit * 100)
            }
          </Score>
        </Axis>
      }
      <Average>{ round(match:context-fit($wanted, $coach) * 100) }</Average>
    </Summary>
    {
    for $match in $wanted/*
    let $own := $coach/Skills[@For eq $match/@For]
    let $type := if ($match/@From) then string($match/@From) else string($match/@For)
    return
      <Details For="{local:gen-name-for-selector($type, 'en')}">
      {
        if (exists($match/*)) then (: two levels skills :)
          for $skill in $match//Match
          return
            <Skills For="{ display:gen-name-for($type, $skill, 'en')} ">
              <Fit json:literal='true'>
                { 
                let $self := $own//Skill[@For eq $skill/text()]
                return
                  if ($self) then 
                    $self/text()
                  else (: fallback to no expertise :)
                    1
                }
              </Fit>
            </Skills>
        else (: one level skills :)
          <Skills For="{ display:gen-name-for($type, $match, 'en') }">
            <Fit json:literal='true'>
              { 
              let $self := $own//Skill[@For eq $match/text()]
              return
                if ($self) then 
                  $self/text()
                else (: fallback to no expertise :)
                  1
              }
            </Fit>
          </Skills>
      }
      </Details>
    }
  </Dimension>
};

(: ======================================================================
   Computes the global performance score (%) for the coach as a string

   Returns :
   - "A,C,T" with A the average mean of all the means of all the feeds summary 
     only taking into account summaries where the means are significant (i.e. not 0)
   - "n/c,0,T" if there is at least one significant mean in a feed summary
     but no feed summary is complete
   - "n/a,0,T" when the coach only received empty evaluations (i.e case was closed 
     w/o evaluation)
   - "-" no evaluation received on any feed
   in all cases above C is the number of complete individual evaluations received 
   and T is the toatl of all the evaluations received

   Pre-condition: all means in feeds are a value from 1 (low) to 5 (high)

   NOTE: we could pass only feeds element but we found safer to disjonct $stats 
   when updating to be sure to compute with latest value
   ======================================================================
:)
declare function match:calc-performance-score ( $feeds as element()?, $stats as element()* ) as xs:string? {
  let $total := count($feeds//Evaluation)
  let $count := count($feeds//Evaluation[not(Stats/Mean eq '0')]) (: complete evaluation :)
  return
    if (some $m in $stats/Mean satisfies $m ne '0') then (: should be equivalent to $count > 0 :)
      let $score :=
        avg(
          for $s in $stats
          where every $m in $s/Mean satisfies $m ne '0'
          return avg($s/Mean)
        )
      return
        if (exists($score)) then 
          concat(string(round(($score - 1) * 25)), ',', $count, ',', $total)
        else (: not complete :)
          concat('n/c', ',', $count, ',', $total)
    else if (count($feeds//Evaluation[Stats/Mean ne '0']) > 0) then
      concat('n/c', ',', $count, ',', $total) (: count should be 0 :)
    else if ($total > 0) then
      concat('n/a', ',', $count, ',', $total) (: count should be 0 :)
    else
      '-'
};

(: ======================================================================
   Returns the cached global performance score (%) for the coach as a string
   or dynamically computes and return it (does not cache it anyway)
   ======================================================================
:)
declare function match:get-performance-score ( $coach as element() ) as xs:string? {
  if (exists($coach/Feeds/@Perf)) then
    string($coach/Feeds/@Perf)
  else
    match:calc-performance-score($coach/Feeds, $coach/Feeds/Feed/Stats)
};

(: ======================================================================
   Returns the mean score for a given dimension filter or 0 if it does not exists
   ====================================================================== 
:)
declare function match:get-score-for ( $filter as xs:string, $coach as element(), $host-ref as xs:string ) as xs:double {
  let $stats := $coach/Feeds/Feed[@For eq $host-ref]/Stats/Mean[@For eq $filter][. ne '0']
  return
    if (exists($stats)) then
      let $score := number($stats/text())
      return
        if (string($score) eq 'NaN') then
          0
        else
          round($score * 100) div 100
    else
      0
};

(: ======================================================================
   Returns the cached SME rating and the total number of evaluations 
   as a comma-separated list
   FIXME: do not use $host-ref but take average between hosts ?
   TODO: merge with match:print-sme-rating
   ======================================================================
:)
declare function match:get-sme-rating ( $coach as element(), $host-ref as xs:string ) as xs:string? {
  let $stats := $coach/Feeds/Feed[@For eq $host-ref]/Stats/Mean[@For eq 'SME'][. ne '0']
  return
    if (exists($stats)) then
      let $score := xs:decimal($stats/text())
      return
        if (string($score) eq 'NaN') then
          '-'
        else
          concat(round($score * 100) div 100, ',', $stats/@Count)
    else
    '-'
};

(: ======================================================================
   Returns the cached SME rating followed by the total number of evaluations 
   between parenthesis
   FIXME: do not use $host-ref but take average between hosts ?
   ======================================================================
:)
declare function match:print-sme-rating ( $coach as element(), $host-ref as xs:string ) as xs:string? {
  let $stats := $coach/Feeds/Feed[@For eq $host-ref]/Stats/Mean[@For eq 'SME'][. ne '0']
  return
    if (exists($stats)) then
      let $score := xs:decimal($stats/text())
      return
        if (string($score) eq 'NaN') then
          '-'
        else
          concat(round($score * 100) div 100, ' (', $stats/@Count, ')')
    else
    '-'
};

declare function local:filter-out-stopwords( $keywords as xs:string* ) as xs:string* {
  let $stopwords := ('a', 'an', 'and', 'are', 'as', 'at', 'be', 'but', 'by', 'for', 'if', 'in', 'into', 'is', 'it', 'no', 'not', 'of', 'on', 'or', 'such', 'that', 'the', 'their', 'then', 'there', 'these', 'they', 'this', 'to', 'was', 'will', 'with')
  return 
    for $word in tokenize( $keywords, '\s+')
    return $word[not(. = $stopwords)]
};


declare function local:build-query-for-fts( $keywords as xs:string* ) as element() {
  let $filtered-kw := local:filter-out-stopwords( $keywords )
  return
    <query>
    {
      for $kw in $filtered-kw
      return
        if (matches($kw, '[\*\?]')) then
          if (string-length($kw) > 4) then
            <wildcard>{$kw}</wildcard>
          else
            ()
        else
        <term>{$kw}</term>
    }
    </query>
};

(: ======================================================================
   Returns a map of coach {id : <Summ/>)} matching criteria and visible for host ref
   Match to levels of expertise as coded in global information
   TODO:
   - hard-coded Coach role '4'
   ====================================================================== 
:)
declare function match:search-by-criteria-ids( $criteria as element(), $levels as xs:string*, $host-ref as xs:string ) as map {
  map:new(
    (: Coach dimension :)
    let $person := $criteria//CoachRef/text()
    let $country := $criteria//Country/text()
    let $spoken := $criteria//EU-LanguageRef/text()
    (: SME context :)
    let $domain := $criteria//DomainActivityRef/text()
    let $market := $criteria//TargetedMarketRef/text()
    let $context := $criteria//ContextRef/text() (: initial or targeted :)
    let $service := $criteria//ServiceRef/text()
    let $fts-query := local:build-query-for-fts(tokenize($criteria//Keywords, '[,\s]+'))
    let $no-fts := empty($fts-query//(term|wildcard))
    (: Business innovation :)
    let $vector := $criteria//VectorRef/text()
    let $vector-nb := count($vector)
    let $idea := $criteria//IdeaRef/text()
    let $idea-nb := count($idea)
    let $resource := $criteria//ResourceRef/text()
    let $resource-nb := count($resource)
    let $partner := $criteria//PartnerRef/text()
    let $partner-nb := count($partner)
    return
      for $c in fn:collection($globals:persons-uri)//Person[Skills][UserProfile//FunctionRef = '4']
      let $bi := $c/Skills[@For eq 'CaseImpacts']
      let $hit := if ($no-fts) then () else $c//CurriculumVitae[ft:query(Summary, $fts-query)]
      where (empty($person) or ($c/Id = $person))
        and match:assert-coach($c, $host-ref)
        and (empty($country) or ($c/Information/Address/Country = $country))
        (: ALL following criteria internally evaluated with OR :)
        and (empty($spoken)
            or ($c//EU-LanguageRef = $spoken))
            (:or (every $s in $spoken satisfies exists($c//EU-LanguageRef[. eq $s]))):)
        (: Business innovation - FIXME: hard coded encoding :)
        and (empty($vector)
            or exists($bi/Skills[@For eq '1']/Skill[@For = $vector and . = $levels]))
            (:or (every $v in $vector satisfies exists($bi/Skills[@For eq '1']/Skill[@For eq $v][. = $levels]))):)
        and (empty($idea)
            or exists($bi/Skills[@For eq '2']/Skill[@For = $idea and . = $levels]))
            (:or (every $i in $idea satisfies exists($bi/Skills[@For eq '2']/Skill[@For eq $i][. = $levels]))):)
        and (empty($resource)
            or exists($bi/Skills[@For eq '3']/Skill[@For = $resource and . = $levels]))
            (:or (every $r in $resource satisfies exists($bi/Skills[@For eq '3']/Skill[@For eq $r][. = $levels]))):)
        and (empty($partner)
            or exists($bi/Skills[@For eq '4']/Skill[@For = $partner and . = $levels]))
            (:or (every $p in $partner satisfies exists($bi/Skills[@For eq '4']/Skill[@For eq $p][. = $levels]))):)
        (: SME context :)
        and (empty($domain)
            or exists($c/Skills[@For eq 'DomainActivities']//Skill[@For = $domain and . = $levels]))
            (:or (every $d in $domain satisfies exists($c/Skills[@For eq 'DomainActivities']//Skill[@For eq $d ][. = $levels]))):)
        and (empty($market)
            or exists($c/Skills[@For eq 'TargetedMarkets']//Skill[@For = $market and . = $levels]))
            (:or (every $m in $market satisfies exists($c/Skills[@For eq 'TargetedMarkets']//Skill[@For eq $m ][. = $levels]))):)
        and (empty($context)
            or exists($c/Skills[@For eq 'LifeCycleContexts']//Skill[@For = $context and . = $levels]))
            (:or (every $co in $context satisfies exists($c/Skills[@For eq 'LifeCycleContexts']/Skill[@For eq $co][. = $levels]))):)
        and (empty($service)
            or exists($c/Skills[@For eq 'Services']//Skill[@For = $service and . = $levels]))
        and ($no-fts or $hit)
      return
        map:entry(
          string($c/Id), 
          if ($hit) then 
            let $exp := kwic:expand($hit)
            return 
              if ($exp//exist:match) then
                <Summ>
                {
                  for $i in $exp//Summary/node()
                  return
                    if ($i instance of element()) then <txt match="1">{fn:translate(string($i), '&#9;', ' ')}</txt> else if (string-length($i) > 0) then <txt>{ fn:translate($i, '&#9;', ' ') }</txt> else ()
                }
                </Summ>
              else
                <Summ><txt>{ fn:translate(string($exp), '&#9;', ' ') }</txt></Summ>
                (:<Summ>{ local:expand( fn:translate('', '&#9;', ' '), local:wildcard-to-regex($fts-query//wildcard[1])) }</Summ>:)
          else
            ()
        )
  )
};

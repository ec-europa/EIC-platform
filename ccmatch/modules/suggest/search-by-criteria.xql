xquery version "3.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Suggestion of coaches against an SME profile

   Input when called as a service :

      <Match | Search>
        <Key>host key</Key>
        <SearchByCriteria>...</SearchByCriteria>
      </Match | Search>

   Input when called directly from Coach Match (authentified user) :

      <SearchByCriteria>...</SearchByCriteria>

   Note that actually the Criteria search does not make any score against the SME needs

   September 2015 - (c) Copyright may be reserved
   ----------------------------------------------- :)

declare namespace json="http://www.json.org";

declare namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace match = "http://oppidoc.com/ns/match" at "match.xqm";

declare option exist:serialize "method=json media-type=application/json";

(: ======================================================================
   Generates coach sample to display in criteria results table
   Warning: you should set a range index on Id on persons collection
   FIXME: actually SME rating from SME Instrument only !
   ====================================================================== 
:)
declare function local:gen-coach-sample( $c as element(), $context as element()?, $host as xs:string ) as element()* {
  <Coaches>
  {
    $c/Id,
    if ($c/Information/Name/*) then $c/Information/Name else (),
    <Languages>{ string-join($c//EU-LanguageRef, ',') }</Languages>,
    <Country>{ $c/Information/Address/Country/text() }</Country>,
    $context,
    <Perf>{ match:get-sme-rating($c, '1') (:match:get-performance-score($c):) }</Perf>
  }
  </Coaches>
};

declare function local:gen-coach-samples( $ids as map, $host as xs:string ) as element()* {
  map:for-each-entry($ids,
    function($key, $sum) {
      let $c := fn:collection($globals:persons-uri)//Person[Id eq $key]
      return
        local:gen-coach-sample($c, $sum, $host)
    })
};

(: ======================================================================
   DEPRECATED performs better when no index
   Match to levels of expertise as coded in global information
   TODO:
   - hard-coded Coach role '4'
   ====================================================================== 
:)
declare function local:search-by-criteria( $criteria as element(), $levels as xs:string*, $host-ref as xs:string ) as element()* {
  (: Competence dimension :)
  (:let $needs-analysis := $submitted/Match:)
  (:let $match-competences := match:weights-to-skills-matrix($needs-analysis/CaseImpacts) :)
  (: Experience - SME Context - dimension :)
  (:let $match-context := match:sme-context-to-skills-matrix($needs-analysis):)
  (: Criteria dimension :)
  (:let $match-criteria := match:criteria-to-skills-matrix($criteria):)
  (: Criteria :)
  let $person := $criteria//CoachRef/text()
  let $country := $criteria//Country/text()
  let $spoken := $criteria//EU-LanguageRef/text()
  (: SME context :)
  let $domain := $criteria//DomainActivityRef/text()
  let $market := $criteria//TargetedMarketRef/text()
  let $context := $criteria//ContextRef/text() (: initial or targeted :)
  let $service := $criteria//ServiceRef/text()
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
          (:or (every $s in $service satisfies exists($c/Skills[@For eq 'Services']/Skill[@For = $s][. = $levels]))):)
    return
      local:gen-coach-sample($c, (), $host-ref)
};

(: ======================================================================
   Returns SearchByCriteria data independently of where the service is called from
   ====================================================================== 
:)
declare function local:get-submitted ( $data as element()?, $host-ref as xs:string ) {
  if ($host-ref eq '0') then
    $data
  else
    $data/SearchByCriteria
};

(: FIXME: fix $axel.oppidum.handleMessage to support responses w/o message :)
let $user := oppidum:get-current-user()
let $search := match:get-data($user, 'ccmatch.suggest') (: FIXME: shared with ccmatch.search :)
return
  if (local-name($search) ne 'error') then
    let $host := match:get-host($user, $search/Key)
    return
      if (local-name($host) ne 'error') then
        let $submitted := local:get-submitted($search, $host)
        let $expertise := $submitted/Expertise/text()
        let $groups := oppidum:get-user-groups($user, oppidum:get-current-user-realm()) (:FIXME: temporary :)
        return
          if (empty($submitted/*/*) and not($groups = 'admin-system') and ($host eq '0')) then
            oppidum:throw-error('CUSTOM', 'You must select at least 1 criteria !')
          else (
            if ($submitted/@Accepted eq 'XML') then (: by pass JSON :)
              util:declare-option("exist:serialize", "method=xml media-type=text/xml indent=no")
            else
              (),
            <success>
              <message>Search done</message>
              <payload>
                <MatchResults Table="criteria" Keywords="{$submitted/Keywords}">
                  {
                  let $levels := if ($expertise eq 'high') then '3' else ('2', '3')
                  return
                    (:local:search-by-criteria($submitted, $levels, $host):)
                    local:gen-coach-samples(match:search-by-criteria-ids($submitted, $levels, $host), $host)
                  }
                  <Variables>
                    {
                    match:gen-variable('EU-Languages'),
                    match:gen-variable('Countries')
                    }
                  </Variables>
                </MatchResults>
              </payload>
            </success>
            )
      else
        $host
  else
    $search

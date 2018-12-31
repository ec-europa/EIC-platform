xquery version "3.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Implements Ajax protocol for suggestion of coaches against an SME profile
   or for searching a coaches against an SME profile

   Input when called as a service (cm-suggest.js) :

      <Match | Search>
        <Key>host key</Key>
        <SearchByFit>...</SearchByFit>
      </Match | Search>

   DEPRECATED Input when called directly from Coach Match (authentified user, cm-search.js) :

      <SearchByFit>...</SearchByFit>

   September 2015 - (c) Copyright may be reserved
   ----------------------------------------------- :)

declare namespace json="http://www.json.org";

declare namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace match = "http://oppidoc.com/ns/match" at "match.xqm";
import module namespace analytics = "http://oppidoc.com/ns/analytics" at "../../../excm/modules/analytics/analytics.xqm";

declare option exist:serialize "method=json media-type=application/json";

(: ======================================================================
   Generates coach sample to display in fit results table
   WARNING: you should set a range index on Id on persons collection
   OPITIMIZATION: for refinement search client could remember scores 
   and we could avoid recomputing them (see cm-suggest.js) !
   SEE ALSO: match:search-by-fit returns the same record
   ====================================================================== 
:)
declare function local:gen-coach-sample( $c as element(), $competence as xs:float, $context as xs:float, $host as xs:string ) as element()* {
  <Coaches>
  {
    $c/Id,
    if ($c/Information/Name/*) then $c/Information/Name else (),
    <Competence>{ $competence }</Competence>,
    <Languages>{ string-join($c//EU-LanguageRef, ',') }</Languages>,
    <Context>{ $context }</Context>,
    <Country>{ $c/Information/Address/Country/text() }</Country>,
    <Perf>{ match:get-sme-rating($c, $host) (:match:get-performance-score($c):) }</Perf>
  }
  </Coaches>
};

declare function local:gen-coach-samples( $sme-profile as element(), $ids as map, $host as xs:string ) as element()* {
  let $match-competences := match:weights-to-skills-matrix($sme-profile/CaseImpacts)
  let $match-context := match:sme-context-to-skills-matrix($sme-profile)
  return
  
    map:for-each-entry($ids,
      function($key, $sum) {
        let $c := fn:collection($globals:persons-uri)//Person[Id eq $key]
        let $competence := round(match:competence-fit($match-competences, $c/Skills[@For eq 'CaseImpacts']) * 100)
        let $context := round(match:context-fit($match-context, $c) * 100)
        return
          local:gen-coach-sample($c, $competence, $context, $host)
      })
};

(: FIXME: fix $axel.oppidum.handleMessage to support responses w/o message :)
let $user := oppidum:get-current-user()
let $search := match:get-data($user, 'ccmatch.suggest')
return
  if (local-name($search) ne 'error') then
    let $host := match:get-host($user, $search/Key)
    return
      if (local-name($host) ne 'error') then
        <success>
          <message>Search done</message>
          <payload>
            <MatchResults Table="fit">
              { 
              if ($host ne '0') then (: suggestion for coaching :)
                if ($search/SearchByCriteria and (not(empty($search/SearchByCriteria/*/*)) or $search/SearchByCriteria/Keywords ne '')) then (: refinement :)
                  (: TODO: only return IDs and cache them in cm-suggest.js :)
                  let $levels := if ($search/SearchByCriteria/Expertise eq 'high') then '3' else ('2', '3')
                  return
                    analytics:save-request(
                      $host, 'coach-refine-fit-search', $search, (), 20,
                      local:gen-coach-samples($search/SearchByFit,
                        match:search-by-criteria-ids($search/SearchByCriteria, $levels, $host),
                        $host
                        )
                      )
                else (: no refinement :)
                  analytics:save-request(
                    $host, 'coach-fit-search', $search, (), 20,
                    match:search-by-fit($search/SearchByFit, $host)
                    )
              else (: DEPRECATED UNPLUGGED simple search :)
                match:search-by-fit ($search, $host) 
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
      else
        $host
  else
    $search

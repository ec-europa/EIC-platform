xquery version "3.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Report console GUI.

   Table view of all reports with report statistics and link to call the API 
   to run report or generate excel.

   Limitation :
   - DO NOT run two report generation on the same report in // !
     (we suspect this to cause duplicated entries)

   Glossary :
   - Pivot : a node that generates 0 or more samples
   - Orphan : a pivot node without child samples
   - Sample : a sample generated either from an orphan pivot or from a pivot
   - Dirty (sample) : a sample who is not fresh (as per report:expired function)
   - an invariant : Sample = Orphan + Pivotable (= max. number of rows in report cache)

   May 2015 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

import module namespace request="http://exist-db.org/xquery/request";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace miscellaneous = "http://oppidoc.com/ns/miscellaneous" at "../../../excm/lib/misc.xqm";
import module namespace report = "http://oppidoc.com/ns/cctracker/reports" at "report.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

declare function local:as-number( $n as xs:string?, $default as xs:double ) {
  let $res := number($n)
  return
    if (string($res) eq 'NaN') then
      $default
    else
      $res
};

(: ======================================================================
   Utility function to create a cache of XPath expressions to compute 
   some reports stats only once
   ====================================================================== 
:)
declare function local:encache-totals ( $reports as element()? ) {
  map:new((
    let $targets := $reports/Report/Target
    let $expressions := distinct-values(
      for $t in $targets
      let $object-xpath := concat('fn:collection("/db/sites/cctracker/', $t/Subject/@Collection, '")', $t/Object)
      let $col-path := concat('fn:collection("/db/sites/cctracker/', $t/Subject/@Collection, '")')
      let $pivotable := concat($t/Pivot/@Parent, '/', $t/Pivot)
      let $orphan-xpath := concat($col-path, $t/Object, '[not(', $pivotable, ')]')
      let $pivotable-xpath := concat($col-path, $t/Object, '/', $pivotable)
      return 
        ($object-xpath, $orphan-xpath, $pivotable-xpath)
      )
    return
        for $e in $expressions
        return map:entry($e, util:eval(concat('count(', $e, ')')))
  ))
};

(: ======================================================================
   Generate a list of reports and associated stats to shozw in reports console
   ====================================================================== 
:)
declare function local:list-reports() {
  let $meta := fn:doc(concat($globals:reports-uri, '/', 'meta.xml'))/Meta
  let $reports := fn:doc(oppidum:path-to-config('reports.xml'))/Reports
  let $min := request:get-parameter('min', 0)
  let $max := request:get-parameter('max', 'no limit')
  let $freshness := miscellaneous:get-property('reports', 'freshness', 'PT86400S')
  let $stats-cache := local:encache-totals($reports) (: small optimization :)
  return
    <Reports>
      <Menu Freshness="{$freshness}" Min="{$min}" Max="{$max}"/>
      {
      for $report in $reports/Report
      let $t := $report/Target
      let $cached := fn:collection($globals:reports-uri)/Report[@No eq $report/@No]
      let $dirty-xpath := concat('fn:doc("', $globals:reports-uri, '/', $report/@No, '.xml")', $t/Object, '[report:expired(.)]')
      let $sealed := count($cached/*/@Seal)
      (: below paths same as local:encache-totals to compute only once totals :)
      let $object-xpath := concat('fn:collection("/db/sites/cctracker/', $t/Subject/@Collection, '")', $t/Object)
      let $col-path := concat('fn:collection("/db/sites/cctracker/', $t/Subject/@Collection, '")')
      let $pivotable := concat($t/Pivot/@Parent, '/', $t/Pivot)
      let $orphan-xpath := concat($col-path, $t/Object, '[not(', $pivotable, ')]')
      let $pivotable-xpath := concat($col-path, $t/Object, '/', $pivotable)
      return
        <Report Running="{ count(fn:collection($globals:reports-uri)/Report[@Duration eq '...']) }">
          <No>{ string($report/@No) }</No>
          { $report/(Title | Note) }
          <CacheSamples>{ count($cached/*) }</CacheSamples>
          <CachePivots>{ count(distinct-values($cached/*/@Key)) }</CachePivots>
          <TotalPivots path="{$object-xpath}">{ map:get($stats-cache, $object-xpath) }</TotalPivots>
          <TotalSamples>
            { 
            sum((
              if ($report/Target/Object/@Include eq 'no') then () else map:get($stats-cache, $orphan-xpath),
              map:get($stats-cache, $pivotable-xpath)
              ))
            }
          </TotalSamples>
          <TotalOrphans path="{$orphan-xpath}">{ map:get($stats-cache, $orphan-xpath) }</TotalOrphans>
          <TotalPivoted path="{$pivotable-xpath}">{ map:get($stats-cache, $pivotable-xpath) }</TotalPivoted>
          <Orphans>{ if ($report/Target/Object/@Include eq 'no') then 'not included' else 'included'  }</Orphans>
          <Start>{ string($cached/@StartGeneration) }</Start>
          <Duration>{ string($cached/@Duration) }</Duration>
          <LastRun>{ string($cached/@LastRun) }</LastRun>
          <Insert>{ string($cached/@Insert) }</Insert>
          <Replace>{ string($cached/@Replace) }</Replace>
          <Delete>{ string($cached/@Delete) }</Delete>
          <Hit>{ string($cached/@Hit) }</Hit>
          { $meta/Errors[@ReportRef eq $report/@No] }
          { if ($cached/@Orphan) then <Orphan>{ string($cached/@Orphan) }</Orphan> else () }
          { if ($cached/@Pivotable) then <Pivotable>{ string($cached/@Pivotable) }</Pivotable> else () }
          <Dirty>{ util:eval(concat('count(', $dirty-xpath, ')')) }</Dirty>
          <Sealed>{ $sealed }</Sealed>
        </Report>
      }
    </Reports>
};

(: *** MAIN ENTRY POINT *** :)
local:list-reports()

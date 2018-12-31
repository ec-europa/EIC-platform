xquery version "1.0";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../lib/globals.xqm";
import module namespace stats = "http://oppidoc.com/ns/cctracker/stats" at "../modules/stats/stats.xqm";

(:declare option exist:serialize "method=json media-type=application/json";:)

let $cases := fn:collection($globals:cases-uri)/Case
return
  <Tests>
    {
    let $filter-spec-uri := oppidum:path-to-config('stats.xml')
    let $stats-spec := fn:doc($filter-spec-uri)/Statistics/Filters/Filter[@Page = 'kpi']
    return
      (
      for $d in $stats-spec//*[local-name(.) ne 'Composition'][@Selector]
      return 
        <Test Name="{ $d }">{ stats:gen-selector-domain($d, $d/@Selector, $d/@Format) }</Test>,
      for $d in $stats-spec//*[@WorkflowStatus]
      return stats:gen-workflow-status-domain($d, $d/@WorkflowStatus),
      for $d in $stats-spec//*[@Persons]
      let $tag := string($d)
      let $refs := ('1', '2', '3', '4', '5')
      return stats:gen-persons-domain-for($refs, 'Person'),
      stats:gen-year-domain($cases),
      for $i in $stats-spec/Charts/Chart/Vector[@Domain eq 'CaseImpact']
      return
        stats:gen-case-vector($i/text(), string($i/@Section))
        )
    }
  </Tests>

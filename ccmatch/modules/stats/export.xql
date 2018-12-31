xquery version "1.0";
(: ------------------------------------------------------------------
   CCMATCH - EIC Coach Match Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Statistical table export

   OPTIMIZATIONS:
   - replace direct compressed table generation (<td class="xy">) 
     with embedded JSON + d3.js generation (?)

   January 2016 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

declare namespace site = "http://oppidoc.com/oppidum/site";

import module namespace xdb="http://exist-db.org/xquery/xmldb";

import module namespace util="http://exist-db.org/xquery/util";
import module namespace epilogue = "http://oppidoc.com/oppidum/epilogue" at "../../../oppidum/lib/epilogue.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace stats = "http://oppidoc.com/ns/cctracker/stats" at "stats.xqm";
import module namespace match = "http://oppidoc.com/ns/match" at "../suggest/match.xqm";


declare variable $local:separator := '; ';
declare variable $local:weight-thresholds := ('2', '3');

(: TODO: declare colors for columns inside stats.xml :)
declare variable $local:cols-name := ('none', 'coach', 'status', 'case', 'priorities', 'needs', 'kpi');
declare variable $local:cols-backgrounds := ('#FFF', '#F5E0FF', '#C2FFFF', '#99C2EB', '#E6AAF2', '#83D6C3', '#B5C04F');

(: ======================================================================
   Returns the name of the current user as First name Last name or falls back to user login
   ======================================================================
:)
declare function local:gen-current-person-name() as xs:string? {
  let $p := access:get-current-person()
  return
    if ($p) then
      display:gen-person-name($p, 'en')
    else
      oppidum:get-current-user()
};

(: ======================================================================
   TODO: fallback to warning if no Email
   ======================================================================
:)
declare function local:gen-person-email( $p as element() ) as element() {
  let $info := $p/Information
  return
    <a href="mailto:{$info/Contacts/Email}">{ $info/Contacts/Email }</a>
};

declare function local:gen-phone( $contacts as element()? ) as xs:string? {
  string-join(($contacts/Phone, $contacts/Mobile), ', ')
};

(: ======================================================================
   Returns a Variables structure for un$target as xs:string, $action as xs:string, $mode as xs:string?$target as xs:string, $action as xs:string, $mode as xs:string?$target as xs:string, $action as xs:string, $mode as xs:string?referencing labels client side in export table

   Note the first string must corresponds to a class name on the td host element

  { stats:gen-case-vector('vct', '1') }
  { stats:gen-case-vector('sci', '2') }
  { stats:gen-case-vector('rsc', '3') }
  { stats:gen-case-vector('prt', '4') }
   ======================================================================
:)
declare function local:gen-variables( ) as element() {
  <Variables>
    {
    stats:gen-selector-domain('co', 'Countries'),
    stats:gen-selector-domain('lg', 'EU-Languages'),
    stats:gen-selector-domain('sv', 'Services'),
    stats:gen-selector-domain('as', 'Acceptances'),
    stats:gen-selector-domain('wr', 'WorkingRanks'),
    stats:gen-selector-domain('av', 'YesNoAvails'),
    stats:gen-selector-domain('vs', 'YesNoAccepts'),
    stats:gen-selector-domain('es', 'ExpertiseScales')
  }
  </Variables>
};

(: ======================================================================
   Returns a <script> element to insert at the end of the export tables
   for client side decompression of labels
   Optimization to lower results table weight and to server processing
   ======================================================================
:)
declare function local:gen-decompress-script( ) as element() {
  let $DB :=  <DB>{ local:gen-variables() }</DB>
  let $string := util:serialize($DB, 'method=json')
  return
    <script type="text/javascript">
DB = { $string };

function decodeLabel ( varname, value ) {{
var convert = DB.Variables[varname], trans, pos, output, res = "";
if (convert) {{
trans = convert.Values || convert,
pos = trans.indexOf(value),
output = convert.Labels || convert;
res = output[pos] ? output[pos].replace('amp;', '') : value;
}}
return res;
}}

function uncompress (klass) {{
var i, cur;
while (cur = klass.pop()) {{
$('td.' + cur).each( function (i, e) {{
var n = $(e), v = n.attr('class'), src = n.text(), input = src.split("{$local:separator}"), output = [], k;
while (k = $.trim(input.pop())) {{
output.push(decodeLabel(v, k));
}}
n.text(output.join("{$local:separator}"));
}}
);
}}
}}

function uncompressWeights (klass) {{
  var cur;
  while (cur = klass.pop()) {{
    $('td.' + cur).each( function (i, e) {{
    var n = $(e), nn = n.next('td').first(); src = n.text();
    n.text(src.replace(/(\d+)#(\d+)/g, function(a, variable, value) {{ var res = decodeLabel(cur.substr(1), variable); return value === '2' ? res : ''; }}).split("; ").filter(function (n) {{ return n === "" ? false : true; }}).join('; '));
    nn.text(src.replace(/(\d+)#(\d+)/g, function(a, variable, value) {{ var res = decodeLabel(cur.substr(1), variable); return value === '3' ? res : ''; }}).split("; ").filter(function (n) {{ return n === "" ? false : true; }}).join('; '));
    }}
    );
  }}
}}

function uncompressServices (klass) {{
  var cur;
  while (cur = klass.pop()) {{
    $('td.' + cur).each( function (i, e) {{
      var n = $(e), src = n.text();
      window.console.log(src);
      n.text(
        src.replace(/(\d+)#(\d+)/g, 
          function(a, variable, value) {{ 
            var res = decodeLabel(cur, variable); 
            return res + ' (' + decodeLabel('es', value) + ')';
          }}
        )
      );
      }}
    );
  }}
}}

uncompress(['co', 'lg', 'as', 'wr', 'av', 'vs']);
uncompressServices(['sv'])
</script>
};

(: ======================================================================
   COPIED FROM filter.xql
   FIXME: use injection dependency instead of $kind (requires XQuery 3)
   ======================================================================
:)
declare function local:gen-coaches ( $filter as element(), $lang as xs:string ) as element()* {
  (:let $user := oppidum:get-current-user():)

  (:let $host := stats:filter-region-criteria($user, $filter):)
  let $host := '1'
  let $ranks := fn:doc($globals:feeds-uri)/Feeds/Feed[@For eq $host]//Mean[@Filter eq 'SME']/Rank

  (: FIXME: hard coded 1 to 4 :)
  let $status := $filter//AccreditationStatusRef
  let $start-date := $filter/AccreditationStartDate/text()
  let $end-date := $filter/AccreditationEndDate/text()
  let $status-any-time := if ($start-date or $end-date) then () else $status
  let $status-after := if ($start-date and not($end-date)) then if (empty($status)) then 1 to 4 else $status else ()
  let $status-before := if ($end-date and not($start-date)) then if (empty($status)) then 1 to 4 else $status else ()
  let $status-between := if ($start-date and $end-date) then if (empty($status)) then 1 to 4 else $status else ()
  let $availability := $filter//YesNoAvailRef
  let $visibility := $filter//YesNoAcceptRef
  let $service := $filter//ServiceRef
  let $service-level := stats:get-expertise-for($filter, 'Services')

  let $coach := $filter//CoachRef
  let $sex := $filter//GenderRef
  let $country := $filter//Country
  let $languages := $filter//EU-LanguageRef
  let $perf := $filter/Performance[(Min ne '') or (Max ne '')]
  let $perf-min := if ($perf/Min) then number($perf/Min) else 1
  let $perf-max := if ($perf/Max) then number($perf/Max) else 5
  let $service-years := $filter//ServiceYearRef

  let $domain := $filter//DomainActivityRef
  let $domain-level := stats:get-expertise-for($filter, 'DomainsOfActivities')
  let $market := $filter//TargetedMarketRef/text()
  let $market-level := stats:get-expertise-for($filter, 'TargetedMarkets')
  let $life-cycle := $filter//InitialContextRef
  let $life-cycle-level := stats:get-expertise-for($filter, 'InitialContexts')

  let $vector := $filter//VectorRef/text()
  let $vector-level := stats:get-expertise-for($filter, 'Vectors')
  let $idea := $filter//IdeaRef/text()
  let $idea-level := stats:get-expertise-for($filter, 'Ideas')
  let $resource := $filter//ResourceRef/text()
  let $resource-level := stats:get-expertise-for($filter, 'Resources')
  let $partner := $filter//PartnerRef/text()
  let $partner-level := stats:get-expertise-for($filter, 'Partners')
  
  return
    for $c in fn:collection($globals:persons-uri)//Person[UserProfile//FunctionRef = '4']
    where     (empty($status-before) or $c/Hosts/Host[@For eq $host]/AccreditationRef[. = $status-before]/@Date <= $end-date)
          and (empty($status-after) or $c/Hosts/Host[@For eq $host]/AccreditationRef[. = $status-after]/@Date >= $start-date)
          and (empty($status-between) or $c/Hosts/Host[@For eq $host]/AccreditationRef[. = $status-between][@Date >= $start-date and @Date <= $end-date])
          and (empty($status-any-time) or $c/Hosts/Host[@For eq $host]/AccreditationRef = $status-any-time)
          and (empty($availability) or $c/Preferences/Coaching[@For eq $host]/YesNoAvailRef = $availability)
          and (empty($visibility) or $c/Preferences/Visibility[@For eq $host]/YesNoAcceptRef = $visibility)
          and (empty($service) or $c/Skills[@For eq 'Services']/Skill[@For = $service] = $service-level)
          and (empty($coach) or $c/Id = $coach)
          and (empty($sex) or $c/Information/Sex = $sex)
          and (empty($country) or $c/Information/Address/Country = $country)
          and (empty($languages) or $c/Knowledge/SpokenLanguages/EU-LanguageRef = $languages)
          and (empty($perf) or stats:check-min-max($c, $host, $perf-min, $perf-max))
          and (empty($service-years) or $c/Knowledge/IndustrialManagement/ServiceYearRef = $service-years)
          and (empty($domain) or exists($c/Skills[@For eq 'DomainActivities']//Skill[@For = $domain and . = $domain-level]))
          and (empty($market) or exists($c/Skills[@For eq 'TargetedMarkets']//Skill[@For = $market and . = $market-level]))
          and (empty($life-cycle) or exists($c/Skills[@For eq 'LifeCycleContexts']//Skill[@For = $life-cycle and . = $life-cycle-level]))
          and (empty($vector) or exists($c/Skills[@For eq 'CaseImpacts']/Skills[@For eq '1']/Skill[@For = $vector and . = $vector-level]))
          and (empty($idea) or exists($c/Skills[@For eq 'CaseImpacts']/Skills[@For eq '2']/Skill[@For = $idea and . = $idea-level]))
          and (empty($resource) or exists($c/Skills[@For eq 'CaseImpacts']/Skills[@For eq '3']/Skill[@For = $resource and . = $resource-level]))
          and (empty($partner) or exists($c/Skills[@For eq 'CaseImpacts']/Skills[@For eq '4']/Skill[@For = $partner and . = $partner-level]))
    return
      local:gen-coach-sample($c, 'en')
};

(: ======================================================================
   Case sample for All exportation : duplicates Activity rows to show coaching status
   FIXME: 
   - hard coded host ref '1'
   ====================================================================== 
:)
declare function local:gen-coach-sample ( $c as element(), $lang as xs:string ) as element()* {
  let $host := '1'
  let $coach-id := $c/No/text()
  return (
    <tr>
      <td><a href="../{$c/Id}" target="_blank">{$c/Id/text()}</a></td>
      <td>{ display:gen-person-name($c, $lang) }</td>
      <td>{ local:gen-person-email($c) }</td>
      <td>{ local:gen-phone($c/Information/Contacts) }</td>
      <td>{ $c/Information/Sex/text() }</td>
      <td class="co">{ $c/Information/Address/Country/text() }</td>
      <td class="lg">{ string-join($c/Knowledge//EU-LanguageRef, $local:separator) }</td>
      <td class="sv">{ 
        string-join(
          for $s in $c/Skills[@For eq 'Services']/Skill[. = ('2', '3')]
          return concat($s/@For, '#', $s)
          , $local:separator)
       }
      </td>
      <td>{ match:print-sme-rating ( $c, $host) }</td>
      <td class="as">{ $c/Hosts/Host[@For eq $host]/AccreditationRef/text() }</td>
      <td class="wr">{ $c/Hosts/Host[@For eq $host]/WorkingRankRef/text() }</td>
      <td class="av">{ $c/Preferences/Coaching[@For eq $host]/YesNoAvailRef/text() }</td>
      <td class="vs">{ $c/Preferences/Visibility[@For eq $host]/YesNoAcceptRef/text() }</td>
    </tr>
    )
};

(: ======================================================================
   Returns column headers for cases or activities export to table for Excel export
   ======================================================================
:)
declare function local:gen-headers-for( $target as xs:string, $type as xs:string ) as element()* {
  let $table := fn:doc(oppidum:path-to-config('stats.xml'))/Statistics//Table[(@Page eq $target) and contains(@Type, $type)]
  return
    (
    for $h in $table//Header[not(@Avoid) or (@Avoid ne $type)]
    let $group := string($h/@BG)
    let $i := if ($group ne '') then index-of($local:cols-name, $group) else 1
    let $color := if ($i) then $local:cols-backgrounds[$i] else $local:cols-backgrounds[1]
    return
      <col span="1" style="background:{$color}"/>,
      <thead>
        <tr>
          {
          for $h in $table//Header[not(@Avoid) or (@Avoid ne $type)]
          return 
            <th>
              {
              $h/@style,
              if (contains($h, ')')) then
                (substring-before($h, '('), <br/>, concat('(', substring-after($h, '(')))
              else
                $h/text()
              }
            </th>
          }
        </tr>
      </thead>
    )
};

(: ======================================================================
   Turns a time interval [from A? to B?] into appropriate sentence 
   ====================================================================== 
:)
declare function local:serialize-interval( $start as xs:string?, $end as xs:string? ) as xs:string? {
  if ($start and $end) then 
    concat('from ', $start, ' to ', $end) 
  else if ($start) then 
    concat('after ', $start) 
  else if ($end) then 
    concat('before ', $end) 
  else 
    ()
};

(: ======================================================================
   Turns a time interval [between A? and B?] into appropriate sentence 
   ====================================================================== 
:)
declare function local:serialize-period( $start as xs:string?, $end as xs:string? ) as xs:string? {
  if ($start and $end) then 
    concat('between ', $start, ' and ', $end) 
  else if ($start) then 
    concat('since ', $start) 
  else if ($end) then 
    concat('before ', $end) 
  else 
    ()
};

(: ======================================================================
   Turns a range [between A? and B?] into appropriate sentence 
   ====================================================================== 
:)
declare function local:serialize-range( $range as element()? ) as xs:string? {
  let $start := $range/Min
  let $end := $range/Max
  return
    if ($start and $end) then 
      concat('between ', $start, ' and ', $end) 
    else if ($start) then 
      concat('superior or equal to ', $start) 
    else if ($end) then 
      concat('inferior or equal to ', $end) 
    else 
      ()
};
(: ======================================================================
   Switch function to call correct function in stats.xqm to generate
   the samples corresponding to submitted criterias as HTML table rows
   See also stats:gen-cases and stats:gen-activities in stats.xqm
   ======================================================================
:)
declare function local:serialize-data-set( $target as xs:string, $type as xs:string, $filter as element(), $lang as xs:string ) as element()* {
  if ($target eq 'coaches') then
    local:gen-coaches($filter, $lang)
  else 
    ()
};

(: ======================================================================
   Renders field values inside Criteria
   Implements @render, @selector, @status and @function annotations of stats.xml
   ======================================================================
:)
declare function local:gen-current-filter ( $filter as element(), $criteria as element() ) as xs:string {
  if ($criteria/@render) then
    string-join(util:eval($criteria/@render), ' ')
  else if ($criteria/@selector) then
    if ($criteria/@ValuePath) then
      string-join(
        for $i in util:eval(concat('$filter/', $criteria/@ValuePath))
        return display:gen-name-for($criteria/@selector, $i, 'en'),
        $local:separator
        )
    else (: assumes @ValueTag :)
      string-join(
        for $i in $filter//*[local-name(.) eq string($criteria/@ValueTag)]
        return display:gen-name-for($criteria/@selector, $i, 'en'),
        $local:separator
        )
  else if ($criteria/@function) then
    string-join(
      for $i in $filter//*[local-name(.) eq string($criteria/@ValueTag)]
      let $src := concat('display:', string($criteria/@function), '($i, "en")')
      return util:eval($src),
      $local:separator
    )
(:  else if ($criteria/@status) then
    string-join(
      for $i in $filter//*[local-name(.) eq string($criteria/@ValueTag)]
      return display:gen-workflow-status-name($criteria/@status, $i, 'en'),
      $local:separator
      )
:)  else if ($criteria/@ValueTag) then
    string-join($filter//*[local-name(.) eq string($criteria/@ValueTag)], $local:separator)
  else
    string-join($filter//*[local-name(.) eq string($criteria/@Tag)], $local:separator)
};

(: ======================================================================
   Generates an optionally localized criteria field label
   TODO: $lang parameter
   ======================================================================
:)
declare function local:criteria-field-label( $field as element()? ) as xs:string {
  if ($field/@loc) then
    let $dico := fn:doc($globals:dico-uri)/site:Dictionary/site:Translations[@lang = 'en']
    let $t := $dico/site:Translation[@key = $field/@loc]/text()
    return
      if ($t) then 
        $t 
      else 
        $field/text()
  else
    $field/text()
};

(: ======================================================================
   Returns true() if the given Criteria has a non empty filter set in the query mask
   ====================================================================== 
:)
declare function local:has-filter($criteria as element(), $filter as element(), $plugins as element()* ) {
  let $name :=
    if ($criteria/@Tag) then
      string($criteria/@Tag)
    else (: actually no @Tag implies a Period plugin :)
      let $period := $plugins/Period[contains(@Keys, $criteria/@Key)]
      let $suffix := if ($period/@Span eq 'Year') then 'Year' else 'Date'
      return (: see also search-mask.xsl :)
        (concat($period/@Prefix, 'Start', $suffix), concat($period/@Prefix, 'End', $suffix)) 
  let $mask := $filter/*[local-name(.) = $name]
  return
    some $m in $mask satisfies normalize-space(string($m)) ne ''
};

declare function local:gen-criterias-iter( $filter as element(), $nodes as item()*, $plugins as element()* ) as item()* {
  for $n in $nodes
  return
    typeswitch($n)
      case element() return
        if (local-name($n) eq 'Group') then (
          let $span := count($n/descendant::Criteria[local:has-filter(., $filter, $plugins)]) - (count($n/descendant::SubGroup/Criteria[local:has-filter(., $filter, $plugins)]) + count($n/descendant::Criteria[preceding-sibling::*[1][local-name() = 'SubGroup']][local:has-filter(., $filter, $plugins)]))
          return
            if ($span > 0) then
              let $first := $n/Criteria[local:has-filter(., $filter, $plugins)][1]
              return
                <tr style="background:{$n/@Background}">
                  <td style="width:20%" rowspan="{$span}">{$n/Title/text()}</td>
                  <td style="width:30%">{ local:criteria-field-label($first) }</td>
                  <td style="width:50%">{ local:gen-current-filter($filter, $first) }</td>
                </tr>
            else
              (),
          let $followers := $n/(SubGroup[descendant::Criteria[local:has-filter(., $filter, $plugins)]] | Criteria[local:has-filter(., $filter, $plugins)][position()>1])
          return
            if (exists($followers)) then
              local:gen-criterias-iter($filter, $followers, $plugins)
            else
              ()
          )
        else if (local-name($n) eq 'SubGroup') then (
          let $span := count($n/Criteria[local:has-filter(., $filter, $plugins)]) + count($n/following-sibling::Criteria[local:has-filter(., $filter, $plugins)])
          return
            if ($span > 0) then
              let $first := $n/Criteria[local:has-filter(., $filter, $plugins)][1]
              return
                <tr style="background:{$n/ancestor::Group/@Background}">
                  <td style="width:20%" rowspan="{$span}">{$n/Title/text()}</td>
                  <td style="width:30%">{ local:criteria-field-label($first) }</td>
                  <td style="width:50%">{ local:gen-current-filter($filter, $first) }</td>
                </tr>
            else
              (),
          let $followers := $n/Criteria[local:has-filter(., $filter, $plugins)][position()>1]
          return
            if (exists($followers)) then
              local:gen-criterias-iter($filter, $followers, $plugins)
            else
              ()
          )
        else if (local-name($n) eq 'Criteria') then
          <tr style="background:{$n/ancestor::Group/@Background}">
            <td>{ local:criteria-field-label($n) }</td>
            <td>{ local:gen-current-filter($filter, $n) }</td>
          </tr>
        else
          ()
      default return ()
};

(: ======================================================================
   Generates the search criteria table filled with the current filter
   Pre-condition: copy formulars/stats.xml spec into $globals:stats-formulars-uri
   ======================================================================
:)
declare function local:serialize-criterias( $target as xs:string, $type as xs:string, $filter as element(), $lang as xs:string ) as element() {
  <table id="filters">
    <caption style="font-size:24px;margin:20px 0 10px;text-align:left">
      <b>Search criterias</b>
    </caption>
    {
    let $maskpath := concat('/db/www/ccmatch/formulars/stats-', $target, '.xml')
    let $searchmask := fn:doc($maskpath)//SearchMask
    return
      for $c in $searchmask/Include
      let $stats-uri := concat('/db/www/ccmatch/formulars/', $c/@src)
      let $rowspec :=  fn:doc($stats-uri)//Component[@Name eq $c/@Name]
      let $plugins := fn:doc($stats-uri)//Plugins
      return
        local:gen-criterias-iter($filter, $rowspec/*, $plugins)
    }
  </table>
};

(: ======================================================================
   Generate a page with an HTML table for the filter criteria and an HTML table
   for the results, both can be exported to Excel
   ======================================================================
:)
declare function local:export-html ( $target as xs:string, $type as xs:string, $filter as element(), $lang as xs:string ) {
  let $base := epilogue:make-static-base-url-for('ccmatch')
  let $subject := 'Coaches'
  let $brand := concat(
                  if ($type eq 'anonymized') then ' anonymized ' else (),
                  if ($type eq 'list') then ' contact list ' else ' data set '
                )  
  let $date := string(current-dateTime())
  let $timestamp := concat(' exported on ', display:gen-display-date($date, $lang), ' at ', substring($date, 12, 5))
  let $username := local:gen-current-person-name()
  let $rows := local:serialize-data-set($target, $type, $filter, $lang)
  return
    <html xmlns="http://www.w3.org/TR/REC-html40">
      <head>
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
        <title>{$subject} {$timestamp}</title>
        <script src="{epilogue:make-static-base-url-for('oppidum')}/contribs/jquery/js/jquery-1.7.1.min.js" type="text/javascript">//</script>
        <script src="{$base}excellentexport/excellentexport.js" type="text/javascript">//</script>
        <link href="{$base}css/stats.css" rel="stylesheet" type="text/css" />
        <script src="{$base}lib/stats.js" type="text/javascript">//</script>
        <script src="{$base}tablesorter/jquery.tablesorter.min.js" type="text/javascript">//</script>
      </head>
      <body id="export">
        <h1>{$subject} {$brand} {$timestamp}</h1>
        <div id="results-export">Export <a download="coach-match-{$target}.xls" href="#" class="export">excel</a> <a download="coach-match-{$target}.csv" href="#" class="export">csv</a></div>
        { local:serialize-criterias($target, $type, $filter, $lang) }
        <table id="results">
          <caption style="font-size:24px;margin:20px 0 10px;text-align:left"><b>{ concat(count($rows), ' ', upper-case($subject), ' in ', $brand, $timestamp, ' by ', $username) }</b></caption>
          { local:gen-headers-for($target, $type) }
          <tbody>
            { $rows }
          </tbody>
        </table>
        { local:gen-decompress-script() }
      </body>
    </html>
};

(: ======================================================================
   Trick to catch errors when parsing submitted data
   ======================================================================
:)
declare function local:gen-error() as element() {
  <error><message>Failed to read submitted parameters</message></error>
};

let $cmd := oppidum:get-command()
let $data := request:get-parameter('data', ())
let $submitted := util:catch('*', util:parse($data), local:gen-error())
return
  if (node-name($submitted) eq 'error') then
    $submitted
  else
    let $target := lower-case(substring-before(local-name($submitted/*[1]), 'Filter'))
    let $type := request:get-parameter('t', ())
    let $action := concat(string($cmd/@action), '?t=', $type)
    return
      if ((access:check-stats-action($target, $action, false()))) then
        if ($target = ('coaches')) then (: FIXME: hard-coded :)
          if ($type = ('list')) then
            (
            util:declare-option("exist:serialize", "method=html media-type=text/html"),
            (: TODO: access:check-stats(...) :)
            local:export-html($target, $type, $submitted/*[1], 'en')
            )
          else
            <error>Unkown export type { $type }</error>
        else
          <error>Unkown export target { $target }</error>
      else
        oppidum:throw-error('FORBIDDEN', ())


xquery version "3.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Statistical table export

   TODO:
   - factorize gen-cases and gen-activities with filter.xql in stats.xqm

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

declare variable $local:separator := '; ';
declare variable $local:weight-thresholds := ('2', '3');

(: TODO: declare colors for columns inside stats.xml :)
declare variable $local:cols-name := ('none', 'activity', 'enterprise', 'case', 'priorities', 'needs', 'kpi');
declare variable $local:cols-backgrounds := ('#FFF', '#F5E0FF', '#C2FFFF', '#99C2EB', '#E6AAF2', '#83D6C3', '#B5C04F');

(: ======================================================================
   Returns the name of the current user as First name Last name or falls back to user login
   ======================================================================
:)
declare function local:gen-current-person-name() as xs:string {
  let $user := oppidum:get-current-user()
  let $uid := access:get-current-person-id($user)
  return
    if ($uid) then
      display:gen-person-name($uid, 'en')
    else
      $user
};

(: ======================================================================
   TODO: fallback to warning if no Email
   ======================================================================
:)
declare function local:gen-person-email( $refs as element()* ) as element()* {
  for $r in $refs
  return
    let $p := fn:collection($globals:persons-uri)//Person[Id = $r]
    return
      if ($p) then
        <a href="mailto:{$p/Contacts/Email}">{ concat($p/Name/FirstName, ' ', $p/Name/LastName) }</a>
      else
        <span>{ display:noref($r, 'en') }</span>
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
    stats:gen-selector-domain('prg', 'FundingPrograms'),
    stats:gen-funding-phase-domain(()),
    stats:gen-cut-off-domain(()), (: FIXME: decode it server-side ? :)
    stats:gen-selector-domain('sz', 'Sizes'),
    stats:gen-selector-domain('co', 'Countries'),
    stats:gen-selector-domain('ctx', 'TargetedContexts'),
    stats:gen-selector-domain-regional-entities('een'),
    stats:gen-selector-domain('tp', 'Topics'),
    stats:gen-selector-domain('da', 'DomainActivities'),
    stats:gen-selector-domain('tm', 'TargetedMarkets'),
    stats:gen-selector-domain('sg', 'SectorGroups'),
    stats:gen-selector-domain('sv', 'Services'),
    stats:gen-selector-domain('ad', 'CommunicationAdvices'),
    stats:gen-selector-domain('rs', 'RatingScales'),
    stats:gen-workflow-status-domain('cs', 'Case'),
    stats:gen-workflow-status-domain('as', 'Activity'),
    stats:gen-case-vector('vr', '1'),
    stats:gen-case-vector('ir', '2'),
    stats:gen-case-vector('rr', '3'),
    stats:gen-case-vector('pr', '4')
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
  return
    <script type="text/javascript">
DB = { util:serialize($DB, 'method=json') };

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

uncompress(['prg', 'ph', 'COf', 'co', 'sz', 'ctx', 'een', 'cs', 'tp', 'da', 'tm', 'sg', 'vr', 'ir', 'rr', 'pr', 'as', 'sv', 'ad', 'rs']);
uncompressWeights(['_vr', '_ir', '_rr', '_pr'])
</script>
};

(: ======================================================================
   Aligned with corresponding Table element in stats.xml
   ======================================================================
:)
declare function local:gen-common-case-sample-I ( $p as element()?, $c as element(), $flags as xs:string*, $lang as xs:string ) as element()* {
  <td>{ $p/Information/Acronym/text() }</td>,
  <td class="prg">{ $p/Information/Call/FundingProgramRef/text() }</td>,
  <td class="Ph">{ $p/Information/Call/(SMEiFundingRef | FETActionRef)/text() }</td>,
  <td class="COf">{ $p/Information/Call/(SMEiCallRef|FTICallRef|FETCallRef)/text() }</td>,
  <td class="tp">{ string-join($p/Information/Call//TopicRef, $local:separator) }</td>,
  <td>{ local:gen-person-email($p/Information/ProjectOfficerRef) }</td>,
  <td class="cs">{ $c/StatusHistory/CurrentStatusRef/text() }</td>
};

(: ======================================================================
   Aligned with corresponding Table element in stats.xml
   For display in Case export tables
   ======================================================================
:)
declare function local:gen-common-case-sample-IIC ( $p as element()?, $c as element(), $flags as xs:string*, $lang as xs:string ) as element()* {
  let $en := $p/Information/Beneficiaries/*[PIC eq $c/PIC]
  let $na := $c/NeedsAnalysis
  return
    (
    if ($flags = ('all', 'list')) then
      <td>{ $en/ShortName/text() }</td>
    else
      (),
    <td class="co">{ $en//Country/text() }</td>,
    <td class="da">{ $en/DomainActivityRef/text() }</td>,
    <td class="tm">{ string-join($en//TargetedMarketRef, $local:separator) }</td>,
    <td class="sz">{ $en/SizeRef/text() }</td>,
    <td>{ $en/CreationYear/text() }</td>,
    <td class="sg">{ $na//SectorGroupRef/text() }</td>,
    <td class="ctx">{ $na//InitialContextRef/text() }</td>,
    <td class="ctx">{ $na//TargetedContextRef/text() }</td>,
    <td class="vr">{ string-join($na//VectorRef, $local:separator) }</td>,
    <td class="ir">{ string-join($na//IdeaRef, $local:separator) }</td>,
    <td class="rr">{ string-join($na//ResourceRef, $local:separator) }</td>,
    <td class="pr">{ string-join($na//PartnerRef, $local:separator) }</td>
    )
};

(: ======================================================================
   Aligned with corresponding Table element in stats.xml
   For display in Activity or KPI export tables
   ======================================================================
:)
declare function local:gen-common-case-sample-IIA ( $p as element()?, $c as element(), $flags as xs:string*, $lang as xs:string ) as element()* {
  let $en := $p/Information/Beneficiaries/*[PIC eq $c/PIC]
  let $na := $c/NeedsAnalysis
  return
    (
    if ($flags = ('all', 'list')) then
      <td>{ $en/ShortName/text() }</td>
    else
      (),
    <td class="co">{ $en//Country/text() }</td>,
    <td class="da">{ $en/DomainActivityRef/text() }</td>,
    <td class="tm">{ string-join($en//TargetedMarketRef, $local:separator) }</td>,
    <td class="sz">{ $en/SizeRef/text() }</td>,
    <td>{ $en/CreationYear/text() }</td>,
    <td class="een">{ $c/ManagingEntity/RegionalEntityRef/text() }</td>,
    <td>{ local:gen-person-email($c/Management/AccountManagerRef) }</td>,
    <td class="sg">{ $na//SectorGroupRef/text() }</td>,
    <td class="ctx">{ $na//InitialContextRef/text() }</td>,
    <td class="ctx">{ $na//TargetedContextRef/text() }</td>,
    <td class="vr">{ string-join($na//VectorRef, $local:separator) }</td>,
    <td class="ir">{ string-join($na//IdeaRef, $local:separator) }</td>,
    <td class="rr">{ string-join($na//ResourceRef, $local:separator) }</td>,
    <td class="pr">{ string-join($na//PartnerRef, $local:separator) }</td>
    )
};

(: ======================================================================
   Case sample generation ('all' flag duplicate Activity rows to show 
   coaching status, 'anonymized' flag for anonymized short version)
   ====================================================================== 
:)
declare function local:gen-case-sample ( $p as element(), $c as element(), $flags as xs:string*, $lang as xs:string ) as element()* {
  let $case-nb := $c/No/text()
  let $a := $c//Activity[1]
  let $common-I := local:gen-common-case-sample-I($p, $c, $flags, $lang)
  let $common-II := local:gen-common-case-sample-IIC($p, $c, $flags, $lang)
  return (
    <tr>
      <td><a href="../projects/{ $p/Id }/cases/{$case-nb}" target="_blank">{$case-nb}</a></td>
      <td><a href="../projects/{ $p/Id }" target="_blank">{ $p/Id/text() }</a></td>
      { 
      $common-I,
      <td>{ local:gen-person-email($c/Management/AccountManagerRef) }</td>,
      <td class="een">{ $c/ManagingEntity/RegionalEntityRef/text() }</td>,
      if ($flags = 'all') then (
        <td><a href="../projects/{ $p/Id }/cases/{$case-nb}/activities/{$a/No}" target="_blank">{$a/No/text()}</a></td>,
        <td class="as">{ $a/StatusHistory/CurrentStatusRef/text() }</td>,
        <td>{ local:gen-person-email($a//ResponsibleCoachRef) }</td>
        )
      else
        (),
      $common-II 
      }
    </tr>,
    if ($flags = 'all') then
      for $a in subsequence($c//Activity, 2)
      return
        <tr>
          <td><a href="../projects/{ $p/Id }/cases/{$case-nb}" target="_blank">{$case-nb}</a></td>
          <td><a href="../projects/{ $p/Id }" target="_blank">{ $p/Id/text() }</a></td>
          { $common-I }
          <td>{ local:gen-person-email($c/Management/AccountManagerRef) }</td>
          <td class="een">{ $c/Information/ManagingEntity/RegionalEntityRef/text() }</td>
          <td><a href="../projects/{ $p/Id }/cases/{$case-nb}/activities/{$a/No}" target="_blank">{$a/No/text()}</a></td>
          <td class="as">{ $a/StatusHistory/CurrentStatusRef/text() }</td>
          <td>{ local:gen-person-email($a//ResponsibleCoachRef) }</td>
          { $common-II }
        </tr>
    else
      ()
    )
};

(: ======================================================================
   Aligned with corresponding Table element in stats.xml
   ======================================================================
:)
declare function local:gen-case-sample-for-list ( $p as element(), $c as element(), $flags as xs:string*, $lang as xs:string ) as element()* {
  <tr>
    { local:gen-case-common-rows-for-list($p, $c, (), $flags, $lang) }
    <td class="cs">{ $c/StatusHistory/CurrentStatusRef/text() }</td>
  </tr>
};

(: ======================================================================
   Factorized case row generation for contacts list serialization
   ====================================================================== 
:)
declare function local:gen-case-common-rows-for-list ( $p as element(), $c as element(), $a as element()?, $flags as xs:string*, $lang as xs:string ) as element()* {
  let $case-nb := $c/No/text()
  let $en := $p/Information/Beneficiaries/*[PIC eq $c/PIC]
  return
    (
    <td><a href="../projects/{ $p/Id }/cases/{$case-nb}" target="_blank">{$case-nb}</a></td>,
    <td><a href="../projects/{ $p/Id }" target="_blank">{ $p/Id/text() }</a></td>,
    <td class="prg">{ $p/Information/Call/FundingProgramRef/text() }</td>,
    <td class="Ph">{ $p/Information/Call/(SMEiFundingRef | FETActionRef)/text() }</td>,
    if (not($flags = 'kpi')) then (: not in KPI export :)
      <td class="COf">{ $p/Information/Call/(SMEiCallRef|FTICallRef|FETCallRef)/text() }</td>
    else
      (),
    if (not($flags = 'kpi')) then (: not in KPI export :)
      <td>{ $p/Information/Acronym/text() }</td> 
    else 
      (),
    <td>{ $en/ShortName/text() }</td>,
    <td>
      {
        let $p := $en/ContactPerson
        return <a href="mailto:{$p/Contacts/Email}">{ concat($p/Name/FirstName, ' ', $p/Name/LastName) }</a>
      }
    </td>,
    <td class="co">{ $en//Country/text() }</td>,
    if (not($flags = 'kpi')) then ( (: not in KPI export :)
      <td class="sz">{ $en/SizeRef/text() }</td>,
      <td class="ctx">{ $c/NeedsAnalysis//TargetedContextRef/text() }</td>,
      <td>{ local:gen-person-email($p/Information/ProjectOfficerRef) }</td>
      )
    else
      (),
    <td class="een">{ $c/ManagingEntity/RegionalEntityRef/text() }</td>,
    <td>
      {
        if ($c/Management/AssignedByRef) then
          local:gen-person-email($c/Management/AssignedByRef)
        else
          'TBD: coordinators'
      }
    </td>,
    <td>{ local:gen-person-email($c/Management/AccountManagerRef) }</td>
    )
};

(: ======================================================================
   Helper function to extracts values of weight elements from an Activity 
   for a given root (identified by its first letter for optimization,
   'V' for Vectors, 'I' for 'Ideas' and so on...)
   Returns a comma separated list of "x#y" strings (e.g. '1#2; 5#3') where x
   is a code corresponding to a weight variable and y is the priority set on it
   NOTE: the string will be decoded client-side with Javascript for optimization
         (see uncompressWeights above)
   ====================================================================== 
:)
declare function local:extract-weight ( $weights as element()?, $root as xs:string ) as xs:string {
  string-join(
    for $v in $weights/*[starts-with(local-name(.), $root) and . = $local:weight-thresholds]
    return concat(substring-after(local-name($v), '-'), '#', $v),
    $local:separator
    )
};

(: ======================================================================
   Generate subset sample for KPI to insert inside Activity sample
   ====================================================================== 
:)
declare function local:gen-kpi-indicators-sample ( $a as element() ) as element()* {
  let $feedbacks := stats:gen-feedbacks-sample($a)
  return (
    <td>{ round(stats:calc-filter('KPI1', $feedbacks) * 100) div 100 }</td>,
    <td>{ round(stats:calc-filter('KPI2', $feedbacks) * 100) div 100 }</td>,
    <td>{ round(stats:calc-filter('KPI3', $feedbacks) * 100) div 100 }</td>,
    <td>{ round(stats:calc-filter('KPI4', $feedbacks) * 100) div 100 }</td>,
    <td>{ round(stats:calc-filter('KPI', $feedbacks) * 100) div 100 }</td>
    )
};

(: ======================================================================
   Aligned with corresponding Table element in stats.xml
   ======================================================================
:)
declare function local:gen-activity-sample-for-list ( $p as element(), $c as element(), $a as element(), $flags as xs:string*, $lang as xs:string ) as element()* {
  let $case-nb := $c/No/text()
  let $activity-nb := $a/No/text()
  return
    <tr>
      { local:gen-case-common-rows-for-list($p, $c, $a, $flags, $lang) }
      <td><a href="../projects/{ $p/Id }/cases/{$case-nb}/activities/{$activity-nb}" target="_blank">{$activity-nb}</a></td>
      <td>{ local:gen-person-email($a//ResponsibleCoachRef) }</td>
      <td class="as">{ $a/StatusHistory/CurrentStatusRef/text() }</td>
      { if ($flags = 'kpi') then local:gen-kpi-indicators-sample($a) else () }
    </tr>
};

(: ======================================================================
   Generate subset sample for KPI to insert inside Activity sample
   ====================================================================== 
:)
declare function local:gen-kpi-vector-sample ( $a as element() ) as element()* {
  let $fr := $a/FinalReport
  let $fra := $a/FinalReportApproval
  let $sme := $a/Evaluation
  return 
    (
      <td class="rs">{ $fra/Recognition/RatingScaleRef/text() }</td>,
      <td class="rs">{ $fra/Tools/RatingScaleRef/text() }</td>,
      <td class="rs">{ $sme//RatingScaleRef[@For eq 'SME1']/text() }</td>,
      <td class="rs">{ $sme//RatingScaleRef[@For eq 'SME2']/text() }</td>,
      <td class="rs">{ $fra/Profiles/RatingScaleRef/text() }</td>,
      <td class="rs">{ $sme//RatingScaleRef[@For eq 'SME3']/text() }</td>,
      <td class="rs">{ $fr/KAMPreparation/RatingScaleRef/text() }</td>,
      <td class="rs">{ $fr/ManagementTeam/RatingScaleRef/text() }</td>,
      <td class="rs">{ $sme//RatingScaleRef[@For eq 'SME7']/text() }</td>,
      <td class="rs">{ $fr/Dissemination/RatingScaleRef/text() }</td>,
      <td class="rs">{ $sme//RatingScaleRef[@For eq 'SME4']/text() }</td>,
      <td class="rs">{ $fr/ObjectivesAchievements/RatingScaleRef/text() }</td>,
      <td class="rs">{ $sme//RatingScaleRef[@For eq 'SME5']/text() }</td>,
      <td class="rs">{ $sme//RatingScaleRef[@For eq 'SME6']/text() }</td>,
      <td class="rs">{ $a/Evaluation/Order/Answers/Comments/Text/text() }</td>,
      <td class="rs">{ $fra/Dialogue/RatingScaleRef }</td>,
      <td class="rs">{ $a/FinalReportApproval/Dialogue/Comment/Text/text() }</td>
    )
};

(: ======================================================================
   Aligned with corresponding Table element in stats.xml
   ======================================================================
:)
declare function local:gen-activity-sample ( $p as element(), $c as element(), $a as element(), $flags as xs:string*, $lang as xs:string ) as element()* {
  let $case-nb := $c/No/text()
  let $activity-nb := $a/No/text()
  let $w := $a/Assignment/Weights
  return
    <tr>
      <td><a href="../projects/{ $p/Id }/cases/{$case-nb}" target="_blank">{$case-nb}</a></td>
      <td><a href="../projects/{ $p/Id }" target="_blank">{ $p/Id/text() }</a></td>
      <td><a href="../projects/{ $p/Id }/cases/{$case-nb}/activities/{$activity-nb}" target="_blank">{$activity-nb}</a></td>
      <td>{ local:gen-person-email($a//ResponsibleCoachRef) }</td>
      <td class="sv">{ $a/Assignment/ServiceRef/text() }</td>
      <td class="as">{ $a/StatusHistory/CurrentStatusRef/text() }</td>
      { if ($flags = 'kpi') then local:gen-kpi-vector-sample($a) else () }
      <td class="_vr">{ local:extract-weight($w, 'V') }</td>
      <td></td>
      <td class="_ir">{ local:extract-weight($w, 'I') }</td>
      <td></td>
      <td class="_rr">{ local:extract-weight($w, 'R') }</td>
      <td></td>
      <td class="_pr">{ local:extract-weight($w, 'P') }</td>
      <td></td>
      <td class="ad">{ $a/FinalReport//CommunicationAdviceRef/text() }</td>
      <td class="ad">{ $a/FinalReportApproval//CommunicationAdviceRef/text() }</td>
      { 
      local:gen-common-case-sample-I($p, $c, $flags, $lang),
      local:gen-common-case-sample-IIA($p, $c, $flags, $lang)
      }
    </tr>
};

(: ======================================================================
   Returns column headers for cases or activities export to table for Excel export
   ======================================================================
:)
declare function local:gen-headers-for( $target as xs:string, $type as xs:string ) as element()* {
  let $filter-spec-uri := oppidum:path-to-config('stats.xml')
  let $table := fn:doc($filter-spec-uri)/Statistics//Table[(@Page eq $target) and contains(@Type, $type)]
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
          return <th>{ $h/text() }</th>
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
  if ($target eq 'cases') then
    if ($type = ('all', 'anonymized')) then
      stats:gen-cases($filter, $type, $lang, function-lookup(xs:QName("local:gen-case-sample"), 4))
    else (: assumes list :)
      stats:gen-cases($filter, 'list', $lang, function-lookup(xs:QName("local:gen-case-sample-for-list"), 4))
  else if ($target = ('activities', 'kpi')) then
    if ($type = ('all', 'anonymized')) then
      stats:gen-activities($filter, ($type, $target), $lang, function-lookup(xs:QName("local:gen-activity-sample"), 5))
    else (: assumes list :)
      stats:gen-activities($filter, ($type, $target), $lang, function-lookup(xs:QName("local:gen-activity-sample-for-list"), 5))
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
  else if ($criteria/@status) then
    string-join(
      for $i in $filter//*[local-name(.) eq string($criteria/@ValueTag)]
      return display:gen-workflow-status-name($criteria/@status, $i, 'en'),
      $local:separator
      )
  else if ($criteria/@ValueTag) then
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
    for $m in $mask
    where normalize-space(string($m)) ne ''
    return $m
};

(: ======================================================================
   local:has-filter-wrapper for local;has-filter
   Returns true() if the given Criteria has a non empty filter set in the query mask
   ====================================================================== 
:)
declare function local:has-filter-wrapper($n as item()*, $filter as element(), $plugins as element()* ) as element()* {
let $cmpt := for $criteria in $n return if (local:has-filter($criteria, $filter, $plugins)) then $criteria else ()
  return
     $cmpt
};

declare function local:gen-criterias-iter( $filter as element(), $nodes as item()*, $plugins as element()* ) as item()* {
  for $n in $nodes
  return
    typeswitch($n)
      case element() return
        if (local-name($n) eq 'Group') then (
          let $span := count(local:has-filter-wrapper($n/descendant::Criteria, $filter, $plugins)) - (count(local:has-filter-wrapper($n/descendant::SubGroup/Criteria, $filter, $plugins)) + count(local:has-filter-wrapper($n/descendant::Criteria[preceding-sibling::*[1][local-name() = 'SubGroup']], $filter, $plugins)))
          (:let $span := count($n/descendant::Criteria[local:has-filter(., $filter, $plugins)]) - (count($n/descendant::SubGroup/Criteria[local:has-filter(., $filter, $plugins)]) + count($n/descendant::Criteria[preceding-sibling::*[1][local-name() = 'SubGroup']][local:has-filter(., $filter, $plugins)])):)
          return
            if ($span > 0) then
              (:let $first := $n/Criteria[local:has-filter(., $filter, $plugins)][1]:)
              let $first := local:has-filter-wrapper($n/Criteria, $filter, $plugins)[1]
              return
                <tr style="background:{$n/@Background}">
                  <td style="width:20%" rowspan="{$span}">{$n/Title/text()}</td>
                  <td style="width:30%">{ local:criteria-field-label($first) }</td>
                  <td style="width:50%">{ local:gen-current-filter($filter, $first) }</td>
                </tr>
            else
              (),
          (:let $followers := $n/(SubGroup[descendant::Criteria[local:has-filter(., $filter, $plugins)]] | Criteria[local:has-filter(., $filter, $plugins)][position()>1]):)
          let $followers := ( $n/SubGroup[local:has-filter-wrapper(descendant::Criteria, $filter, $plugins)], local:has-filter-wrapper($n/Criteria, $filter, $plugins)[position()>1]) 
          return
            if (exists($followers)) then
              local:gen-criterias-iter($filter, $followers, $plugins)
            else
              ()
          )
        else if (local-name($n) eq 'SubGroup') then (
          (:let $span := count($n/Criteria[local:has-filter(., $filter, $plugins)]) + count($n/following-sibling::Criteria[local:has-filter(., $filter, $plugins)]):)
          let $span := count(local:has-filter-wrapper($n/Criteria, $filter, $plugins)) + count(local:has-filter-wrapper($n/following-sibling::Criteria, $filter, $plugins))
          return
            if ($span > 0) then
              (:let $first := $n/Criteria[local:has-filter(., $filter, $plugins)][1]:)
              let $first := local:has-filter-wrapper($n/Criteria, $filter, $plugins)[1]
              return
                <tr style="background:{$n/ancestor::Group/@Background}">
                  <td style="width:20%" rowspan="{$span}">{$n/Title/text()}</td>
                  <td style="width:30%">{ local:criteria-field-label($first) }</td>
                  <td style="width:50%">{ local:gen-current-filter($filter, $first) }</td>
                </tr>
            else
              (),
          (:let $followers := $n/Criteria[local:has-filter(., $filter, $plugins)][position()>1]:)
          let $followers := local:has-filter-wrapper($n/Criteria, $filter, $plugins)[position()>1]
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
    let $maskpath := concat('/db/www/cctracker/formulars/stats-', $target, '.xml')
    let $searchmask := fn:doc($maskpath)//SearchMask
    return
      for $c in $searchmask/Include
      let $stats-uri := concat($globals:stats-formulars-uri, '/', $c/@src)
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
  let $base := epilogue:make-static-base-url-for('cctracker')
  let $subject := if ($target eq 'cases') then 'Cases' else 'Activities'
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
        <div id="results-export">Export <a download="case-tracker-{$target}.xls" href="#" class="export">excel</a> | <a download="case-tracker-{$target}.csv" href="#" class="export">csv</a></div>
        { 
          try {
            local:serialize-criterias($target, $type, $filter, $lang) 
          }
          catch * {
            <p>[Error] - Serialize-criterias failed</p>
          }
        }
        <table id="results">
          <caption style="font-size:24px;margin:20px 0 10px;text-align:left"><b>{ concat(count($rows), ' ', upper-case($subject), ' in ', $brand, $timestamp, ' by ', $username) }</b></caption>
          { 
            try {
              local:gen-headers-for($target, $type) 
            }
            catch * {
              <p>[Error] - gen-headers-for failed</p>
            }
          }
          <tbody>
            { $rows/* }
          </tbody>
        </table>
        { 
          try {
            local:gen-decompress-script()
          }
          catch * {
           <p>[Error] - gen-decompress-script failed</p>
          }
        }
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
        if ($target = ('cases', 'activities', 'kpi')) then
          if ($type = ('anonymized', 'all', 'list')) then
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


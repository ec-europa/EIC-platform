xquery version "3.0";
(: ------------------------------------------------------------------
   CCMATCH - EIC Coach Match Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Coach evaluation feeds console
   To be used for testing nightly job feeds/job.xql

   Call with '?digest=yes' to also update histories collection

   July 2016 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

declare namespace response="http://exist-db.org/xquery/response";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace xhtml = "http://www.w3.org/1999/xhtml";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace services = "http://oppidoc.com/ns/services" at "../../lib/services.xqm";
import module namespace feeds = "http://oppidoc.com/ns/feeds" at "feeds.xqm";
import module namespace histories = "http://oppidoc.com/ns/histories" at "../../lib/histories.xqm";

declare option exist:serialize "method=xml media-type=application/xml";

(: ======================================================================
   Utility to serialize XML output inside HTML output
   ====================================================================== 
:)
declare function local:serialize( $e as element()? ) {
  <pre id="output" xmlns="http://www.w3.org/1999/xhtml">
    { 
    fn:serialize(
      $e,
      <output:serialization-parameters>
        <output:indent value="yes"/>
      </output:serialization-parameters>
    )
    }
  </pre>
};

declare function local:repeat-range( $inf as xs:integer?, $sup as xs:integer? ) as xs:string? {
  if ($inf or $sup) then
    concat('&amp;r=', string-join(($inf, $sup), '-'))
  else
    ()
};

declare function local:filter-selected( $cur as xs:string, $val as xs:string ) {
  if ($cur eq $val) then 
    attribute { 'selected' } { 'selected' }
  else
    ()
};

(: ======================================================================
    Show feeds console help and shortcut links
   ====================================================================== 
:)
declare function local:menu( $inf as xs:integer?, $sup as xs:integer? ) as element() {
  let $s := request:get-parameter('algo', 'regenerate')
  return
    <Help>
      <div id="c-help" xmlns="http://www.w3.org/1999/xhtml">
        <p><b>Algorithm</b> : please choose algorithm
          <select id="c-algo">
            <option value="regenerate">{ local:filter-selected($s, 'regenerate') }regenerate</option>
            <option value="reset">{ local:filter-selected($s, 'reset') }reset</option>
          </select>
        </p>
        <p><b>Syntaxe</b> : <code>/feeds?m={{method}}[&amp;r={{inf}}-{{sup}}]</code></p>
        <p>with a optional range <a href="feeds?m=view&amp;r=1-10">r=x-y</a> of user Id (x included and y excluded) to apply request to and <i>method</i> :</p>
        <ul>
          <!-- request -->
          <li><a href="feeds?m=request{local:repeat-range($inf, $sup)}">request</a> : generate and show the feed request that would be sent to Case Tracker from the current database content</li>
          <!-- response -->
          <li><a href="feeds?m=response{local:repeat-range($inf, $sup)}">response</a> : generate and show the response sent from Case Tracker from the current database content</li>
          <!-- ... -->
          <li><a href="feeds?m=dry{local:repeat-range($inf, $sup)}">dry</a> : generate the feed request, send it to Case Tracker (like run method), but does not update database, return an update status report for each feed</li>
          <li><b>run</b> : generate the feed request, send it to Case Tracker, update feeds in database, return an update status report for each feed</li>
          <li><b>digest</b> : same behavior as <i>run</i> but in addition save a report in database history (exactly the <b>same behavior as the nightly job</b>), return the update report for each feed</li>
          <li><a href="feeds?m=dump{local:repeat-range($inf, $sup)}" target="blank">dump</a> : dump current feed stats in new window</li>
        </ul>
        <p>internal methods w/o Case Tracker feed web service call where <i>method</i> is :</p>
        <ul>
          <li><a href="feeds?m=recompute{local:repeat-range($inf, $sup)}">recompute</a> : recompute and return all Stats in each Evaluation and the Stats for the feed currently in database</li>
          <li><b>record</b> : recompute (see above) and update all Stats in each Evaluation and the Stats for the feed currently in database. Useful for migration if you  change formulas in feeds.xml</li>
        </ul>
        <p>information about feeds where <i>method</i> is :</p>
        <ul>
          <li><a href="../management/histories" target="blank">histories</a> : show latest digests logs in new window</li>
          <li><a href="feeds?m=stats{local:repeat-range($inf, $sup)}" target="blank">stats</a> : show stats in new window</li>
        </ul>
      </div>
    </Help>
};

declare function local:run( $mode as xs:string, $inf as xs:integer?, $sup as xs:integer?, $algo as xs:string ) as element()? {
  if ($mode = ('recompute', 'record')) then
    <Recompute>
      {
      feeds:recompute-coach-feeds('1', $inf, $sup, $mode eq 'record')
      }
    </Recompute>
  else
    <Pull Inf="{ $inf }" Sup="{ $sup }" Algo="{ $algo }"> 
      {
        let $done :=
          if ($mode eq 'request') then
            feeds:make-feed-requests ('1', $inf, $sup, $algo)/*
          else if ($mode eq 'response') then
            let $requests := feeds:make-feed-requests('1', $inf, $sup, $algo)
            return
              for $req at $i in $requests/Evaluations[count(For/*) > 0]
              return services:post-to-service('cctracker', 'cctracker.feeds', $req, ("200"))
          else (: run, dry, digest :)
            feeds:update-coach-feeds(
              feeds:make-feed-requests('1', $inf, $sup, $algo),
              '1',
              $mode eq 'dry'
            )
        return
          if ($mode eq 'digest') then
            histories:archive-all ('feeds', $done[local-name(.) eq 'error' or error or (ok = ('updated', 'replaced', 'reset'))])
          else
            $done
      }
    </Pull>
};

declare function local:gen-summary-table-headers() {
  <tr xmlns="http://www.w3.org/1999/xhtml">
    <th>Id</th>
    <th>UID</th>
    <th>Name</th>
    <th>Action</th>
    <th>Before</th>
    <th>Perf</th>
    <th>#nb</th>
    <th>RI</th>
    <th>BI</th>
    <th>I</th>
    <th>SME</th>
  </tr>
};

declare function local:as-number( $n as xs:string? ) {
  if ($n) then
    let $res := number($n)
    return
      if (string($res) eq 'NaN') then
        0
      else
        round($res * 100) div 100
  else
    0
};

declare function local:gen-name-column( $user as element() ) {
  concat(
    $user/Information/Name/FirstName, " ", $user/Information/Name/LastName,
    if ($user/UserProfile//FunctionRef = '4' and $user/Hosts/Host[@For eq '1']/WorkingRankRef eq '1') then
      ' (active)'
    else
      ()
    )
};

(: ======================================================================
   Generate table row for a user's feed
   ====================================================================== 
:)
declare function local:gen-feed-sample( $user as element(), $feed as element()? ) {
  if ($feed) then
    let $ri := $feed/Stats/Mean[@For eq 'RI']
    let $bi := $feed/Stats/Mean[@For eq 'BI']
    let $i := $feed/Stats/Mean[@For eq 'I']
    let $sme := $feed/Stats/Mean[@For eq 'SME']
    return
      <xhtml:tr>
        <xhtml:td><a href="../{ $user/Id/text() }" target="_blank">{ $user/Id/text() }</a></xhtml:td>
        <xhtml:td>{ $feed/UID/text() }</xhtml:td>
        <xhtml:td>{ local:gen-name-column($user) }</xhtml:td>
        <xhtml:td><a>dump</a>, <a>request</a>, <a>dry</a>, <a>run</a></xhtml:td>
        <xhtml:td>{ $feed/Period/Before/text() }</xhtml:td>
        <xhtml:td>{ string($feed/parent::Feeds/@Perf) }</xhtml:td>
        <xhtml:td>{ count($feed/Evaluation) }</xhtml:td>
        <xhtml:td>{ string($ri/@Count) } ({ local:as-number($ri) })</xhtml:td>
        <xhtml:td>{ string($bi/@Count) } ({ local:as-number($bi) })</xhtml:td>
        <xhtml:td>{ string($i/@Count) } ({ local:as-number($i) })</xhtml:td>
        <xhtml:td>{ string($sme/@Count) } ({ local:as-number($sme) })</xhtml:td>
      </xhtml:tr>
  else
    <xhtml:tr>
      <xhtml:td>{ $user/Id/text() }</xhtml:td>
      <xhtml:td/>
      <xhtml:td>{ local:gen-name-column($user) }</xhtml:td>
      <xhtml:td><a>dump</a>, <a>request</a>, <a>dry</a>, <a>run</a></xhtml:td>
      { for $i in 1 to 7  return <xhtml:td/> }
    </xhtml:tr>
};

(: ======================================================================
   Return summary table to a range of users
   ====================================================================== 
:)
declare function local:summary-table( $inf as xs:integer?, $sup as xs:integer?  ) {
  (: table header : stats to explain Id discontinuity :)
  let $max := max(fn:collection($globals:persons-uri)//Person/Id)
  let $total := count(fn:collection($globals:persons-uri)//Person)
  return
    <xhtml:p>Max Id : { $max }, Total accounts  { $total }, Deleted accounts : { $max - $total }</xhtml:p>,
  <xhtml:table id="feeds" class="table table-bordered">
    <xhtml:caption>Individual coach feeds </xhtml:caption>
    <xhtml:thead>
      { local:gen-summary-table-headers() }
    </xhtml:thead>
    <xhtml:tbody>
      {
      for $person in fn:collection($globals:persons-uri)//Person
      let $feed := $person//Feeds/Feed[@For eq '1']
      let $id := number($person/Id)
      where
            (empty($inf) or ($id >= $inf))
        and (empty($sup) or ($id < $sup))
      order by $id
      return
        local:gen-feed-sample($person, $feed)
        (: FIXME: show coach status - application not submitted - pending - rejected, etc. :)
      }
    </xhtml:tbody>
  </xhtml:table>
};

(: ======================================================================
   Gen statistics for current Host
   ====================================================================== 
:)
declare function local:gen-stats() {
  let $total1 := count(fn:collection($globals:persons-uri)//Person)
  let $total2 := count(fn:collection($globals:persons-uri)//Person[UserProfile//FunctionRef = '4'][Hosts/Host[@For eq '1']])
  let $coaches := fn:collection($globals:persons-uri)//Person[UserProfile//FunctionRef = '4'][Hosts/Host[@For eq '1'][WorkingRankRef eq '1']]
  let $feeds :=  fn:collection($globals:persons-uri)//Person//Feed[@For eq '1']
  let $max := max(for $f in $feeds return count($f//Evaluation))
  return
    <Stats>
      <p>There are actually { $total1 } persons in database</p>
      <p>There are actually { count($coaches) } active coaches for a total of { $total2 } registered coaches</p>
      <p>Coach Match contains { count($feeds) } individual evaluation feeds for a total of { count($feeds//Evaluation) } evaluations</p>
      <p>The maximum number of evaluations received by a single coach is { $max }</p>
      {
      for $p in $coaches
      where count($p//Feed[@For eq '1']//Evaluation) eq $max
      return
        <p>The maximum number of evaluations has been received by { concat($p/Information/Name/FirstName, " ", $p/Information/Name/LastName) } (Id:{$p/Id/text()})</p>
      }
    </Stats>
};

let $cmd := oppidum:get-command()
let $mode := request:get-parameter('m', 'view')
let $algo := request:get-parameter('algo', 'regenerate')
let $range := tokenize(request:get-parameter('r', ''), '-')
let $inf := if (exists($range)) then number($range[1]) else ()
let $sup := if (exists($range)) then number($range[2]) else ()
return
  <Console>
    <Title>Coach Match feeds console</Title>
    {
    if (empty($mode)) then
      response:redirect-to(xs:anyURI(concat($cmd/@base-url, 'console/feeds?m=help')))
    else if ($mode eq 'dump') then
      response:redirect-to(xs:anyURI(concat($cmd/@base-url, 'console/feeds/dump?r=1,10')))
    else if ($mode = ('stats')) then (
      <Output>{ local:serialize(local:gen-stats()) }</Output>
      )
    else if ($mode = ('help', 'view')) then (
      local:menu($inf, $sup),
      <Output><xhtml:pre id="output">Request inspector</xhtml:pre></Output>
      )
    else (
      local:menu($inf, $sup),
      if ($mode = ('view', 'request', 'response', 'dry', 'run', 'digest', 'recompute', 'record')) then
        <Output>{ local:serialize( local:run($mode, $inf, $sup, $algo) ) } </Output>
      else 
        <Output><xhtml:pre id="output">Unknown mode "{ $mode }"</xhtml:pre></Output>
      ),
    if ($mode = ('view', 'request', 'response', 'dry', 'run')) then
      <Table Name="Feeds">{ local:summary-table($inf, $sup) }</Table>
    else
      ()
    }
  </Console>

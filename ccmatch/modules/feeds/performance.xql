xquery version "3.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Returns performance feed data for coach to plot radar view
   Refreshes host coach feed by calling host feeds web services

   June 2016 - European Union Public Licence EUPL
   ----------------------------------------------- :)

declare namespace json="http://www.json.org";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace services = "http://oppidoc.com/ns/services" at "../../lib/services.xqm";
import module namespace misc = "http://oppidoc.com/ns/misc" at "../../lib/util.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace feeds = "http://oppidoc.com/ns/feeds" at "feeds.xqm";

declare option exist:serialize "method=json media-type=application/json";

(: minimum number of complete evaluations required to display graph :)
declare variable $local:min-evals := 1; (: TODO: move to settings.xml (?) :)
(: minimum period between two checks on Case Tracker :)
declare variable $local:min-checks-delay := "P1D"; (: TODO: move to settings.xml (?) :)
declare variable $local:algo := "regenerate";

(: ======================================================================
   Prepares request to ask Feeds since last feed to case tracker host
   Returns XML request to send to Case Tracker or the empty sequence 
   if feed are already synchronized (got data until current day)
   ====================================================================== 
:)
declare function local:gen-feed-request( $person as element(), $host as xs:string ) as element()? {
  let $feed := $person/Feeds/Feed[@For eq $host]
  let $uid := $feed/UID
  let $before := $feed/Period/Before
  return
    if (empty($before) or (current-date() >= (xs:date($before) + xs:dayTimeDuration($local:min-checks-delay)))) then
      <Evaluations Algorithm="{$local:algo}">
        <For>
          {
          if ($feed/UID) then 
            <UID Count="{ count($feed/Evaluation) }">{ $feed/UID/text() }</UID>
          else if ($person/UserProfile/Remote[@Name eq 'ECAS']) then
            <Remote Count="{ count($feed/Evaluation) }" Name="ECAS">{ $person/UserProfile/Remote[@Name eq 'ECAS']/text() }</Remote>
          else
            <Email Count="{ count($feed/Evaluation) }">{ $person/Information/Contacts/Email/text() }</Email>
          }
        </For>
        {
          if ($before) then
             <After Bound="include">{ $before }</After>
          else
            ()
        }
      </Evaluations>
    else
      ()
};

(: ======================================================================
   Updates the coach feed from the Case Tracker host if:
   - coach is accepted and in working rank
   - feed is not already up to date
   Lazy creation of coach feed if necessary
   Returns <ok> with a status information or throws an <error>
   See also: feeds:make-feed-requests in feeds.xqm that shouls apply same logic
   ====================================================================== 
:)
declare function local:update-coach-feed ( $person as element(), $host as xs:string ) {
  if ($person/Hosts/Host[@For eq $host]/WorkingRankRef eq '1') then
    let $update := local:gen-feed-request($person, $host)
    return 
      if ($update) then (: invokes Case Tracker service :)
        let $response :=  services:post-to-service('cctracker', 'cctracker.feeds', $update, ("200"))
        return 
          if (local-name($response) ne 'error') then
            let $feed := $response//Feed[1]
            return
              if ($feed//Evaluation/error) then
                <error><message>{ string-join($feed//Evaluation/error, ', ') }</message></error>
              else
                feeds:update-coach-feed($person, $host, $feed, false())
          else
            oppidum:throw-error('CUSTOM', $response/message/text())
      else
        <ok>fresh</ok>
  else
    <ok>inactive</ok>
};

(: ======================================================================
   Returns interval in months between first and last evaluation in feed
   Note: substracting dates always returns a xs:dayTimeDuration (see Walmsley)
   ====================================================================== 
:)
declare function local:compute-elapsed-time( $feed as element() ) {
  let $today := current-date()
  let $older := min(for $d in $feed/Evaluation/@Date where $d ne '' return xs:date(substring($d, 1, 10)))
  let $days := days-from-duration($today - $older)
  return
    $days idiv 30.5 + 1
};

declare function local:compute-last-evaluated( $feed as element()? ) as xs:string? {
  if (exists($feed)) then
    let $younger := max(for $d in $feed/Evaluation/@Date where $d ne '' return xs:date(substring($d, 1, 10)))
    return
      if (exists($younger)) then
        concat(', latest evaluation dates back to ', display:gen-display-date(string($younger), 'en'))
      else
        ()
  else
    ()
};

(: ======================================================================
   Serializes a coach performance data from a given host for plotting

   Only take into accounts complete evaluations (all axis) and only
   if there are at least $local:min-evals of them

   Note that since it uses cached Feed Stats summary it must be aligned 
   with feeds:update-feed-stats() summary computation in feeds.xqm

   WARNING: xs:double(4.1) - 1 => 3.0999999999999996
   ====================================================================== 
:)
declare function local:gen-performance-graph( $person as element(), $host as xs:string, $status as xs:string, $error as xs:string? ) {
  let $feed := $person/Feeds/Feed[@For eq $host]
  let $defs := fn:doc($globals:feeds-uri)/Feeds/Feed[@For eq $host]//Mean (: variable definitions :)
  let $total := count($feed/Evaluation)
  let $count := count($feed/Evaluation[not(Stats/Mean eq '0')])
  let $partial := $total - $count
  let $elapsed := if ($total > 0) then local:compute-elapsed-time($feed) else 0
  return
    <Performance Status="{ $status }">
      <Settings>
        <Format>.2</Format>
        <Max>4</Max>
        <Levels>4</Levels>
        <Delta>1</Delta>
      </Settings>
      <Legend>Base : { $total } coaching { misc:pluralize('activity', $total) } { if ($total eq 0) then () else concat(" during the last ", $elapsed, " ", misc:pluralize('month', $elapsed)) }{ local:compute-last-evaluated($feed) }</Legend>
      {
      if ($count >= $local:min-evals) then
        (
        <Summary>
          {
          for $axis in $defs
          let $key := string($axis/@Filter)
          let $score := round($feed/Stats/Mean[@For eq $key] * 100) div 100
          (:let $pourcent := (avg($feed/Evaluation[not(Stats/Mean eq '0')]/Stats/Mean[@For eq $key][. ne '0']/text()) - 1) * 25:)
          where $feed/Stats/Mean[@For eq $key] ne '0'
          return
              <Axis For="{ display:get-local-string($axis/@loc, 'en') } ({$score})">
                <Score>{ $score }</Score>
              </Axis>
          }
        </Summary>,
        <Message>{ local:acceptance($person) }{ local:last-check($feed/Period/Before) }{ local:error($error) }</Message>
        )
      else
        <Message>The performance graph will be available once you have received at least { $local:min-evals } complete { misc:pluralize('evaluation', $local:min-evals) }. { local:acceptance($person) }{ local:last-check($feed/Period/Before) }{ local:error($error) }</Message>
      }
      <Detail>
        {
        for $axis in $defs[@Filter = ('RI', 'BI', 'I')]
        return
          for $rank in $axis/Rank
          let $scores := 
            feeds:as-numbers(
              for $s in $feed/Evaluation/Scores
              return
                tokenize($s, ' ')[position() = $rank/text()]
            )
          return
            element { concat('q', $rank) } {
              <avg>{ round(avg($scores[. ne 0]) * 100) div 100 }</avg>,
              <nb>{ count($scores[. ne 0]) }</nb>
              },
        for $mean in $feed/Stats/Mean
        return
          element { string($mean/@For) } {
            <avg>{ round($mean * 100) div 100 }</avg>,
            <nb>{ string($mean/@Count) }</nb>
          }
        }
      </Detail>
    </Performance>
};

(: ======================================================================
   Utility to generate acceptance explanation
   ====================================================================== 
:)
declare function local:acceptance( $person as element() ) as xs:string? {
  if ($person/Hosts/Host[WorkingRankRef eq '1']) then (: Accepted and in working order :)
    ()
  else if ($person/Hosts/Host[AccreditationRef eq '4']) then (: Accepted but not in working order :)
    " You are registered as an accepted coach in a host organization but it seems you have been deactivated by this host organization. By consequence your performance is not actually updated with the latest coaching evaluations. "
  else
    " You are actually not accepted in any host organization, thus your performance is not updated with the latest coaching evaluations. "
};

(: ======================================================================
   Utility to generate error last check time stamp into feedback
   ====================================================================== 
:)
declare function local:last-check( $date as element()? ) as xs:string? {
  if ($date/@TS) then 
    concat(
      " Last check ",
      display:gen-display-dateTime(string($date/@TS), 'en'),
      "."
    )
  else
    ()
};

(: ======================================================================
   Utility to generate error feedback under performance graph
   ====================================================================== 
:)
declare function local:error(  $error as xs:string? ) as xs:string? {
  if ($error) then 
    concat(" Today's check failed. ", $error)
  else
    ()
};

let $submitted := oppidum:get-data()
let $cmd := request:get-attribute('oppidum.command')
let $token := string($cmd/resource/@name)
let $user := oppidum:get-current-user()
let $groups := oppidum:get-current-user-groups()
let $person := access:get-person($token, $user, $groups)
return
  (: TODO : assert $submitted... :)
  if (local-name($person) ne 'error') then
    let $result := local:update-coach-feed($person, "1")
    return
      if (local-name($result) eq 'ok') then (
        if ($result = ('updated', 'replaced', 'reset')) then (: add 'same' to force update :) 
          feeds:update-feed-stats($person, "1")
        else
          (),
        local:gen-performance-graph($person, "1", $result, ())
        )[last()]
      else (
        response:set-status-code(200), (: overwrites throw-error :)
        local:gen-performance-graph($person, "1", $result, $result/message)
        )
  else
    $person

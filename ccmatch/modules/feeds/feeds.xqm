xquery version "3.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Utilities to manage evaluation feeds

   June 2016 - European Union Public Licence EUPL
   ----------------------------------------------- :)

module namespace feeds = "http://oppidoc.com/ns/feeds";

import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace services = "http://oppidoc.com/ns/services" at "../../lib/services.xqm";
import module namespace misc = "http://oppidoc.com/ns/misc" at "../../lib/util.xqm";
import module namespace match = "http://oppidoc.com/ns/match" at "../suggest/match.xqm";

declare option exist:serialize "method=json media-type=application/json";

declare function feeds:as-numbers( $scores as xs:string* ) as xs:double* {
  for $n in $scores
  return 
    let $res := xs:decimal($n)
    return
      if (string($res) eq 'NaN') then
        0
      else
        $res
};

(: ======================================================================
   Converts whitespace separated list of scores into xd:double sequence
   ====================================================================== 
:)
declare function local:gen-evaluation-scores( $scores as xs:string* ) as xs:double* {
  feeds:as-numbers(tokenize($scores, ' '))
};

(: ======================================================================
   Returns average of feedbacks at ranks if at least one is defined
   Returns non value 0 otherwise
   See also: Case Tracker module stats.xqm
   ====================================================================== 
:)
declare function local:calc-average(
  $feedbacks as xs:double*,
  $ranks as element()
  )
{
  let $vals := $feedbacks[position() = $ranks/Rank/text()][. ne 0]
  return (: computes if at least one answer :)
    if (empty($vals)) then
      0
    else
      avg($vals)
};

(: ======================================================================
   Returns the score for name variable filter using stats.xml definition
   See also: Case Tracker module stats.xqm
   ====================================================================== 
:)
declare function local:calc-filter(
  $meandef as element(),
  $feedbacks as xs:double*
  ) as xs:double
{
  let $ranks := $meandef/Rank/text()
  return 
    if (empty($ranks)) then (: mean of means :)
      let $composition := $meandef/parent::Composition
      let $means := 
        for $m in $composition/Mean[@Filter ne $meandef/@Filter]
        return local:calc-average($feedbacks, $m)
      return
        if (exists($means[. = 0])) then (: cannot compute :)
          0
        else
          avg($means)
    else (: computes if at least one answer :)
      local:calc-average($feedbacks, $meandef)
};

(: ======================================================================
   Regenerates global Stats and Perf for a feed of evaluations from a host
   Perf and Stats are computed only from complete evaluations (i.e. no Mean is 0)
   The global Stats and Perf cache contain pre-computed means to speed up
   graph generation or performance score generation
   Returns the Perf string
   ====================================================================== 
:)
declare function feeds:update-feed-stats ( $person as element(), $host as xs:string ) as xs:string? {
  let $safe-person := fn:collection($globals:persons-uri)//Person[Id eq $person/Id]
  let $feed := $safe-person/Feeds/Feed[@For eq $host]
  let $stats := 
    <Stats Date="{ current-dateTime() }">
    {
    for $axis in fn:doc($globals:feeds-uri)/Feeds/Feed[@For eq $host]//Mean
    let $key := string($axis/@Filter)
    let $samples :=  if ($axis/@Stats eq 'alone') then 
                       feeds:as-numbers($feed/Evaluation/Stats/Mean[@For eq $key][. ne '0'])
                     else (: retains only complete evaluations :)
                       feeds:as-numbers($feed/Evaluation[not(Stats/Mean = '0')]/Stats/Mean[@For eq $key])
    return
      <Mean For="{ $key }" Count="{ count($samples[. ne 0]) }">
        { 
        let $mean := avg($samples[. ne 0])
        return 
          if ($mean) then $mean else 0
        }
      </Mean>
    }
    </Stats>
  return (
    (: updates host feed stats :)
    misc:save-content-silent($feed, $feed/Stats, $stats),
    (: updates multiple-hosts aggregated Perf :)
    let $perf := match:calc-performance-score (
            $safe-person/Feeds,
            ($stats, $safe-person/Feeds/Feed[@For ne $host]/Stats)
            )
    return (
      if ($safe-person/Feeds/@Perf) then
        update value $safe-person/Feeds/@Perf with $perf
      else
        update insert attribute { 'Perf'} { $perf } into $safe-person/Feeds,
      $perf
      )
    )[last()]
};

(: ======================================================================
   Transformed a single Evaluation received from host into internal representation
   FIXME: currently store as is, store pre-computed means into Cache element of Feed
   ====================================================================== 
:)
declare function local:gen-evaluation-for-writing($e, $host) {
  <Evaluation>
    {
    $e/@*,
    $e/*,
    let $scores := local:gen-evaluation-scores($e/Scores)
    let $means := fn:doc($globals:feeds-uri)/Feeds/Feed[@For eq $host]//Mean
    return
      <Stats>
      {
      for $axis in $means
      let $key := string($axis/@Filter)
      return
        <Mean For="{ $key }">{ local:calc-filter($axis, $scores) }</Mean>
      }
      </Stats>
    }
  </Evaluation>
};

(: ======================================================================
   Returns a new Period element to update a feed time record
   Returns the empty sequence if no need for update
   FIXME: should get boundaries from feed, actually always before current date
   ====================================================================== 
:)
declare function local:gen-period-for-writing( $legacy as element()?, $feed as element()? ) as element()? {
  <Period>
    <Before TS="{ current-dateTime() }">{ substring(string(current-date()), 1, 10) }</Before>
  </Period>
};

(: ======================================================================
   Updates Period into feed optimized if feed already exists
   ====================================================================== 
:)
declare function local:update-feed-timestamp( $feed as element()?, $incoming as element()? ) as element()? {
  let $before := $feed/Period/Before
  return
    if ($before) then (
      update value $before with substring(string(current-date()), 1, 10),
      if ($before/@TS) then
        update value $before/@TS with current-dateTime()
      else
        update insert attribute { 'TS' } { current-dateTime() } into $before
      )
    else
      misc:save-content-silent($feed, $feed/Period,
        local:gen-period-for-writing($feed/Period, $incoming))
};

(: ======================================================================
   Creates evaluations feed for a given host
   Can be called without evaluation to bootstrap a timestamped feed
   ====================================================================== 
:)
declare function local:create-evaluations-feed( $person as element(), $incoming as element()?, $host as xs:string ) {
  let $data := 
    <Feed For="{ $host }" Creation="{ current-dateTime() }">
      {
      local:gen-period-for-writing((), $incoming),
      $incoming/UID,
      for $eval in $incoming/Evaluations/Evaluation
      return
        local:gen-evaluation-for-writing($eval, $host)
      }
    </Feed>
  return
    if ($person/Feeds) then
      update insert $data into $person/Feeds
    else
      update insert <Feeds>{ $data }</Feeds> into $person
};

(: ======================================================================
   Removes all evaluations into person's profile which are not in incoming feed
   ====================================================================== 
:)
declare function local:remove-evaluations-feed( $person as element(), $feed as element()?, $incoming as element()?, $host as xs:string ) {
  if ($feed) then
    for $eval in $feed/Evaluation
    where empty($incoming/Evaluation[Id eq $eval/Id]) (: removes legacy :)
    return
      update delete $eval
  else
    ()
};

(: ======================================================================
   Records incoming evaluations into person's profile for given host
   TODO: generate Before in case tracker services (more logical ?)
   ====================================================================== 
:)
declare function local:save-evaluations-feed( $person as element(), $feed as element()?, $incoming as element()?, $host as xs:string ) {
  if ($feed) then (
    if (empty($feed/UID) and exists($incoming/UID)) then (: in case the feed was created empty w/o UID :)
      update insert $incoming/UID into $feed
    else
      (),
    for $eval in $incoming/Evaluations/Evaluation
    where ($incoming/@Content eq 'reset') or empty($feed/Evaluation[Id eq $eval/Id]) (: avoid duplicates :)
    order by substring($eval/@Date, 1, 10) ascending
    return
      update insert local:gen-evaluation-for-writing($eval, $host) into $feed,
    local:update-feed-timestamp($feed, $incoming)
    )
  else
    local:create-evaluations-feed($person, $incoming, $host)
};

(: ======================================================================
   Updates the coach feed coming from the Case Tracker host with the new feed evaluations
   Lazy creation of coach feed if necessary
   Returns <ok> with a status information
   ====================================================================== 
:)
declare function feeds:update-coach-feed ( $person as element(), $host as xs:string, $incoming as element()?, $dry as xs:boolean ) as element() {
  let $feed := $person/Feeds/Feed[@For eq $host]
  return
    if ($incoming/@Content eq 'reset') then
      let $del := count($feed/Evaluation)
      let $add := count($incoming/Evaluations/Evaluation)
      return (
        if ($dry) then 
          ()
        else (
          for $eval in $feed/Evaluation
          return update delete $eval,
          local:save-evaluations-feed($person, $feed, $incoming, $host)
          ),
        <ok del="{ $del }" add="{ $add }">reset</ok>
        )[last()]
    else if ($incoming/@Content eq 'all') then (
      if ($dry) then 
        ()
      else (
        local:remove-evaluations-feed($person, $feed, $incoming, $host),
        local:save-evaluations-feed($person, $feed, $incoming, $host)
        ),
      <ok>replaced</ok>
      )[last()]
    else if (some $e in $incoming/Evaluations/Evaluation satisfies empty($feed/Evaluation[Id eq $e/Id])) then (
      if ($dry) then
        ()
      else
        local:save-evaluations-feed($person, $feed, $incoming, $host),
      <ok>updated</ok>
      )[last()]
    else (
      (: just saves period timestamp into feed :)
      if ($dry) then
        ()
      else
        if ($feed) then 
          local:update-feed-timestamp($feed, $incoming)
        else
          local:create-evaluations-feed($person, (), $host),
      <ok>same</ok>
      )[last()]
};

(: ======================================================================
   Returns request to trigger feeds from given host
   Actually splits it in two requests :
   - one for first time coaches (no feed yet)
   - one for all other coaches (feed already exists)
   Only retrieves feeds for coaches accepted with the host
   See also: local:update-coach-feed in performance.xql that shouls apply same logic
   ====================================================================== 
:)
declare function feeds:make-feed-requests ( $host-ref as xs:string, $inf as xs:double?, $sup as xs:double?, $algo as xs:string ) as element() {
  <Pull>
    <Evaluations Format="short">
      <For>
        {
        for $c in fn:collection($globals:persons-uri)//Person[UserProfile//FunctionRef = '4'][Hosts/Host[@For eq $host-ref][WorkingRankRef eq '1']]
        where empty($c/Feeds/Feed[@For eq $host-ref]) and $c/Information/Contacts/Email
        return 
          <Email Id="{ $c/Id }">{ $c/Information/Contacts/Email/text() }</Email>
        }
      </For>
    </Evaluations>
    {
    let $min-date := min(
        distinct-values(
        fn:collection('/db/sites/ccmatch/persons')//Person[UserProfile//FunctionRef = '4'][Hosts/Host[@For eq $host-ref][WorkingRankRef eq '1']][Feeds/Feed[@For eq $host-ref]]//Feed/Period/string(Before)
        )
      )
    return
      <Evaluations Format="short" Algorithm="{ $algo }">
        <For>
          {
          for $c in fn:collection($globals:persons-uri)//Person[UserProfile//FunctionRef = '4'][Hosts/Host[@For eq $host-ref][WorkingRankRef eq '1']]
          let $feed := $c/Feeds/Feed[@For eq $host-ref]
          where $feed 
                and (($feed/UID) or $c/UserProfile/Remote[@Name eq 'ECAS'] or $c/Information/Contacts/Email)
                and (empty($inf) or (number($c/Id) >= $inf))
                and (empty($sup) or (number($c/Id) < $sup))
          return (: FIXME: hard-coded ECAS, this may be host dependent :)
            if ($feed/UID) then 
              <UID Id="{ $c/Id }" Count="{ count($feed/Evaluation) }">{ $feed/UID/text() }</UID>
            else if ($c/UserProfile/Remote[@Name eq 'ECAS']) then
              <Remote Id="{ $c/Id }" Count="{ count($feed/Evaluation) }" Name="ECAS">{ $c/UserProfile/Remote[@Name eq 'ECAS']/text() }</Remote>
            else
              <Email Id="{ $c/Id }" Count="{ count($feed/Evaluation) }">{ $c/Information/Contacts/Email/text() }</Email>
          }
        </For>
        <After Bound="include">{ $min-date }</After>
      </Evaluations>
    }
  </Pull>
};

(: ======================================================================
   Adds an evaluations feed to a coach record, merges the new evaluations
   if the coach already has received some feeds, replaces them all 
   if the incoming feed has a Content attribute set to all
   TODO: hard-coded host 1 !
   ======================================================================
:)
declare function local:add-feed( $key as xs:string, $person as element()?, $host as xs:string, $feed as element()?, $dry as xs:boolean ) {
  if ($person) then (: defensive sanity check :)
    (: don't update feed if Case Tracker raised an error during score computation :)
    if ($feed//Evaluation/error) then
      <Entry Key="{ $key }" ID="{ $person/Id }">
        { $feed//Evaluation/error }
      </Entry>
    else
      let $result:= 
        try { 
          feeds:update-coach-feed($person, $host, $feed, $dry)
        } catch * {
          <error>Caught error {$err:code}: {$err:description}</error>
        }
      return 
          if ($result = ('updated', 'replaced', 'reset')) then (: add 'same' to force update :)
            <Entry Key="{ $key }" ID="{ $person/Id }">
              { 
              attribute { 'Perf' } {
                if ($dry) then
                  'dry'
                else
                  feeds:update-feed-stats($person, '1')
                },
              $result,
              if ($dry) then <Response>{$feed}</Response> else ()
              }
            </Entry>
          else
            <Entry Key="{ $key }" ID="{ $person/Id }">
              { 
              $result,
              if ($dry) then <Response>{$feed}</Response> else ()
              }
            </Entry>
    else
      ()
};

(: ======================================================================
   Guard function just in case Case Tracker returns multiple Feed 
   for the same key ot there are multiple persons with the same key 
   in Coach Match database.
   TODO: we need to run integrity checks to avoir multiple persons !
   ====================================================================== 
:)
declare function local:add-feeds ( $key as xs:string, $person as element()*, $host as xs:string, $feed as element()*, $dry as xs:boolean ) {
  if (count($feed) > 1) then
    (: iterates just in case multiple accounts are registered 
       with the key in the host, merges evaluations in that case :)
    for $f in $feed 
    return
      if (count($person) > 1) then
        for $p in $person 
        (: FIXME: return an error instead ? :)
        return
          local:add-feed($key, $p, $host, $f, $dry)    
      else
        local:add-feed($key, $person, $host, $f, $dry)    
  else
    if (count($person) > 1) then
      for $p in $person 
      return
        (: FIXME: return an error instead ? :)
        local:add-feed($key, $p, $host, $feed, $dry)
    else
      local:add-feed($key, $person, $host, $feed, $dry)
};

(: ======================================================================
   Update the coach feed coming from the Case Tracker host if not already
   up to date. Lazy creation of coach feed if necessary. 
   Do not update database when $dry is set to true() for debugging.
   Return a list of Entry records with a status information (updated or same)
   or throws an <error>
   ====================================================================== 
:)
declare function feeds:update-coach-feeds ( $requests as element()?, $host as xs:string, $dry as xs:boolean ) {
  for $req at $i in $requests/Evaluations[count(For/*) > 0]
  let $response :=  services:post-to-service('cctracker', 'cctracker.feeds', $req, ("200"))
  return (
    if (local-name($response) ne 'error') then (
      for $uid in $req/For/UID
      let $person := fn:collection($globals:persons-uri)//Person[Id eq $uid/@Id]
      let $feed := $response//Feed[UID eq $uid]
      return local:add-feeds($uid, $person, $host, $feed, $dry),
      for $rem in $req/For/Remote
      let $person := fn:collection($globals:persons-uri)//Person[UserProfile/Remote[@Name eq $rem/@Name] eq $rem]
      let $feed := $response//Feed[Remote eq $rem]
      return local:add-feeds($rem, $person, $host, $feed, $dry),
      for $email in $req/For/Email
      let $person := fn:collection($globals:persons-uri)//Person[Id eq $email/@Id]
      let $feed := $response//Feed[Email eq $email]
      return local:add-feeds($email, $person, $host, $feed, $dry)
      )
    else
      $response
    )
};

(: ======================================================================
   Same as feeds:update-feed-stats but for migrations
   See feeds:recompute-coach-feeds
   ====================================================================== 
:)
declare function local:compute-feed-stats ( $feed as element() ) as element() {
    <Stats>
    {
    for $axis in fn:doc($globals:feeds-uri)/Feeds/Feed[@For eq '1']//Mean
    let $key := string($axis/@Filter)
    let $samples :=  if ($axis/@Stats eq 'alone') then
                       feeds:as-numbers($feed/Evaluation/Stats/Mean[@For eq $key][. ne '0'])
                     else (: retains only complete evaluations :)
                       feeds:as-numbers($feed/Evaluation[not(Stats/Mean = '0')]/Stats/Mean[@For eq $key])
    return
      <Mean For="{ $key }" Count="{ count($samples[. ne 0]) }">
        { 
        let $mean := avg($samples[. ne 0])
        return 
          if ($mean) then $mean else 0
        }
      </Mean>
    }
    </Stats>
};

(: ======================================================================
   Recomputes and saves (if $record is true) all Stats in each Evaluation 
   and the Stats for the feed. Use that function for migration in case 
   you change formulas in feeds.

   FIXME: update @Perf too with match:calc-performance-score ?
   ====================================================================== 
:)
declare function feeds:recompute-coach-feeds ( $host as xs:string, $inf as xs:double?, $sup as xs:double?, $record as xs:boolean ) {
  for $feed in fn:collection($globals:persons-uri)//Person//Feed[@For eq $host]
  let $c := $feed/ancestor::Person
  where (empty($inf) or (number($c/Id) >= $inf))
        and (empty($sup) or (number($c/Id) < $sup))
  return
    <Entry ID="{ $feed/ancestor::Person/Id }" >
      {
      if (count($feed/Evaluation) > 0) then
        let $refeed := 
          <Feed>
          {
          (: see also local:gen-evaluation-for-writing :)
          for $e in $feed/Evaluation
          let $scores := local:gen-evaluation-scores($e/Scores)
          let $means := fn:doc($globals:feeds-uri)/Feeds/Feed[@For eq $host]//Mean
          return
            <Evaluation>
            {
            <Stats>
            {
            for $axis in $means
            let $key := string($axis/@Filter)
            let $val := local:calc-filter($axis, $scores)
            let $mean := <Mean For="{ $key }">{ $val }</Mean>
            return
               if (exists($e/Stats/Mean[@For eq $key])) then
                 if ($e/Stats/Mean[@For eq $key] = string($val)) then
                   $mean
                 else (
                   if ($record) then update replace $e/Stats/Mean[@For eq $key] with $mean else (),
                   <Mean _action="replace" For="{ $key }">{ $val }</Mean>
                   )
               else (
                 if ($record) then update insert $mean into $e/Stats else (),
                 <Mean _action="insert" For="{ $key }">{ $val }</Mean>
                 )
            }
            </Stats>
            }
            </Evaluation>
          }
          </Feed>
        return (
          $refeed,
          let $glob-stats :=  local:compute-feed-stats($refeed)
          return
            if (exists($feed/Stats)) then
              <Stats>
                {
                for $mean in $glob-stats/Mean
                return
                  if (exists($feed/Stats/Mean[@For eq $mean/@For])) then
                    if ($feed/Stats/Mean[@For eq $mean/@For] = $mean) then
                      (: TODO: replace vs insert :)
                      $mean
                    else (
                      if ($record) then update replace $feed/Stats/Mean[@For eq $mean/@For] with $mean else (),
                      <Mean _action="replace">{ $mean/@For, $mean/@Count, $mean/text() }</Mean>
                      )
                  else (
                    if ($record) then update insert $mean into $feed/Stats else (),
                    <Mean _action="insert">{ $mean/@For, $mean/@Count, $mean/text() }</Mean>
                    )
                  }
              </Stats>
            else
              <Stats action="_insert" Date="{ current-dateTime() }">
                {
                $glob-stats/*  
                }
              </Stats>
          )
      else
        <empty/>
      }  
    </Entry>
};

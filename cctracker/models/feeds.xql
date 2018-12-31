xquery version "3.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Service to publish coach performance feeds

   To be called from third party applications like Coach Match

   Implements XML protocol :

   POST
    <Evaluations [Format="short"] [Algorithm="regenerate"]>
      <For>?
        <Email>* : coach by e-mail 
        <UID>* : coach by case tracker UID
      <Before [Bound='include']> : evaluations completed before date
      <After [Bound='include']> : evaluations completed after date

   Returns
    <Feeds>
      <Feed>* : one per coach
        <Email> : coach e-mail 
        <UID> : coach case tracker UID
        <Evaluations>
          <Evaluation Date="">
            <Id>
            <Scores>
            <Comment Ref="">*
            [ <Author Ref="">*  ----> not implemented
              <UID>
              <Email>
              <Name>
                <FirstName>
                <LastName> ]

   The return set only includes coaches with at least one evaluation
   Note that if an email address is registered with several users the result
   may contain several feeds with different UID for the same email address

   TODO: maybe Feed could include incomplete evaluations (Closed activities with enough answers ?)

   June 2016 - European Union Public Licence EUPL
   ----------------------------------------------- :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";
declare namespace request = "http://exist-db.org/xquery/request";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../lib/globals.xqm";
import module namespace services = "http://oppidoc.com/ns/services" at "../lib/services.xqm";
import module namespace account = "http://platinn.ch/coaching/account" at "../modules/users/account.xqm";
import module namespace stats = "http://oppidoc.com/ns/cctracker/stats" at "../modules/stats/stats.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Implements After[@Bound='include']
   ====================================================================== 
:)
declare function local:gen-min-date( $date as element()? ) as xs:string? {
  if ($date/@Bound eq 'include') then
    string(xs:date(string($date)) -  xs:dayTimeDuration("PT24H"))
  else
    $date
};

(: ======================================================================
   Implements Before[@Bound='include']
   ====================================================================== 
:)
declare function local:gen-max-date( $date as element()? ) as xs:string? {
  if ($date/@Bound eq 'include') then
    string(xs:date(string($date)) +  xs:dayTimeDuration("PT24H"))
  else
    $date
};

(: ======================================================================
   Convert Remote, Email or UID key into internal Case Tracker coach Id
   ====================================================================== 
:)
declare function local:get-coach-ref-from-key( $key as element() ) as xs:string* {
  switch (local-name($key))
  case 'Remote' return fn:collection($globals:persons-uri)//Person[UserProfile/Remote[@Name eq $key/@Name] eq $key]/Id
  case 'Email' return (fn:collection($globals:persons-uri)//Person[Contacts/Email eq $key]/Id)[1] (: defensive :)
  case 'UID' return $key
  default return ()
};

(: ======================================================================
   Return a sequence of Evaluation elements received by the coach 
   in the given period (does not include boundaries).
   Each evaluation contains an Id, a Scores vector and the Comment to KAM 
   question 15
   ====================================================================== 
:)
declare function local:gen-evaluations-for-coach( $coach as element(), $after as xs:string?, $before as xs:string? ) as element()* 
{
  for $a in fn:collection($globals:projects-uri)//Activity[StatusHistory/CurrentStatusRef = ('10', '11')][Assignment/ResponsibleCoachRef eq $coach/Id]
  let $cur-status := $a/StatusHistory/CurrentStatusRef
  let $timestamp := $a/StatusHistory/Status[ValueRef eq $cur-status]/Date
  let $date := substring($timestamp, 1, 10)
  where     (empty($after) or ($date > $after))
        and (empty($before) or ($date < $before))
  return
    <Evaluation Date="{ $timestamp }">
      <Id>{ concat($a/ancestor::Project/Id, '.', $a/ancestor::Case/No, '.', $a/No) }</Id>
      {
        try {
          let $vector := stats:gen-feedbacks-sample($a)
          return (
            <Scores>
              { 
              concat(
                string-join(for $v in $vector return string($v), ' '),
                ' ',
                stats:as-score($a/FinalReportApproval/Dialogue/RatingScaleRef)
                ) (: adds Question 15 :)
              }
            </Scores>,
            (: extra evaluation data :)
            if ($a/FinalReportApproval/Dialogue/Comment) then 
              <Comment Ref="15">{ $a/FinalReportApproval/Dialogue/Comment/text() }</Comment>
            else
              ()
            )
        }
        catch * {
          <error>Caught error {$err:code}: {$err:description}</error>
        }
      }
    </Evaluation>
};

(: ======================================================================
   Coach feed generation "regenerate" algorithm.
   
   Generate a Feed with every Evaluation received in the given period
   When the coach key element has a Count attribute, compare the Count 
   plus the number of evaluations in the period with the total number 
   of evaluations actually in Case Tracker for the coach. If they differ
   send back a full feed marked as @Content="all".
   ======================================================================
:)
declare function local:regenerate-feed-for-coach-key( $key as element(), $after as xs:string?, $before as xs:string? ) as element()? {
  let $key-tag := local-name($key)
  let $coach-ref := local:get-coach-ref-from-key($key)
  return 
    if (exists($coach-ref)) then
      let $c := fn:collection($globals:persons-uri)//Person[Id = $coach-ref]
      let $return-key :=  if ($key-tag ne 'UID') then
                            (: return key to allow client to associate it with UID :)
                            element { $key-tag } {  $key/text() }
                          else
                            ()
      return
        if ($c) then
          let $total := count(fn:collection($globals:projects-uri)//Activity[StatusHistory/CurrentStatusRef = ('10', '11')][Assignment/ResponsibleCoachRef eq $coach-ref])
          let $delta := local:count-delta-evaluations-for($coach-ref, $after, $before)
          return
            if ($total ne (number($key/@Count) + $delta)) then (: complete feed to give a chance to client to synchronize :)
              <Feed Content="all" Total="{ $total }" Count="{ $key/@Count }" Delta="{ $delta }" >
                <UID>{ $c/Id/text() }</UID>
                { $return-key }
                <Evaluations>
                  { local:gen-evaluations-for-coach($c, (), ()) }
                </Evaluations>
              </Feed>
            else (: classical diff feed :)
              let $evaluations := local:gen-evaluations-for-coach($c, $after, $before)
              return
                if (empty($evaluations)) then
                  ()
                else
                  <Feed> 
                    <UID>{ $c/Id/text() }</UID>
                    { $return-key }
                    <Evaluations>
                      { $evaluations }
                    </Evaluations>
                  </Feed>
        else
          <NoUID For="{ $key }"/>
    else (: maybe we should return empty feed to let client remove feeds ? :)
      <NoRemoteOrEmail For="{ $key }"/>
};

(: ======================================================================
   Coach feed generation "reset" algorithm.

   Return Feed with all Evaluation elements for a known coach or an empty 
   Evaluations element if none is available (empty feed).

   Also return an empty Feed if the coach is not found but the client 
   specified a @Count.

   Return the empty sequence if the coach is not known and the client 
   didn't specified a @Count.
   ======================================================================
:)
declare function local:reset-feed-for-coach-key( $key as element() ) as element()? {
  let $key-tag := local-name($key)
  let $coach-ref := local:get-coach-ref-from-key($key)
  let $c := if ($coach-ref) then fn:collection($globals:persons-uri)//Person[Id = $coach-ref] else ()
  return 
    if (exists($c)) then
      <Feed Content="reset"> 
        <UID>{ $c/Id/text() }</UID>
        {
        if ($key-tag ne 'UID') then
          element { $key-tag } {  $key/text() }
        else
          ()
        }
        <Evaluations>
          { local:gen-evaluations-for-coach($c, (), ()) }
        </Evaluations>
      </Feed>
    else if ($key/@Count and number($key/@Count) >= 0) then
      (: maybe coach has been deleted, return an empty Feed :)
      <Feed Content="reset">
        { element { $key-tag } { $key/text() } }
        <Evaluations/>
      </Feed>
    else
      ()
};

(: ======================================================================
   Coach feed generation default algorithm.

   Return Feed with all Evaluation elements for a coach in a given period
   or the empty sequence if no Evaluation available.

   Was DEPRECATED in Coach Match client in favor of "regenerate" algorithm
   ======================================================================
:)
declare function local:gen-feed-for-coach-ref( $coach-ref as xs:string, $after as xs:string?, $before as xs:string? ) as element()? {
  let $c := fn:collection($globals:persons-uri)//Person[Id = $coach-ref]
  return
    let $evaluations := local:gen-evaluations-for-coach($c, $after, $before)
    return
      if (empty($evaluations)) then
        ()
      else
        <Feed> 
          <UID>{ $c/Id/text() }</UID>
          { $c/Contacts/Email }
          <Evaluations>
            {
            $evaluations
            }
          </Evaluations>
        </Feed>
};

(: ======================================================================
   Return list of coach references for which to generate feeds either
   from a limited set of coach key elements or the full list otherwise

   Use this if you want to support client requests w/o coach key to 
   retrieve all Case Tracker coach feeds !
   ====================================================================== 
:)
declare function local:gen-coach-refs-for-feeds( $submitted as element() ) as xs:string* {
  if (count($submitted/For/*) > 0) then
    distinct-values(
      (
      for $key in $submitted/For/*
      return local:get-coach-ref-from-key($key)
      )
    )
  else (: full dump :)
    distinct-values(fn:collection($globals:projects-uri)//Activity[StatusHistory/CurrentStatusRef = ('10', '11')]/Assignment/ResponsibleCoachRef)
};

declare function local:count-delta-evaluations-for( $coach-ref as xs:string, $after as xs:string?, $before as xs:string? ) as xs:decimal {
  sum(
    for $a in fn:collection($globals:projects-uri)//Activity[StatusHistory/CurrentStatusRef = ('10', '11')][Assignment/ResponsibleCoachRef eq $coach-ref]
    let $cur-status := $a/StatusHistory/CurrentStatusRef
    let $timestamp := $a/StatusHistory/Status[ValueRef eq $cur-status]/Date
    let $date := substring($timestamp, 1, 10)
    where     (empty($after) or ($date > $after))
          and (empty($before) or ($date < $before))
    return 1
  )
};

(: *** MAIN ENTRY POINT *** :)
let $envelope := oppidum:get-data()
let $errors := services:validate('cctracker', 'cctracker.feeds', $envelope)
return
  if (empty($errors)) then 
    let $payload := services:unmarshall($envelope)
    let $min := local:gen-min-date($payload/After)
    let $max := local:gen-max-date($payload/Before)
    return
      (: NOTE: guest don't have access to persons collection otherwise :)
      system:as-user(account:get-secret-user(), account:get-secret-password(),
        <Feeds>
          {
            if ($payload/@Format eq 'short') then
              ()
            else
              $payload/For,
            if ($payload/@Algorithm ne 'reset') then (
              $payload/Before,
              $payload/After
              ) 
            else 
              (),
            if ($payload/@Algorithm eq 'regenerate') then
              (: shows new feeds only or all feeds if count mismatch :)
              (: useful if user changes key or if empty timestamped feed has been stored before the key is available :)
              for $coach-key in $payload/For/*
              return local:regenerate-feed-for-coach-key($coach-key, $min, $max)
            else if ($payload/@Algorithm eq 'reset') then
              for $coach-key in $payload/For/*
              return local:reset-feed-for-coach-key($coach-key)
            else 
              for $coach-ref in local:gen-coach-refs-for-feeds($payload)
              return local:gen-feed-for-coach-ref($coach-ref, $min, $max)
          }
        </Feeds>
        )
  else
    $errors

xquery version "1.0";
(: ------------------------------------------------------------------
   CCMATCH - EIC Coach Match Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Updates all coach evaluation feeds invoking Case Tracker evaluation feeds web service
   Can be used for testing nightly job feeds/job.xql

   Parameters :
   - ?r=1-10 : specify a coach range by Ids
   - ?m=recompute | record : recompute existing feed (using formulas in feeds.xml) save them in addition (record)
   - ?m =request : dump the request that would be sent to Case Tracker web service (no call)
   - ?m=run : make Case Tracker feed request and update feeds [NOT IMPLEMENTED does a dry by default]
   - ?algo=regenerate | reset : specify feed algorithm (only for ?m=request | run)
    - without ?m does a dry run

   July 2016 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

import module namespace system = "http://exist-db.org/xquery/system";
import module namespace account = "http://oppidoc.com/ns/account" at "../modules/users/account.xqm";
import module namespace feeds = "http://oppidoc.com/ns/feeds" at "../modules/feeds/feeds.xqm";
import module namespace histories = "http://oppidoc.com/ns/histories" at "../lib/histories.xqm";

declare option exist:serialize "method=xml media-type=application/xml";

let $mode := request:get-parameter('m', ())
let $algo := request:get-parameter('algo', 'regenerate')
let $range := tokenize(request:get-parameter('r', ''), '-')
let $inf := if (exists($range)) then number($range[1]) else ()
let $sup := if (exists($range)) then number($range[2]) else ()
return
  if ($algo = ('reset', 'regenerate')) then
    system:as-user(account:get-secret-user(), account:get-secret-password(),
      if ($mode = ('recompute', 'record')) then
        <Recompute>
          {
          feeds:recompute-coach-feeds('1', (), (), $mode eq 'record')
          }
        </Recompute>
      else
        <Pull Inf="{ $inf }" Sup="{ $sup }"> 
          {
            let $done := 
              if ($mode eq 'request') then
                feeds:make-feed-requests ('1', $inf, $sup, $algo)/*
              else
                feeds:update-coach-feeds(
                  feeds:make-feed-requests ('1', $inf, $sup, $algo),
                  '1',
                  true()
                  (: FIXME: always dry mode :)
                )
            return
              if ($mode eq 'digest') then
                histories:archive-all('feeds', $done[local-name(.) eq 'error' or error or (ok = ('updated', 'replaced', 'reset'))])
              else
                $done
          }
        </Pull>
    )
  else
    <Pull Inf="{ $inf }" Sup="{ $sup }">Unknown algo "{ $algo }" use "regenerate" or "reset"</Pull>


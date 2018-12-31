xquery version "3.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Periodical TODO list computation

   FIXME: currently the period depends of a $freshness module variable
   and of the last time some user have called that functionality.
   This could be replaced by a trigger.

   May 2015 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace xdb = "http://exist-db.org/xquery/xmldb";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace search = "http://platinn.ch/coaching/search" at "../regions/search.xqm";
import module namespace check = "http://oppidoc.com/ns/cctracker/alert/check" at "check.xqm";

declare variable $freshness := "PT14400S";

(: ======================================================================
   Assert that $target-ref is a real KAM
   ======================================================================
:)
declare function local:is-kam($target-ref as xs:string) as xs:boolean {
  if (fn:collection($globals:persons-uri)//Person[Id eq $target-ref]) then
    count(fn:collection($globals:persons-uri)//Person[Id eq $target-ref]//Role[FunctionRef = '5']) > 0
  else
    false()
};

(: ======================================================================
   Assert that $boss-ref is a KAM coordinator of $target-ref
   ======================================================================
:)
declare function local:is-in-team($boss-ref as xs:string, $target-ref as xs:string) as xs:boolean {
  let $profile := fn:collection($globals:persons-uri)//Person[Id eq $boss-ref]
  return
    if ($profile//Role/FunctionRef = '3') then (: FIXME: hard-coded KAM Coordinator :)
      some $x in search:gen-linked-persons('kam', $profile//Role[FunctionRef eq '3']/RegionalEntityRef)
      satisfies $x/Id eq $target-ref
    else
      false()
};

(: ======================================================================
   FIXME: current limitation 1 Meet per Responsible per Check in cheks.xml
   ======================================================================
:)
declare function local:fetch-all ( $user-ref as xs:string?, $base as xs:string, $summarize as xs:string ) as element()* {
  let $profile := fn:collection($globals:persons-uri)//Person[Id eq $user-ref]
  return
    if ($user-ref) then
      element { if (not($summarize)) then 'Checks' else 'Summaries' }
      {
        attribute Hit { "1" },
        attribute User { display:gen-person-name($user-ref, 'en') },
        attribute Base { $base },
        attribute IsKC { number($profile//FunctionRef/text() = '3') },
        attribute Username { $profile//Username/text() },
        for $check in fn:doc(oppidum:path-to-config('checks.xml'))//Check[starts-with(Responsible/Meet, 'r')]
        let $cache-uri := concat('/db/sites/cctracker/checks/', $check/@No, '.xml')
        let $role := $check/Responsible/Meet[1]/text()
        let $suffix := substring-after($role, 'r:')
        (: where some $x in fn:doc($cache-uri)//ReRef satisfies $x eq $user-ref :)
        return
          if ($profile//FunctionRef[. eq access:get-function-ref-for-role($suffix)]) then
            (: since KC supervises KAM if KC is also KAM then KC is not summarized :)
            if ($suffix = $summarize or not($summarize)) then
              <Check>
              { fn:doc($cache-uri)/Check/@*[local-name(.) ne 'Total'] }
              {
              let $cases := fn:doc($cache-uri)//Project[.//ReRef eq $user-ref]
              return (
                attribute Total { count($cases) },
                $cases
              )
              }
              </Check>
            else
              ()
          else
            (),
        (: no <Checks><Summarizes><Summarizes>...</Checks> :)
        if (not($summarize) and $profile//RegionalEntityRef) then (: only roles with region can supervise :)
          let $dep-roles := check:get-roles-supervised-by($profile//FunctionRef)
          return
            for $fref in $profile//Role[FunctionRef eq '3'] (: FIXME: only handles KAM Coordinator Supervisor :)
            return 
              for $role in $dep-roles
              return
                for $p in search:gen-linked-persons($role, $fref/RegionalEntityRef)
                return local:fetch-all($p/Id, $base, $role)
        else
          ()
      }
    else
      element { if ($summarize) then 'Summaries' else 'Checks' }
      {
        attribute User { 'user Not Found' },
        attribute Base { $base }
      }
};

(: ======================================================================
   Returns cases for a given check target either reading it from cache
   or generating a new list that will update the cache too
   ======================================================================
:)
declare function local:fetch-cases( $target as xs:string ) as element()? {
  let $check := fn:doc(oppidum:path-to-config('checks.xml'))//Check[@No eq $target]
  return
    if ($check) then
      let $cached := fn:collection($globals:checks-uri)/Check[@No eq $target]
      return
        if ($cached and
            (current-dateTime() - xs:dateTime($cached/@Timestamp) < xs:dayTimeDuration($freshness))) then
          <Checks Hit="1" Base="../">
            { $cached }
          </Checks>
        else
          <Checks Base="../">
            { check:cache-update($check, check:check($check)) }
          </Checks>
    else
      oppidum:throw-error('URI-NOT-SUPPORTED', ())
};

let $cmd := oppidum:get-command()
let $target := string($cmd/resource/@name)
let $user-ref := access:get-current-person-id()
return
  if ($target eq 'alerts') then
    local:fetch-all($user-ref, "", "")
  else if (matches($target, "\d+")) then
    if (access:check-rule("g:admin-system g:coaching-assistant g:coaching-manager")) then
      local:fetch-cases($target)
    else
      oppidum:throw-error('UNAUTHORIZED-ACCESS', 'EASME coaching assistant or EASME coaching manager')
  else (: goodies : tries with EU login :)
    let $target-ref := fn:head(fn:collection($globals:persons-uri)//Person[UserProfile/Remote[@Name eq 'ECAS'] eq $target]/Id)
    return
      if ($target-ref) then
        let $is-a-boss := access:check-rule("g:admin-system g:coaching-assistant g:coaching-manager")
        let $target-is-kam := local:is-kam($target-ref)
        let $is-super :=
          if ($target-is-kam) then
            local:is-in-team($user-ref, $target-ref)
          else
            false()
        return
          if ($is-a-boss or ($user-ref = $target-ref) or $is-super) then
            local:fetch-all($target-ref, "../", "")
          else
            let $redir := oppidum:redirect(concat($cmd/@base-url, 'about'))
            return
              if (not($is-a-boss) and $target-is-kam and not($is-super)) then
                oppidum:throw-error('UNAUTHORIZED-ACCESS', 
                  concat('KAM coordinator of ', display:gen-person-name($target-ref, 'en'),
                         ' or EASME coaching assistant or EASME coaching manager')
                  )
              else if (not($is-a-boss)) then
                oppidum:throw-error('UNAUTHORIZED-ACCESS', 'EASME coaching assistant or EASME coaching manager')
              else
                oppidum:throw-error('NOT-KAM-COORDINATOR', display:gen-person-name($target-ref, 'en'))
      else 
        let $redir := oppidum:redirect(concat($cmd/@base-url, 'about'))
        return oppidum:throw-error('PERSON-NOT-FOUND',())

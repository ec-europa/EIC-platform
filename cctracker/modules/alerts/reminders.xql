xquery version "1.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Reminders CRUD controller

   Reminders should be configured to be nighlty computed by job.xql
   (see eXist-DB conf.xml)

   Pre-conditions : $globals:reminders-uri collection available
   and "rwu"-able for user executing this script

   February 2016 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace xdb = "http://exist-db.org/xquery/xmldb";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace check = "http://oppidoc.com/ns/cctracker/alert/check" at "check.xqm";

(: ======================================================================
   Returns Reminders for last two days
   Lazily computes, sends and archives reminders for the current date
   in case it has not been done (by nightly job)
   ======================================================================
:)
declare function local:fetch-reminders( $m as xs:string?, $nb as xs:string? ) as element()* {
  if ($m eq 'dry') then (: dry run no archival :)
    <Digest Timestamp="{ current-dateTime() }">
      {
      check:apply-reminders(
        for $check in fn:doc($globals:checks-config-uri)//Check
        where empty($nb) or ($nb eq '-1' and empty($check/@No)) or ($check/@No eq $nb)
        return check:reminders-for-check($check),
        false()
      )
      }
    </Digest>
  else
    let $today := check:get-reminders(current-dateTime())
    return (
      if ($today) then
        $today
      else
        check:archive-reminders(
          check:apply-reminders(
            for $check in fn:doc($globals:checks-config-uri)//Check
            return check:reminders-for-check($check)
          ),
          current-dateTime()
        ),
      check:get-reminders(current-dateTime() - xs:dayTimeDuration('P1D'))
    )
};

let $cmd := oppidum:get-command()
let $target := string($cmd/resource/@name)
let $m := request:get-parameter('m', ())
let $nb := request:get-parameter('nb', ())
return
  <Reminders Today="{ substring(string(current-dateTime()), 1, 10) }" Yesterday="{ substring(string(current-dateTime() - xs:dayTimeDuration('P1D')), 1, 10) }">
    {
    if ($target eq 'reminders') then
      local:fetch-reminders($m, $nb)
    else if (matches($target, "\d+")) then
      (: TODO: could return last N days :)
      ()
    else
      ()
    }
    <Dictionary>
    {
    for $m in fn:doc($globals:checks-config-uri)//Email
    return <Message Key="{ $m/Template }">{ $m/Description/text() }</Message>,
    for $m in fn:doc($globals:checks-config-uri)//Status
    return <Message Id="{ $m/Id }">{ $m/Description/text() }</Message>
    }
    </Dictionary>
  </Reminders>

xquery version "1.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Case creation

   November 2014 - (c) Copyright may be reserved
   ------------------------------------------------------------------ :)

module namespace cases = "http://oppidoc.fr/ns/ctracker/cases";
import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace compat = "http://oppidoc.com/oppidum/compatibility" at "../../oppidum/lib/compat.xqm";

(: ======================================================================
   Creates a new collection inside the home collection for Case collections
   Returns a pair : (new case collection URI, new case index)
   or the empty sequence in case of failure. Sets hard coded permissions.
   TODO: - factorize with case.xql
   ======================================================================
:)
declare function cases:create-case-collection( $date as xs:string ) as xs:string* {
  (: FIXME: use a @LastIndex scheme :)
  let $index :=
        if (fn:collection($globals:cases-uri)/Case/No) then (: bootstrap :)
          max(
            for $key in fn:collection($globals:cases-uri)/Case/No
            return if ($key castable as xs:integer) then number($key) else 0
            ) + 1
        else
          1
  return
    let $year := substring($date, 1, 4)
    let $month := substring($date, 6, 2)
    let $home-year-col-uri := concat($globals:cases-uri, '/', $year)
    let $home-col-uri := concat($home-year-col-uri, '/', $month)
    return (
      (: Lazy creation of home collection with YEAR :)
      if (not(xdb:collection-available($home-year-col-uri))) then
        if (xdb:create-collection($globals:cases-uri, $year)) then
          compat:set-owner-group-permissions($home-year-col-uri, 'admin', 'users', "rwxrwxr-x")
        else
         ()
      else
        (),
      (: Lazy creation of home collection with MONTH :)
      if (not(xdb:collection-available($home-col-uri))) then
        if (xdb:create-collection($home-year-col-uri, $month)) then
          compat:set-owner-group-permissions($home-col-uri, 'admin', 'users', "rwxrwxr-x")
        else
         ()
      else
        (),
      (: Case collection creation :)
      let $col-uri := concat($home-col-uri, '/', $index)
      return
        if (not(xdb:collection-available($col-uri))) then
          if (xdb:create-collection($home-col-uri, string($index))) then
            let $perms := compat:set-owner-group-permissions($col-uri, 'admin', 'users', "rwxrwxr-x")
            return
              ($col-uri, string($index))
          else
            ()
        else
          ($col-uri, string($index))
      )
};


declare function cases:create-project-collection( $date as xs:string, $id as xs:string ) as xs:string* {
  let $year := substring($date, 7, 4)
  let $month := substring($date, 4, 2)
  let $home-year-col-uri := concat($globals:projects-uri, '/', $year)
  let $home-col-uri := concat($home-year-col-uri, '/', $month)
  return (
    (: Lazy creation of home collection with YEAR :)
    if (not(xdb:collection-available($home-year-col-uri))) then
      if (xdb:create-collection($globals:projects-uri, $year)) then
        xdb:set-collection-permissions($home-year-col-uri, 'admin', 'users', util:base-to-integer(0774, 8))
      else
       ()
    else
      (),
    (: Lazy creation of home collection with MONTH :)
    if (not(xdb:collection-available($home-col-uri))) then
      if (xdb:create-collection($home-year-col-uri, $month)) then
        xdb:set-collection-permissions($home-col-uri, 'admin', 'users', util:base-to-integer(0774, 8))
      else
       ()
    else
      (),
    (: Case collection creation :)
    let $col-uri := concat($home-col-uri, '/', $id)
    return
      if (not(xdb:collection-available($col-uri))) then
        if (xdb:create-collection($home-col-uri, string($id))) then
          let $perms := xdb:set-collection-permissions($col-uri, 'admin', 'users', util:base-to-integer(0774, 8))
          return
            ($col-uri, string($id))
        else
          ()
      else
        ($col-uri, string($id))
    )
};

(: ======================================================================
   ======================================================================
:)
declare function cases:gen-case-for-viewing( $project as element(), $case as element(), $lang as xs:string ) {
  <Case>
    {(
    $case/No,
    <Beneficiary>
    {
    let $b := $project/Information/Beneficiaries/(Coordinator | Partner)[PIC eq $case/PIC]
    return
      if ($b) then
        concat($b/ShortName/text(), ' (', $b/ContactPerson//FirstName, ' ',$b/ContactPerson//LastName ,')')
      else
        'Not selected yet'
    }
    </Beneficiary>,
    <ManagingEntity>{display:gen-name-for-regional-entities( $case/ManagingEntity/RegionalEntityRef, $lang ) }</ManagingEntity>,
    <ResponsibleKAM>{display:gen-person-name($case/Management/AccountManagerRef/text(), $lang)}</ResponsibleKAM>,
    <CreationDate>{display:gen-display-date( $project/StatusHistory/Status[ValueRef eq '1']/Date/text(), $lang)}</CreationDate>,
    <Status>{display:gen-workflow-status-name('Case', $case/StatusHistory/CurrentStatusRef/text(), $lang)}</Status>,
    let $activities := $case//Activity/No
    return
      <LinkedActivities Count="{count($activities)}">{$activities}</LinkedActivities>
    )}
  </Case>
};

(: ======================================================================
   Returns the list of activities to display in case workflow view
   ======================================================================
:) 
declare function cases:gen-cases-for-project( $project as element()?, $lang as xs:string ) as element()* {
  for $case in $project/Cases/Case
  return cases:gen-case-for-viewing( $project, $case, $lang)
};

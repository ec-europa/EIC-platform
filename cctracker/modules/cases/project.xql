xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>
   XML protocol

   <Export><Ask [What=XPATH]></Export> :

   Ex: <Export><Ask What="Contract/Date[. eq '']"/></Export>
   (using CASE-TRACKER-KEY)

   April 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";
declare namespace request = "http://exist-db.org/xquery/request";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace services = "http://oppidoc.com/ns/services" at "../../lib/services.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace account = "http://platinn.ch/coaching/account" at "../users/account.xqm";
import module namespace cases = "http://oppidoc.fr/ns/ctracker/cases" at "../cases/case.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";
import module namespace database = "http://oppidoc.com/ns/database" at "../../../excm/lib/database.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

declare function local:register-officer( $person as element()? ) as xs:string {
  if ($person) then
    let $officer := fn:collection($globals:persons-uri)//Person[(UserProfile/Remote, @PersonId) = $person/UserProfile/Remote][1]
    return
      if ($officer) then
        $officer/Id
      else
        let $pid := max(
            for $key in fn:collection($globals:persons-uri)//Person/Id
            return if ($key castable as xs:integer) then number($key) else 0
            ) + 1
        return
          let $ro :=<Person><Id>{ $pid }</Id>{ $person/* }</Person>
          let $col := misc:gen-collection-name-for($pid)
          let $fn := concat($pid, '.xml')
          let $col-uri := database:create-collection-lazy-for($globals:persons-uri, $col, 'person')
          let $stored-path := xdb:store($col-uri, $fn, $person)
          return 
            if (not($stored-path eq ())) then
              (database:apply-policy-for($col-uri, $fn, 'Person'), $pid)[last()]
            else
              '-1'
  else
    '-1'
};

(: ======================================================================
   Returns Case sample
   ======================================================================
:)
declare function local:gen-case-sample( $p as element() ) as element() {
  <ProjectId>{ string($p/Id) }</ProjectId>
};

declare function local:insert-project( $project as element() ) as element() {
  let $datecall := collection('/db/sites/cctracker/global-information')//Selector[@Name = ('SMEiCalls','FETCalls', 'FTICalls')]//Name[../Code = $project/Information/Call/(SMEiCallRef | FETCallRef | FTICallRef)]
  let $project-refs := cases:create-project-collection($datecall, $project/Id)
  let $project-uri := $project-refs[1]
  let $tostore :=
    <Project>
      { $project/( Id | CreationDate | StatusHistory) }
      <Information>
        { $project/Information/*[not(local-name(.) = ('ProjectOfficerRef','BackupProjectOfficerRef'))] }
        <ProjectOfficerRef>{ local:register-officer($project/Information/ProjectOfficerRef/Person) }</ProjectOfficerRef>
        <BackupProjectOfficerRef>{ local:register-officer($project/Information/BackupProjectOfficerRef/Person) }</BackupProjectOfficerRef>
      </Information>
    </Project>
  return
    if (not(empty($project-refs))) then
      let $stored-path := xdb:store($project-uri, "project.xml", $tostore)
      return
        let $succ :=
          if(not($stored-path eq ())) then
          (
            system:as-user(account:get-secret-user(), account:get-secret-password(), xdb:set-resource-permissions($project-uri, "project.xml", 'admin', 'users', util:base-to-integer(0774, 8))),
            'Created'
          )[last()]
          else
            'Failed'
        return
          element { $succ }
          {
            element Ac { $project/Acronym/text() },
            element ProjectId { string($project/Id) },
            element CaseURI { $project-uri }
          }
    else
      element FailedColl
      {
        element Ac { $project/Acronym/text() },
        element ProjectId { string($project/Id) },
        element CaseURI { $project-uri }
      }
};


(: *** MAIN ENTRY POINT *** :)
let $submitted := oppidum:get-data()
let $errors := services:validate('cctracker', 'cctracker.projects', $submitted)
return
  if (empty($errors)) then
    let $search := services:unmarshall($submitted)
    return
      (:1. query stuff to be updated :)
      if ($search/Ask) then
        let $what := if ($search/Ask/@What) then string($search/Ask/@What) else ()
        return
          if ($what) then
            <Batch>
            {
            let $results := util:eval(concat("fn:collection($globals:projects-uri)//Project[",$what,']'))
            return
              (
              attribute Count { count($results) },
              for $case in $results
              return local:gen-case-sample($case)
              )
            }
            </Batch>
          else
            <Batch/>
      else if ($search/Batch) then
      (:2. results pushed :)
        <Results>
        {
        for $action in $search/Batch/*
        return
          system:as-user(account:get-secret-user(), account:get-secret-password(),
          (
          if (local-name($action) eq 'CreateDocument' and $action/Project) then
            let $exists := collection('/db/sites/cctracker/projects')//Project[Id eq $action/Project/Id]
            return
              if ($exists) then
                <Exists Id="{$exists/Id}"/>
              else 
                local:insert-project( $action/Project )
          else
            ()
          ))
        }
        </Results>
      else
        ()
  else
    $errors

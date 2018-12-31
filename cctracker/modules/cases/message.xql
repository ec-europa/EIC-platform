xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   <Export><Message><Tag1/>..<TagN/></Message></Export> :

----------------------------------------------- :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";
declare namespace request = "http://exist-db.org/xquery/request";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace services = "http://oppidoc.com/ns/services" at "../../lib/services.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace account = "http://platinn.ch/coaching/account" at "../users/account.xqm";
import module namespace database = "http://oppidoc.com/ns/database" at "../../../excm/lib/database.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

declare function local:register-officer( $person as element()? ) as xs:string {
  if ($person) then
    let $officer := fn:collection($globals:persons-uri)//Person[(UserProfile/Remote, @PersonId) = $person/UserProfile/Remote][1]
    return
      if ($officer) then
        $officer/Id
      else
        let $newkey := max(
            for $key in fn:collection($globals:persons-uri)//Person/Id
            return if ($key castable as xs:integer) then number($key) else 0
            ) + 1
        let $newPerson := <Person><Id>{ $newkey }</Id>{ $person/* }</Person>
        let $col := misc:gen-collection-name-for($newkey)
        let $fn := concat($newkey, '.xml')
        let $col-uri := database:create-collection-lazy-for($globals:persons-uri, $col, 'person')
        let $stored-path := xdb:store($col-uri, $fn, $newPerson)
        return
          (
            if (not($stored-path eq ())) then
              database:apply-policy-for($col-uri, $fn, 'Person')
            else
              (),
            string($newkey)
          )[last()]
  else
    '-1'
};

declare function local:init( $parent as element(), $name as xs:string ) as element()* {
  if ($parent/*[local-name(.) eq $name]) then
    ()
  else
    update insert element { $name } {()} into $parent
};

declare function local:update( $parent as element(), $legacy as element()?, $new as element()? ) as element()* {
  if ($new) then
    if ($legacy) then
      update replace $legacy with $new
    else
      update insert $new into $parent
  else
    ()
};

(: *** MAIN ENTRY POINT *** :)
let $submitted := oppidum:get-data()
let $errors := services:validate('cctracker', 'cctracker.messages', $submitted)
return
  if (empty($errors)) then
    let $search := services:unmarshall($submitted)
    return
      if ($search/Message) then
        <Results>
        {
        let $message := $search/Message
        return
          if ($message) then
            let $project := fn:collection($globals:projects-uri)//Project[Id eq $message/@Project]
            return
              if ($project) then
                system:as-user(account:get-secret-user(), account:get-secret-password(),
                (
                  for $e in $message/element()
                  return
                    if (local-name($e) eq 'ProjectOfficer') then
                      let $init := local:update( $project/Information, $project/Information/ProjectOfficerRef, <ProjectOfficerRef/> )
                      let $ref := local:register-officer($e)
                      return
                        (
                        update value $project/Information/ProjectOfficerRef with $ref,
                        <Applied>{ $project/Id, $e }</Applied>
                        )
                    else if (local-name($e) eq 'BackupProjectOfficer') then
                      let $init := local:update( $project/Information, $project/Information/BackupProjectOfficerRef, <BackupProjectOfficerRef/> )
                      let $ref := local:register-officer($e)
                      return
                        (
                        update value $project/Information/BackupProjectOfficerRef with $ref,
                        <Applied>{ $project/Id, $e }</Applied>
                        )
                    else if (local-name($e) eq 'GrantAgreementPreparationRef') then
                      let $sign := $e[text() eq '6']
                      return
                        if ($sign) then
                          let $init := local:init( $project/Information, 'Contract')
                          return
                            let $update := local:update( $project/Information/Contract, $project/Information/Contract/Date, <Date>{ string($e/@TS) }</Date>)
                            return <Applied>{ $project/Id, $e }</Applied>
                        else
                          ()
                    else if (local-name($e) eq 'ProjectStartDate') then
                      let $init := local:init( $project/Information, 'Contract')
                      return
                        let $update := local:update( $project/Information/Contract, $project/Information/Contract/Start, <Start>{ $e/text() }</Start>)
                        return <Applied>{ $project/Id, $e }</Applied>
                    else if (local-name($e) eq 'ProjectDuration') then
                      let $init := local:init( $project/Information, 'Contract')
                      return
                        let $update := local:update( $project/Information/Contract, $project/Information/Contract/Duration, <Duration>{ $e/text() }</Duration>)
                        return <Applied>{ $project/Id, $e }</Applied>
                    else
                      ()
                ))
              else
                <UnknownProject>{ string($message/@Project) }</UnknownProject>
          else
            <NoMessage/>
        }
        </Results>
      else
        ()
  else
    $errors

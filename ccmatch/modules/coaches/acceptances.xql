xquery version "1.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Controller for coach acceptance status and comments per host

   Implement protocols :

   - coach application : Ajax XML Oppidum success / error
   - host manager status change : Ajax XML custom protocol 
     on success returns : 
        <Result>
          <New> : new acceptance status
          <Id> : coach ID
     on error throws Oppidum error
   - post comments : Ajax JSON table protocol

   December 2015 - (c) Copyright may be reserved
   ----------------------------------------------- :)

declare namespace request = "http://exist-db.org/xquery/request";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace misc = "http://oppidoc.com/ns/misc" at "../../lib/util.xqm";
import module namespace person = "http://oppidoc.com/ns/ccmatch/person" at "../../lib/person.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Silently (no throw-message) saves (replace or update) new content into legacy one
   ====================================================================== 
:)
declare function local:save-content-silent( $parent as element(), $legacy as element()?, $new as element()? ) as element()* {
  if ($new) then
    if ($legacy) then
      update replace $legacy with $new
    else
      update insert $new into $parent
  else
    ()
};

(: ======================================================================
   Applies for acceptance for a given host reference
   Hard-coded application status "Submitted" (1)
   Pre-condition: $host-ref exists 
   Note: coded so that Host can contain only AccreditationRef
   ====================================================================== 
:)
declare function local:apply( $host-ref as xs:string, $host-name as xs:string, $person as element() ) {
  if ($person//Host[@For eq $host-ref]) then (: unlikely :)
    oppidum:throw-error('APPLICATION-ALREADY-SUBMITTED', ())
  else if ((count($person//CV-File) = 0 and not($person//CV-Link)) or empty($person/CurriculumVitae/Summary/text())) then
    oppidum:throw-error('APPLICATION-MISSING-DATA', ())
  else
    let $date := string(current-dateTime())
    let $data := <Host For="{ $host-ref }">
                   <AccreditationRef Date="{ $date }">1</AccreditationRef>
                 </Host>
    let $hosts := $person/Hosts
    return (
      if ($hosts) then 
        update insert $data into $hosts
      else 
        update insert <Hosts>{ $data }</Hosts> into $person,
      let $status := display:gen-name-for('Acceptances', $data/AccreditationRef, 'en')
      return
        ajax:report-success('ACTION-APPLICATION-SUCCESS', $host-name, 
          concat($status, ' on ', display:gen-display-date($date, 'en'), 
                  ' at ', substring($date, 12, 2),':', substring($date, 15, 2)))
      )
};

(: ======================================================================
   Updates acceptance status, working rank ref and contact person
   Invariant: WorkingRankRef = '1' (activated) implies coach is accepted
   (see also match:assert-coach in match.xqm)
   Pre-condition: authorized user !
   FIXME: we need a real workflow here ?
   ====================================================================== 
:)
declare function local:update( $host-ref as xs:string, $submitted as element()? )  {
  let $person := fn:collection($globals:persons-uri)//Person[Id =  $submitted/CoachRef]
  return
    if ($person) then
      let $d := string(current-dateTime())
      let $host := $person/Hosts/Host[@For eq $host-ref]
      return (
        (: 1. updates AccreditationRef :)
        if ($submitted/AccreditationRef) then
          local:save-content-silent($host, $host/AccreditationRef, <AccreditationRef Date="{$d}">{ $submitted/AccreditationRef/text()}</AccreditationRef>)
        else (: wrong submission, don't change :)
          (),
        (: 2. updates ContactRef :)
        if ($submitted/ContactRef) then
          local:save-content-silent($host, $host/ContactRef, <ContactRef Date="{$d}">{ $submitted/ContactRef/text()}</ContactRef>)
        else
          update delete $host/ContactRef,
        (: 3. updates WorkingRankRef :)
        if ($submitted/AccreditationRef eq '4') then
          let $wr := if ($submitted/WorkingRankRef) then $submitted/WorkingRankRef/text() else '1'
          return
            local:save-content-silent($host, $host/WorkingRankRef, 
              <WorkingRankRef Date="{$d}">{ $wr }</WorkingRankRef>)
        else if ($host/WorkingRankRef) then
          update delete $host/WorkingRankRef
        else
          (),
        <Result> (: Ajax custom protocol :)
          <New>{ $submitted/AccreditationRef/text() }</New>
          <Id>{ $submitted/CoachRef/text() }</Id>
        </Result>
        )[last()]
    else
      oppidum:throw-error('COACH-NOT-FOUND', ())
};

declare function local:comments( $host-ref as xs:string, $submitted as element()?, $uid as xs:string , $actor-id as xs:string, $action as xs:string )  {
  let $person := fn:collection($globals:persons-uri)//Person[Id =  $uid or $uid = (UserProfile/Username, UserProfile/Remote)]
  let $host := $person/Hosts/Host[@For eq $host-ref]
  return
    if ($person) then
      if ($action = 'GET') then
        let $notes := $host/ManagerNotes
        return
          if (empty($notes)) then
            <ManagerNotes/>
          else
            <ManagerNotes>
            {
            $notes/*[not(local-name(.) = 'LastChangesByRef')],
            <LastChangesByRef _Display="{ display:gen-person-name-for-ref($notes/LastChangesByRef, 'en')}">{$notes/LastChangesByRef/text() }</LastChangesByRef>
            }
            </ManagerNotes>
      else (: assumes POST :)
        let $data :=
          <ManagerNotes>
          {
          $submitted/*[not(local-name(.) = 'LastChangesByRef')],
          <LastChangesByRef>{ $actor-id }</LastChangesByRef>
          }
          </ManagerNotes>
        return (
          local:save-content-silent($host, $host/ManagerNotes, $data),
          let $result :=
            (
            <Table>{ request:get-parameter('table', ()) }</Table>,
            <Action>update</Action>, 
            <Users>{ person:gen-coach-sample-for-mgt-table($person, $host-ref) }</Users>
            )
          return ajax:report-success-json('ACTION-UPDATE-SUCCESS', (), $result)
          )
            
    else
      oppidum:throw-error('COACH-NOT-FOUND', ())
};

let $m := request:get-method()
let $cmd := request:get-attribute('oppidum.command')
let $action := string($cmd/@action)
let $groups := oppidum:get-current-user-groups()
let $tokens := tokenize($cmd/@trail, '/')
let $uid := $tokens[1]
let $host-ref := $tokens[3]
let $item := $tokens[4]
let $profile := access:get-current-person-profile()
let $person := $profile/ancestor::Person
let $user := access:get-current-person-id()
return
  if ($profile) then
    let $host := fn:collection($globals:global-info-uri)//Description[@Lang = 'en']//Selector[@Name eq 'Hosts']/Option[Id eq $host-ref]
    return
      if ($host and ($m eq 'POST')) then
        if ($action eq 'apply') then (: assumes <Apply/> :)
          if ($uid eq $user) then 
            (: access control : only someone can apply for himself should we allow admin system or host manager too ? :)
            local:apply($host-ref, $host/Name, $person)
          else
            oppidum:throw-error('FORBIDDEN', ())
        else if ($action eq 'update') then (: assumes <Update/> :)
          if ($profile//Role[FunctionRef eq '2'][HostRef eq $host-ref] or ($groups = ('admin-system'))) then 
            let $submitted := oppidum:get-data() (: FIXME: validate $submitted :)
            return
              local:update($host-ref, $submitted)
          else
            oppidum:throw-error('CUSTOM', $groups)
        else if ($item eq 'comments' and $groups = ('admin-system')) then
          let $submitted := oppidum:get-data() (: FIXME: validate $submitted :)
          return
            local:comments($host-ref, $submitted, $uid, $person/Id, $action)
        else
          oppidum:throw-error('URI-NOT-FOUND', ())
      else if ($item eq 'comments' and $groups = ('admin-system')) then
        local:comments($host-ref, (), $uid, '-1', $action)
      else
        oppidum:throw-error('URI-NOT-FOUND', ())
  else
    oppidum:throw-error('FORBIDDEN', ())

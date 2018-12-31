xquery version "1.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Low-level person model in/out from database

   FIXME: move save-facet to misc and person:create in users/user.xql ?

   September 2015 - European Union Public Licence EUPL
   ----------------------------------------------- :)

module namespace person = "http://oppidoc.com/ns/ccmatch/person";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../oppidum/lib/util.xqm";
import module namespace compat = "http://oppidoc.com/oppidum/compatibility" at "../../oppidum/lib/compat.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "globals.xqm";
import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace misc = "http://oppidoc.com/ns/misc" at "util.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "ajax.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: declaration of binary resources potentially attached to a person :)
declare variable $person:resources := 
  <Resources>
    <Element Name="Information" Resource="Photo"/>
    <Element Name="Knowledge" Resource="CV-File"/>
  </Resources>;

(: ======================================================================
   Apply filters to an input tree
   ====================================================================== 
:)
declare function person:filter-with( $source as element(), $filters as element() ) {
  let $f := $filters/Element[@Name eq local-name($source)]
  return
    if ($f) then
      misc:filter($source, $f/@Resource)
    else 
      $source
};

(: ======================================================================
   Generates Login and Access elements for management results table
   ====================================================================== 
:)
declare function person:gen-access( $username as element()? ) {
  if ($username and ($username ne '')) then (
    <Login>{ $username/text() }</Login>,
    if (xdb:exists-user($username)) then
      <Access>1</Access>
    else
      ()
    )
  else 
    ()
};

(: ======================================================================
   Switch function to generate JSON-compatible user model to update a row
   in a 'user' or 'import' table depending on request's table parameter
   ====================================================================== 
:)
declare function person:gen-update-sample-for-mgt-table( $p as element() ) as element()* {
  let $table := request:get-parameter('table', 'user')
  return
    if ($table eq 'user') then
      person:gen-user-sample-for-mgt-table($p, 'update') 
    else
      let $persists := request:get-parameter('persists', ())
      return person:gen-import-sample-for-mgt-table($p, $persists)
};

(: ======================================================================
   Encodes JSON-oriented user model to display in management results list
   ====================================================================== 
:)
declare function person:gen-user-sample-for-mgt-table( $p as element(), $goal as xs:string? ) as element()* {
  let $login := $p/UserProfile/Username
  let $name := $p/Information/Name
  return
    (
    <Table>user</Table>,
    if ($goal) then <Action>{ $goal }</Action> else (),
    <Users>
      {
      $p/Id,
      if ($name/*) then $name else (),
      person:gen-access($login),
      if ($p/UserProfile/Roles/Role[FunctionRef eq "1"]) then
        <Admin>1</Admin>
      else 
        ()
      }
    </Users>
    )
};

(: ======================================================================
   Returns JSON-oriented user model to display in import results list. 
   The remote login must be passed in request persists parameter to allow 
   reconstruction without invoking the remote Case Tracker
   Always called in Ajax request resulting in a row update 
   ====================================================================== 
:)
declare function person:gen-import-sample-for-mgt-table( $peer as element(), $remote-login as xs:string? ) as element()* {
  let $name := $peer/Information/Name
  return
    (
    <Table>import</Table>,
    <Action>update</Action>,
    <Users>
      {
      $peer/Id,
      if ($name) then
        <Name>{ concat($name/LastName, ' ', $name/FirstName) }</Name>
      else
        (),
      person:gen-access($peer//Username),
      if ($remote-login) then <RemoteLogin>{ $remote-login }</RemoteLogin> else (),
      $peer/Information/Contacts/Email
      }
    </Users>
    )
};

(: ======================================================================
   Returns sequence of coach elements suitable for generating a coach row 
   in a coach management tables (see also cm-coaches.js)
   ====================================================================== 
:)
declare function person:gen-coach-sample-for-mgt-table( $coach as element(), $host-ref as xs:string ) as element()* {
  let $host := $coach//Host[@For = $host-ref]
  return (
    <AccDate>{string($host/AccreditationRef/@Date)}</AccDate>,
    <WorkDate>{string($host/WorkingRankRef/@Date)}</WorkDate>,
    $coach/Id,
    $coach/Information/Name,
    <HostStatus>{$host/AccreditationRef/text()}</HostStatus>,
    if ($host/ManagerNotes) then
      <Notes>1</Notes>
    else
      (),
    <WorkingStatus>{$host/WorkingRankRef/text()}</WorkingStatus>,
    <Contact>{$host/ContactRef/text()}</Contact>
    )
};

(: ======================================================================
   Creates or update a person's facet
   Removes person's facet if the new facet is empty
   ====================================================================== 
:)
declare function person:save-facet( $parent as element(), $legacy as element()?, $new as element()? )
{
  if ($new) then
    let $data := person:filter-with($new, $person:resources)
    return
      if ($legacy) then
        update replace $legacy with $data
      else
        update insert $data into $parent
  else
    if ($legacy) then
      update delete $legacy
    else
      ()
};

(: ======================================================================
   Injects Photo resource into person information model 
   ====================================================================== 
:)
declare function person:gen-information( $person as element() ) {
  if ($person/Resources/Photo) then
    <Information>
      {
      <Photo>{ $person/Resources/Photo/text() }</Photo>,
      $person/Information/*
    }
    </Information>
  else
    $person/Information
};

(: ======================================================================
   Returns external login information
   ====================================================================== 
:)
declare function person:gen-external-login( $person as element() ) {
  <External>
    <Remote>{$person/UserProfile/Remote[@Name = 'ECAS']/text()}</Remote>
    <Realm>{string($person/UserProfile/Remote/@Name)}</Realm>
  </External>
};

(: ======================================================================
   Move person's status to next status
   A reflexive call means status is updated by the end-user
   ====================================================================== 
:)
declare function person:goto-next-status( $person as element(), $reflexive as xs:boolean? ) {
  let $history := $person/StatusHistory
  let $previous := $history/PreviousStatusRef
  let $current := $history/CurrentStatusRef
  return
    if ($history) then
      let $new-status :=
        if ($current) then (: created :)
          if ($reflexive) then '4' else '3' (: (self-)deleted :) (: note that deletion by admin not yet implemented :)
        else
          if ($reflexive) then '2' else '1' (: (self-)created :)
      return
        let $prev := 
          if ($previous) then 
            update value $previous with $current/text()
          else
            update insert <PreviousStatusRef>{ $current/text() }</PreviousStatusRef> following $current
          return 
            (
            if ($current) then
              update value $current with $new-status
            else
              update insert <CurrentStatusRef>{ $new-status }</CurrentStatusRef> into $history,
            update insert <Status><Date>{ substring(string(current-date()),1,10) }</Date><ValueRef>{ $new-status }</ValueRef></Status> into $history
            )
    else
      ()
};

(: ======================================================================
   Physical person creation into database
   ====================================================================== 
:)
declare function person:create ( 
  $id as xs:double, 
  $facets as element()*
  ) as xs:string?
{
  let $new-person := 
    <Person Creation="{current-dateTime()}">
      <Id>{ $id }</Id>
      <StatusHistory/>
      { $facets }
    </Person>
  return
    let $col := misc:gen-collection-name-for($id)
    let $fn := concat($id, '.xml') 
    let $col-uri := misc:create-collection-lazy ($globals:persons-uri, $col, 'admin', 'users', 'rwxrwxr-x')
    let $stored-path := xdb:store($col-uri, $fn, $new-person)
    return 
      (
      if (not($stored-path eq ())) then
        compat:set-owner-group-permissions(concat($col-uri, '/', $fn), 'admin', 'users', 'rwxrwxr--')
      else
        (),
      $stored-path
      )[last()]
};

(: ======================================================================
   Adds a new person to the database by creating person's collection 
   and person's file initialized with optional facets. Persons can 
   be directly created as users if optional username is provided.

   FIXME : use misc:increment-variable($person-counter-name)
   ====================================================================== 
:)
declare function person:create ( 
  $username as xs:string?, 
  $facets as element()*,
  $redirect as xs:string?
  ) as element()?
{
  let $new-key := 
    if (fn:collection($globals:persons-uri)//Person/Id) then
      max(
        for $key in fn:collection($globals:persons-uri)//Person/Id
        return if ($key castable as xs:integer) then number($key) else 0
        ) + 1
    else
      1
  let $profile := 
      if ($username) then
        <UserProfile>
          <Username>{ $username }</Username>
        </UserProfile>
      else
        ()
  let $stored-path := person:create($new-key, ($profile, $facets))
  return
    if (not($stored-path eq ())) then (
      if ($redirect) then
        ajax:report-success-redirect('ACTION-CREATE-SUCCESS', (), $redirect)
      else
        <path>{ $stored-path }</path>
      )
    else
      oppidum:throw-error('CUSTOM', 'Internal error while saving data, please retry')
};

(: ======================================================================
   Generates and returns inital XML model to start logging profile updates
   ====================================================================== 
:)
declare function person:gen-initial-log-entries( $categories as xs:string* ) as element() {
  let $ts := current-dateTime()
  return
    <Logs>
      {
      for $c in $categories
      return
        <Log>
          <Category>{ $c }</Category>
          <Date>{ $ts }</Date>
        </Log>
      }
    </Logs>
};

(: ======================================================================
   Updates Logs timestamp for a given category
   ====================================================================== 
:)
declare function person:update-log-entry( $person as element(), $category as xs:string ) {
  if ($person/Logs) then
    let $legacy := $person/Logs/Log[Category eq $category]
    let $ts := current-dateTime()
    let $log := 
      <Log>
        <Category>{ $category }</Category>
        <Date>{ $ts }</Date>
      </Log>
    return
      if ($legacy) then
        update replace $legacy with $log
      else
        update insert $log into $person/Logs 
  else (: lazy creation - :)
    let $logs := person:gen-initial-log-entries(('creation', $category))
    return 
      update insert $logs into $person
};

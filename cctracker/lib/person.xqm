xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Low-level person model in/out from database

   FIXME: move save-facet to misc and person:create in users/user.xql ?

   September 2015 - European Union Public Licence EUPL
   ----------------------------------------------- :)

module namespace person = "http://oppidoc.com/ns/ccmatch/person";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "globals.xqm";
import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "util.xqm";
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
    if (sm:user-exists($username)) then
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
  let $name := $p/Name
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
  let $name := $peer/Name
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
      $peer/Contacts/Email
      }
    </Users>
    )
};

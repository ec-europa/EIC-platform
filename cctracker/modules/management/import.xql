xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Authors: 
   - Stéphane Sire <s.sire@oppidoc.fr>
   - Frédéric Dumonceau <Frederic.DUMONCEAUX@ext.ec.europa.eu>

   Calls Coach Match export service to retrieve list of coaches
   Aligns with coaches in Case Tracker and returns data structure to manage users
   (i.e. import user's profile or import user's login)

   Use with ?profile={key} for fetching single profile
   Use with ?letter={letter} for fetching a list of coaches

   October 2015 - European Union Public Licence EUPL
   ----------------------------------------------- :)

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace services = "http://oppidoc.com/ns/services" at "../../lib/services.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";

declare option exist:serialize "method=json media-type=application/json";

(: FIXME: canonize E-mail (?):)
declare function local:normalize-email( $email as xs:string? ) as xs:string? {
  normalize-space($email)
};

(: ======================================================================
   Builds import table results row for a given remote coach and optional peer
   See also lib/persons.xqm
   ====================================================================== 
:)
declare function local:gen-import-sample-for-mgt-table( $remote as element(), $peer as element()? ) as element()* {
  let $name := $remote/Name
  return
    <Users>
      {
      $peer/Id,
      if ($name) then
        <Name>{ concat($name/LastName, ' ', $name/FirstName) }</Name>
      else
        (),
      $remote/Email,
      <AcceptanceStatus>{ string-join(display:gen-name-for('AcceptancesCCMatch', $remote/AccreditationRef, 'en'),", ") }</AcceptanceStatus>,
      <WorkingStatus>{ string-join(display:gen-name-for('WorkingRanksCCMatch', $remote/WorkingRankRef, 'en'),", ") }</WorkingStatus>,
      <Availability>{ string-join(display:gen-name-for('YesNoAvailsCCMatch', $remote/YesNoAvailRef, 'en'),", ") }</Availability>
      }
    </Users>
};

(: ======================================================================
   Note that it returns either a Login element if the user already 
   has a login in Coach match, or a NoLogin element telling if the 
   Case Tracker login can be reused (available, taken or none)

   FIXME: optimize with an Email index (but then Email should be normalized 
   when writing profile into database ?)
   ====================================================================== 
:)
declare function local:align-coaches( $coaches as element()* ) as element()* {
  for $c in $coaches
  let $email := local:normalize-email($c/Email)
  let $peer := 
    if ($email) then 
      fn:collection($globals:persons-uri)//Person[local:normalize-email(Contacts/Email) eq $email]
    else
      ()
  return
    (: FIXME: drop coach if Email can be found in pre-registered Remote/Key in remotes.xml :)
    local:gen-import-sample-for-mgt-table($c, $peer[1]) (: robust: takes 1st if several :)
};

(: ======================================================================
   Converts imported coach profile information into profile information
   model for editing
   FIXME: shall we keep sort string ?
   ====================================================================== 
:)
declare function local:gen-coach-for-editing( $imported as element() ) {
  <Person>
    { 
    $imported/(Sex | Civility | Name | Contacts | AccreditationRef | WorkingRankRef | YesNoAvailRef),    
    if ($imported/Country) then
      <Address>{ $imported/Country }</Address>
    else
      (),
    <External><Remote>{ $imported/Remote/text() }</Remote><Realm>{ string($imported/Remote/@Name) }</Realm></External>,
    <AcceptanceStatus>{ string-join(display:gen-name-for('Acceptances', $imported/AccreditationRef, 'en'),", ") }</AcceptanceStatus>,
    <WorkingStatus>{ string-join(display:gen-name-for('WorkingRanks', $imported/WorkingRankRef, 'en'),", ") }</WorkingStatus>,
    <Availability>{ string-join(display:gen-name-for('YesNoAvails', $imported/YesNoAvailRef, 'en'),", ") }</Availability>
    }
  </Person>
};

(: MAIN ENTRY POINT : eventually this script could be splitted ! :)
let $profile := request:get-parameter('profile', ())
return
  (: 1. Imports a single coach profile identified by e-mail from remote service :)
  if ($profile) then 
    let $payload := <Export Format="profile"><Email>{ normalize-space($profile) }</Email></Export>
    let $coaches := services:post-to-service('ccmatch-public', 'ccmatch.export', $payload, "200")
    return
      if (local-name($coaches) ne 'error') then
        if (exists($coaches//Coach)) then (
          local:gen-coach-for-editing($coaches//Coach[1]),
          util:declare-option("exist:serialize", "method=xml media-type=text/xml")
          )
        else
          oppidum:throw-error('CUSTOM', concat('No user could be imported from case tracker with e-mail address "', $profile,'"'))
      else
        (: TBD: services:forward-error($error) :)
        oppidum:throw-error('CUSTOM', $coaches/message/text())
  (: 2. Retrieves list of coaches starting with letter in remote service :)        
  else
    let $letter := request:get-parameter('letter', 'A')
    let $payload := <Export Letter="{$letter}"/>
    let $coaches := services:post-to-service('ccmatch-public', 'ccmatch.export', $payload, "200")
    return
      if (local-name($coaches) ne 'error') then
        <Coaches Letter="{ $letter }">{ local:align-coaches($coaches//Coach) }</Coaches>
      else
        (: TBD: services:forward-error($error) :)
        oppidum:throw-error('CUSTOM', $coaches/message/text())
        

xquery version "1.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creator: Stéphane Sire <s.sire@opppidoc.fr>

   Shared database requests for Regional Entities search

   December 2014 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

module namespace search = "http://platinn.ch/coaching/search";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";


(: ======================================================================
   Returns a sequence of persons with the given role associated 
   with the given regional entity reference, or the empty sequence.
   ======================================================================
:)
declare function search:gen-linked-persons ( $role as xs:string, $region-ref as xs:string ) as element()* {
  let $role-ref := access:get-function-ref-for-role($role)
  return
    fn:collection($globals:persons-uri)//Role[(FunctionRef eq $role-ref) and (RegionalEntityRef eq $region-ref)]/ancestor::Person (: region-manager :)
};

declare function search:gen-team ( $tag as xs:string, $role as xs:string, $region-ref as xs:string ) as element()* {
  for $p in search:gen-linked-persons($role, $region-ref)
  order by $p/Name/LastName
  return
    element { $tag } {(
      attribute { '_Display' } { concat($p/Name/LastName, ' ', $p/Name/FirstName) },
      $p/Id/text()
    )}
};

declare function search:gen-team-for-display ( $role as xs:string, $region-ref as xs:string ) as xs:string {
  let $team := search:gen-linked-persons ($role, $region-ref)
  return
    if (empty($team)) then
      ''
    else
      string-join(
        for $p in $team
        order by $p/Name/LastName
        return
            concat($p/Name/LastName, ' ', $p/Name/FirstName),
        ', '
      )
};

declare function search:has-team-member ( $ref as xs:string, $members as xs:string* ) as xs:boolean {
  let $roles-ref := (access:get-function-ref-for-role('region-manager'), access:get-function-ref-for-role('kam'))
  return
    some $x in fn:collection($globals:persons-uri)//Role[(FunctionRef = $roles-ref) and (RegionalEntityRef eq $ref)]
    satisfies ($x/ancestor::Person/Id = $members)
};

(: ======================================================================
   Generates RegionalEntity information fields to display in result table
   ======================================================================
:)
declare function search:gen-region-sample ( $region as element()?, $lang as xs:string, $update as xs:boolean ) as element() {
  <RegionalEntity>
    {(
      if ($update) then attribute  { 'Update' } { 'y' } else (),
      $region/Id,
      $region/Acronym,
      $region/Address/Country,
      <Managers>{ search:gen-team('Manager', 'region-manager', $region/Id/text()) }</Managers>,
      <KAMs>{ search:gen-team('KAM', 'kam', $region/Id/text()) }</KAMs>
    )}
  </RegionalEntity>
};

(: ======================================================================
   Returns EEN entities matching request
   NOTE: - KAMs commented out to speed up
   ======================================================================
:)
declare function search:fetch-regions ( $request as element() ) as element()* {
  let $entity := $request//RegionalEntityRef/text()
  let $country := $request//CountryRef/text()
  let $member := $request//MemberRef/text()
  let $nuts := $request//Nuts/text()
  let $nuts-regions := 
    if ($nuts) then
      distinct-values(fn:collection($globals:regions-uri)//Region[NutsCodes/Nuts[. = $nuts]]/Id/text())
    else
      ()
  let $omni := access:check-omnipotent-user-for('update', 'Region')    
  return
    <Results>
      <RegionalEntities>
        {(
        if ($omni) then attribute { 'Update' } { 'y' } else (),
        for $region in fn:collection($globals:regions-uri)/Region
        where (empty($entity) or $region/Id = $entity)
               and (empty($nuts) or ($region/Id = $nuts-regions))
               and (empty($country) or $region/Address/Country = $country)
               and (empty($member) or search:has-team-member($region/Id/text(), $member))
        order by $region/Address/Country, $region/Acronym
        return
          search:gen-region-sample($region, 'en', false())
        )}
      </RegionalEntities>
    </Results>
};

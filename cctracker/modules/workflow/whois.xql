xquery version "1.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Generates model for persons linked to coaching activity

   February 2015 - (c) Copyright may be reserved
   ------------------------------------------------------------------ :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace workflow = "http://platinn.ch/coaching/workflow" at "workflow.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Generates a person's model suitable for display in Who'w Who
   ======================================================================
:)
declare function local:render-contact ( $contact as element()?, $beneficiary as element()? ) {
  if ($contact) then
    <Persons>
      <Person>
        { $contact/(Contacts | Function) }
        <Name>{ string-join(($contact/Civility, $contact/Name/FirstName, $contact/Name/LastName), ' ') }</Name>
        { $beneficiary }
      </Person>
    </Persons>
  else
    <None/>
};

(: ======================================================================
   Collate all persons playing a role for the given case or activity
   ======================================================================
:)
declare function local:gen-whois-list ( $workflow as xs:string, $project as element(), $case as element()?, $activity as element()?, $lang as xs:string ) as element()*
{
  let $service := display:gen-name-for('Services', $activity/Assignment/ServiceRef, $lang)
  let $region := display:gen-name-for-regional-entities( $case/ManagingEntity/RegionalEntityRef, $lang)
  return
    <WhoIs>
      {(
      attribute { 'Service' } { if ($service) then $service else 'not yet assigned' },
      attribute { 'RegionalEntity' } { if ($region) then $region else 'not yet assigned' },
      for $role in fn:doc($globals:application-uri)//Description/Role
      let $persons := workflow:get-persons-for-role($role/Name/text(), $project, $case, $activity)
      let $prefix := substring-before($role/Name, ':')
      let $suffix := substring-after($role/Name, ':')
      return
        <Role Abbreviation="{$role/Name/text()}">
          { 
          if (starts-with($role/Name, 'g:')) then (: Group e-mail address override :)
            let $suffix := substring($role/Name, 3)
            return fn:doc($globals:global-information-uri)/GlobalInformation/Description[@Lang = 'en']/Functions/Function[@Role eq $suffix]/@Mail
          else
            ()
          }
          <Title>{ $role/Legend/text() }</Title>
          {
          if (empty($persons)) then
            if ($prefix eq 'd') then
              if ($suffix eq 'sme-contact') then
                for $c in $project/Information/Beneficiaries/(Coordinator | Partner)/ContactPerson
                return local:render-contact($c, <Enterprise>{$c/../(Name | WebSite)}</Enterprise>)
              else if ($suffix eq 'needs-analysis-contact') then
                local:render-contact($case/NeedsAnalysis/ContactPerson, ())
              else (: unrecognized suffix :)
                ()
            else
              <None/>
          else
            <Persons>
              {
              for $ref in $persons
              let $p := fn:collection($globals:persons-uri)//Person[Id = $ref]
              return
                <Person>
                  {(
                  $p/Contacts,
                  <Name>{ display:gen-person-name($ref, 'en') }</Name>,
                  if ($role/Domain) then
                    for $d in $role/Domain
                    return
                      let $func-id := fn:doc($globals:global-information-uri)/GlobalInformation/Description[@Lang = 'en']/Functions/Function[@Role eq $suffix]/Id/text() (: TODO: factorize as form:gen-function-ref( $suffix ) ?  :)
                      let $value :=
                        for $item in $p//Role[FunctionRef eq $func-id]/*[local-name(.) eq $d/text()]
                        return misc:gen_display_name($item, 'Value')
                      return
                        element { substring-before($d, 'Ref') } {
                          if ($value) then
                            string-join($value, ", ")
                          else if ($d eq 'RegionalEntityRef') then
                            'not linked to any EEN entity yet'
                          else if ($d eq 'ServiceRef') then
                            'not linked to any service yet'
                          else
                            'not linked yet'
                          }
                  else
                    ()
                  )}
                </Person>
              }
            </Persons>
          }
        </Role>
      )}
    </WhoIs>
};

let $m := request:get-method()
let $cmd := oppidum:get-command()
let $lang := string($cmd/@lang)
let $pid := tokenize($cmd/@trail, '/')[2]
let $project := fn:collection($globals:projects-uri)/Project[Id eq $pid]
let $tokens := tokenize($cmd/@trail, '/')
let $case-no := if ($tokens[3] eq 'cases') then $tokens[4] else ()
let $case := if ($case-no) then $project/Cases/Case[No = $case-no] else ()
let $activity-no := if ($tokens[5] eq 'activities') then $tokens[6] else ()
let $activity := if ($activity-no) then $case/Activities/Activity[No = $activity-no] else ()
let $target := if ($activity-no) then 'Activity' else if ($case-no) then 'Case' else 'Project'
return
  if ($project and (not($case-no) or $case) and (not($activity-no) or $activity)) then
    local:gen-whois-list($target, $project, $case, $activity, 'en')
  else
    oppidum:throw-error("URI-NOT-FOUND", ())


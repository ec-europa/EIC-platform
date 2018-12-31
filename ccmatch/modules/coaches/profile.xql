xquery version "1.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Coach profile models for each facet (contact, experiences, competences)
   Builds the formular for editing and viewing
   To be included into user's home page tabs

   TODO:
   - View in readonly if not $reflective (!)

   September 2015 - (c) Copyright may be reserved
   ----------------------------------------------- :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

let $cmd := request:get-attribute('oppidum.command')
let $user := oppidum:get-current-user()
let $token := tokenize($cmd/@trail, '/')[1]
let $facet := string(oppidum:get-resource($cmd)/@name)
let $groups := oppidum:get-user-groups($user, oppidum:get-current-user-realm())
let $person := access:get-person($token, $user, $groups)
return
  if (local-name($person) ne 'error') then
    let $name := display:gen-person-name($person, 'en')
    let $reflective := $person/UserProfile/Username eq $user
    return
      <Page StartLevel="2" skin="editor">
        <Window>CM { $facet } for {$name}</Window>
        {
        if ($reflective) then
          <Commands>
            <Save Target="cm-profile-edit">
              <Label loc="action.save">Save</Label>
            </Save>
            <Cancel>
              <Label loc="action.back">Back</Label>
              <Action>../{$token}</Action>
            </Cancel>
          </Commands>
        else
          ()
        }
        <Content>
          <Title Level="1"><span loc="profile.title.{$facet}">Profile</span> of {$name}</Title>
          <Edit Id="cm-profile-edit">
            <Template>{ concat('../templates/coach/', $facet, '?goal=update') }</Template>
            <Resource>{ concat('profile/', $facet, '.xml') }</Resource>
            {
            if ($reflective) then
              <Commands>
                <Save>
                  <Label loc="action.save">Save</Label>
                </Save>
                <Cancel>
                  <Label loc="action.back">Back</Label>
                  <Action>../{$token}</Action>
                </Cancel>
              </Commands>
            else
              ()
            }
          </Edit>
        </Content>
      </Page>
  else
    $person

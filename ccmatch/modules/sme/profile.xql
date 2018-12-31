xquery version "1.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   SME simulator for launching a coach match suggest tunnel

   DEPRECATED: directly integrated into home.xql

   September 2015 - (c) Copyright may be reserved
   ----------------------------------------------- :)

import module namespace xdb = "http://exist-db.org/xquery/xmldb";

import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

let $cmd := request:get-attribute('oppidum.command')
let $lang := string($cmd/@lang)
let $user := oppidum:get-current-user()
return
  <Page StartLevel="2" skin="editor">
    <Window>CM SME matching simulator</Window>
    <Content>
      <Title Level="1">SME Profile to Match</Title>
      <Text class="text-info">Enter SME related information, then hit Suggest to find a coach</Text>
      <Submit Id="cm-sme-edit">
        <Action>suggest</Action>
        <Template>templates/sme/profile?goal=update</Template>
        <Commands>
          <Cancel>
            <Label loc="action.back">Back</Label>
            <Action>{$user}</Action>
          </Cancel>
        </Commands>
      </Submit>
    </Content>
  </Page>

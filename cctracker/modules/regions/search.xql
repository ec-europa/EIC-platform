xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Regions search and management pages

   December 2014 - European Union Public Licence EUPL
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace search = "http://platinn.ch/coaching/search" at "search.xqm";
import module namespace submission = "http://www.oppidoc.fr/oppidum/submission" at "../submission/submission.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

let $m := request:get-method()
return
  if ($m eq 'POST') then (: executes search requests :)
    let $request := oppidum:get-data()
    return
      <Search>
        {
        search:fetch-regions($request)
        }
      </Search>
  else (: shows search page with default results - assumes GET :)
    let $preview := request:get-parameter('preview', ())
    let $can-create := access:check-omnipotent-user-for('create', 'Region')
    return
      <Search Initial="true">
        <Formular Id="editor" Width="680px">
          <Template loc="form.title.regions.search">templates/search/regions</Template>
        
          {
          if (not($preview)) then
            <Submission Controller="regions">regions/submission</Submission>
          else
            ()
          }
          <Commands>
            {
            if ($can-create) then
              <Create Target="c-item-creator">
                <Controller>regions/add?next=redirect</Controller>
                <Label loc="action.add.region">Create a new EEN entity</Label>
              </Create>
            else
              ()
            }
            <Save Target="editor" data-src="regions" data-replace-target="results" data-save-flags="disableOnSave silentErrors" onclick="javascript:$('#c-busy').show()">
              <Label style="min-width: 150px" loc="action.search">Search</Label>
            </Save>
          </Commands>
        </Formular>
        {
        if ($preview) then
          (: simulates a search targeted at a single region :)
          search:fetch-regions(
            <SearchRegionsRequest>
              <RegionalEntities>
                <RegionalEntityRef>{ $preview }</RegionalEntityRef>
              </RegionalEntities>
            </SearchRegionsRequest>
          )
        else
          let $saved-request := submission:get-default-request('SearchRegionsRequest')
          return
            if (local-name($saved-request) = local-name($submission:empty-req)) then
              (:<NoRequest/>:)
              search:fetch-regions(<SearchRegionsRequest/>)
            else
              search:fetch-regions($saved-request)
        }
        <Modals>
          <Modal Id="c-item-viewer" Goal="read">
            <Template>templates/region?goal=read</Template>
            <Commands>
              {
              if (access:check-omnipotent-user-for('delete', 'Region')) then
                <Delete/>
              else
                ()
              }
              <Button Id="c-modify-btn" loc="action.edit"/>
              <Close/>
            </Commands>
          </Modal>
          <Modal Id="c-item-editor" data-backdrop="static" data-keyboard="false">
            <Template>templates/region?goal=update</Template>
            <Commands>
              <Save/>
              <Cancel/>
            </Commands>
          </Modal>
          {
          if ($can-create) then
            <Modal Id="c-item-creator" data-backdrop="static" data-keyboard="false">
              <Name>Add a new EEN Regional Entity</Name>
              <Template>templates/region?goal=create</Template>
              <Commands>
                <Save/>
                <Cancel/>
                <Clear/>
              </Commands>
            </Modal>
          else
            ()
          }
          <Modal Id="person" Goal="read">
            <Name>Community member</Name>
          </Modal>
        </Modals>
      </Search>

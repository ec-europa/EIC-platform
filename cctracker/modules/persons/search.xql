xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Brings up members search page with default search submission results
   or execute a search submission (POST) to return an HTML fragment.
   
   Mixed search controller that manages both persons and coaches search requests

   FIXME:
   - return 200 instead of 201 when AXEL-FORM will have been changed

   January 2015 - European Union Public Licence EUPL
   ----------------------------------------------- :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace search = "http://platinn.ch/coaching/search" at "search.xqm";
import module namespace submission = "http://www.oppidoc.fr/oppidum/submission" at "../submission/submission.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Add "realms" flag to template if user can edit realms
   ====================================================================== 
:)
declare function local:configure-template () as xs:string? {
  if (access:check-omnipotent-user-for('create', 'Person')) then (: TODO: for('create', 'Realms') ? :)
    "&amp;realms=1"
  else
    ()
};

declare function local:gen-search-ui ( $coach as xs:boolean, $create as xs:boolean, $tag as xs:string, $ctrl as xs:string, $tpl as xs:string ) as element()* 
{
  let $preview := request:get-parameter('preview', ())
  return (
    <Formular Id="editor" Width="680px">
      <Template loc="form.title.{ if ($coach) then 'coaches' else 'persons' }.search">
        {
        if ($coach) then attribute { 'sub-loc' } { 'form.subtitle.coaches.search' } else  (),
        concat('templates/search/', $tpl, '?goal=create')
        }
      </Template>
      {
      if (not($preview)) then
        <Submission Controller="{ $ctrl }">{ concat('persons/submission','?name=', $tag) }</Submission>
      else
        ()
      }
      <Commands>
        {
        if ($create) then
          <Create Target="c-item-creator">
            <Controller>persons/add?next=redirect</Controller>
            <Label loc="action.add.person">Ajouter une personne</Label>
          </Create>
        else
          (),
        if ($coach) then
          <Save Target="editor" data-src="match/criteria" data-type="json" data-replace-type="event" data-save-flags="disableOnSave silentErrors" onclick="javascript:$('#c-busy').show();$('#c-req-ready').hide();">
            <Label style="min-width: 150px" loc="action.search">Search</Label>
          </Save>
        else
          <Save Target="editor" data-src="persons" data-replace-target="results" data-save-flags="disableOnSave silentErrors" onclick="javascript:$('#c-busy').show()">
            <Label style="min-width: 150px" loc="action.search">Search</Label>
          </Save>
        }
      </Commands>
    </Formular>,
    if ($preview) then
      (: simulates a search targeted at a single person :)
      search:fetch-persons(
        element { $tag }
          {
          <Persons>
            <PersonRef>{$preview}</PersonRef>
          </Persons>
          }
      )
    else
      let $saved-request := submission:get-default-request($tag)
      return
        if (local-name($saved-request) = local-name($submission:empty-req)) then
          <NoRequest/>
        else if ($coach) then
          <RequestReady/>
        else
          search:fetch-persons($saved-request),
    if ($coach) then (
      <Suggest-Filters Target="criteria"/>,
      <Suggest-Results Target="criteria" Services="analytics" data-analytics-controller="coaches/analytics"/>
      )
    else
      (),
    let $realms := local:configure-template()
    return
      <Modals>
        {
        if ($coach) then
          <Modal Id="c-coach-summary"/>
        else (
          <Modal Id="c-item-viewer" Goal="read">
            <Template>templates/person?goal=read{ $realms }</Template>
            <Commands>
              {
              if (not($coach) and access:check-omnipotent-user-for('delete', 'Person')) then
                <Delete/>
              else
                ()
              }
              <Button Id="c-modify-btn" loc="action.edit"/>
              <Close/>
            </Commands>
          </Modal>,
          <Modal Id="c-item-editor" data-backdrop="static" data-keyboard="false">
            <Template>templates/person?goal=update{ $realms }</Template>
            <Commands>
              <Save/>
              <Cancel/>
            </Commands>
          </Modal>,
          if ($create) then
            <Modal Id="c-item-creator" data-backdrop="static" data-keyboard="false">
              <Name>Add a new person</Name>
              <Template>templates/person?goal=create{ $realms }</Template>
              <Commands>
                <Save/>
                <Cancel/>
                <Clear/>
              </Commands>
            </Modal>
          else
            ()
          )
        }
      </Modals>
    )
};

(: ======================================================================
   Generates plain vanilla person search user interface
   ====================================================================== 
:)
declare function local:gen-person-search-ui ( $cmd as element(), $create as xs:boolean ) as element()* 
{
  <Search skin="persons" Initial="true">
    {
    local:gen-search-ui(false(), $create, 'SearchPersonsRequest', 'persons', $cmd/resource/@name)
    }
  </Search>
};

(: ======================================================================
   Generates remote coach match search user interface
   ====================================================================== 
:)
declare function local:gen-coach-search-ui ( $cmd as element() ) as element()* {
  <Search skin="coaches" Initial="true">
    { local:gen-search-ui(true(), false(), 'SearchCoachesRequest', 'match/criteria', $cmd/resource/@name) }
    <Overlay>
      <Views>
        <View Id="cm-inspect-view" style="display:none">
          <Suggest-Inspect data-analytics-controller="coaches/analytics"/>
        </View>
      </Views>
      <Modals>
        <Show Id="cm-coach-summary" Width="700px">
          <Title>Coach</Title>
        </Show>
      </Modals>
    </Overlay>
  </Search>
};

let $cmd := oppidum:get-command()
let $m := request:get-method()
return
  if (($cmd/resource/@name ne 'coaches') or access:check-omnipotent-user-for('search', 'Coach')) then
    if ($m eq 'POST') then (: executes search requests :)
      let $request := oppidum:get-data()
      return
        if (exists($request//Coaches)) then
          let $groups := oppidum:get-current-user-groups() (:FIXME: temporary :)
          return
            if (empty($request/*/*) and not($groups = 'admin-system')) then
              oppidum:throw-error('CUSTOM', 'You must select at least 1 criteria !')
            else
              search:fetch-coaches($request)
        else
          <Search>{ search:fetch-persons($request) }</Search>
    else if ($cmd/resource/@name eq 'coaches') then (: search page with default results - assumes GET :)
      local:gen-coach-search-ui($cmd)
    else (: search page with default results - assumes GET :)
      local:gen-person-search-ui($cmd, access:check-omnipotent-user-for('create', 'Person'))
  else
    oppidum:throw-error('FORBIDDEN', ())


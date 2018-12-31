xquery version "1.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Construct a single page to query Coach Match services :
   - search by fit (against a given SME context)
   - search by criteria
   - handout generation for a list of coach (against a given SME context)

   UUID and @data-analytics-uuid are generated only if the calling 
   service generates an Analytics block in its request.

   See also : cm-suggest.js (DataIsland identifiers must be aligned)

   September 2015 - (c) Copyright may be reserved
   ----------------------------------------------- :)

import module namespace xdb = "http://exist-db.org/xquery/xmldb";

import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace services = "http://oppidoc.com/ns/services" at "../../lib/services.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Trick to catch errors when parsing submitted data
   TODO: move to misc:get-submitted-date()
   ======================================================================
:)
declare function local:gen-error() as element() {
  <error><message>Wrong submitted data</message></error>
};

let $cmd := request:get-attribute('oppidum.command')
let $lang := string($cmd/@lang)
let $user := oppidum:get-current-user()
let $data := request:get-parameter('data', ())
let $submitted := util:catch('*', util:parse($data), local:gen-error())
let $host-ref := services:get-key-ref-for ('ccmatch-public', 'ccmatch.suggest', $submitted/Service/Payload/Match/Key)
let $uuid := if ($submitted/Service/Payload/Match/Analytics) then <UUID>{ util:uuid() }</UUID> else ()
(: TODO: ideally we should also use services:validate and generate an error page here :)
return
  <Page StartLevel="2" skin="cm-suggest">
    <Window>CM suggestion of coaches</Window>
    { $submitted//Acronym }
    <Content>
      <DataIsland Id="cm-service-envelope">
        <Service>
          { $submitted/Service/AuthorizationToken }
          <Payload>
            <Match>
              { 
              $submitted/Service/Payload/Match/Key,
              $submitted/Service/Payload/Match/Analytics,
              $uuid
              }
              <Fill>HERE</Fill>
            </Match>
          </Payload>
        </Service>
      </DataIsland>
      <DataIsland Id="cm-search-by-fit">{ $submitted/Service/Payload/Match/SearchByFit }</DataIsland>
      <Verbatim>
        <p id="cm-fit-busy" class="cm-busy" style="display:none;margin-left:400px">Loading search by fit results...</p>
        <p id="cm-criteria-busy" class="cm-busy" style="display:none;margin-left:400px">Loading search by criteria results...</p>
      </Verbatim>
      <Views>
        <View Id="cm-search-view" style="margin-top: 10px;">
          <Tabs>
            <Tab Id="cm-fit-tab" class="active">
              <Name>Search by fit</Name>
              <Collapsible Id="cm-criteria-collapsible" State="disabled">
                <Title Level="1" style="margin-bottom:0">Search available Coaches</Title>
                <Name>Refine search within list</Name>
                <Edit Id="cm-criteria-edit">
                  <Template When="deferred">templates/criteria?goal=update&amp;host={$host-ref}</Template>
                  <Commands W="12" L="0">
                    <Button Id="cm-refine-button" State="disabled">
                      <Label>Search</Label>
                    </Button>
                  </Commands>
                </Edit>
              </Collapsible>
              <p class="text-info" style="margin-top:0;font-size:16px;float:left">Search restricted to accepted coaches who are available for additional coaching activities</p>
              <Suggest-Filters Target="fit"/>
              <Suggest-Results Target="fit" data-analytics-controller="suggest/fit/analytics">
                { 
                if ($uuid) then (
                  attribute { 'Services' } { 'analytics' },
                  attribute { 'data-analytics-uuid' } { $uuid/text() }
                  )
                else
                  ()
                }
              </Suggest-Results>
            </Tab>
            <Tab Id="cm-shortlist-tab">
              <Name>Handout list</Name>
              <Suggest-ShortList/>
            </Tab>
          </Tabs>
        </View>
        <View Id="cm-evaluation-view" style="display:none">
          <Suggest-Evaluation data-analytics-controller="suggest/fit/analytics">
            <AjaxFragment Id="cm-profile-part1" class="row-fluid">Loading coach profile</AjaxFragment>
            <div class="row-fluid noprint" style="margin-bottom:20px">
              <div class="span12" style="border:solid 1px #e5e5e5">
                <fieldset>
                  <legend style="margin-bottom:0"><span style="font-size: 18px;margin-left: 20px">Index</span></legend>
                  <div id="toc" style="padding: 5px 20px 20px 20px"/>
                </fieldset>
              </div>
            </div>
            <Title Level="1">Match of coach profile with company</Title>
            <Suggest-Dimension Key="competence" Title="Competence">competence needs</Suggest-Dimension>
            <Suggest-Dimension Key="experience" Title="SME context">SME context</Suggest-Dimension>
            <!--<Suggest-Dimension Key="criteria">Criteria</Suggest-Dimension>-->
            <Title Level="1">Profile of the coach</Title>
            <AjaxFragment Id="cm-profile-part2">Loading coach profile</AjaxFragment>
            <Handout/>
          </Suggest-Evaluation>
        </View>
        <View Id="cm-handout-view" style="display:none">
          <Suggest-Handout/>
        </View>
        <!--<View Id="cm-inspect-view" style="display:none">
          <Suggest-Inspect>
            <Handout/>
          </Suggest-Inspect>
        </View>-->
      </Views>
      <Modals>
        <Show Id="cm-coach-summary" Width="700px">
          <Title>Coach</Title>
        </Show>
      </Modals>
    </Content>
  </Page>

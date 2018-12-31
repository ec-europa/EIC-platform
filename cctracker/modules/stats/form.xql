xquery version "1.0";
(: --------------------------------------
   CCTRACKER application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Generates XTiger XML controls for insertion into stats filter masks

   January 2016 - (c) Copyright may be reserved
   ----------------------------------------------- :)

declare default element namespace "http://www.w3.org/1999/xhtml";

declare namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace form = "http://oppidoc.com/oppidum/form" at "../../lib/form.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";

declare namespace xt = "http://ns.inria.org/xtiger";
declare namespace site = "http://oppidoc.com/oppidum/site";

declare option exist:serialize "method=xml media-type=text/xml";

let $cmd := request:get-attribute('oppidum.command')
let $template := string(oppidum:get-resource($cmd)/@name)
let $lang := string($cmd/@lang)
return
  <site:view>
    <site:field Key="program">
      { form:gen-selector-for('FundingPrograms', $lang, ";multiple=yes;xvalue=FundingProgramRef") }
    </site:field>
    <site:field Key="call-cut-off">
      { form:gen-json-selector-for(('SMEiCalls', 'FTICalls', 'FETCalls'), $lang, "filter=event;multiple=yes;xvalue=ProgramCallRef;choice2_width1=300px;choice2_width2=100px;choice2_closeOnSelect=true") }
    </site:field>
    <site:field Key="phase">
      { form:gen-selector-for(('SMEiFundings','FETActions'), $lang, " event;multiple=yes;xvalue=FundingPhaseRef;typeahead=yes") }
    </site:field>
    <site:field Key="topic">
      <!--{ form:gen-selector-for('Topics', $lang, ";multiple=yes;xvalue=TopicRef;typeahead=yes") }-->
      <xt:use types="constant" param="noxml=true;class=uneditable-input span7">will be back soon</xt:use>
    </site:field>
    <site:field Key="project-officer">
      { 
      form:gen-person-with-role-selector('project-officer', $lang,
        ";multiple=yes;xvalue=ProjectOfficerRef;typeahead=yes", "span2")
      }
    </site:field>
    <site:field Key="case-status">
      { form:gen-workflow-status-selector('Case', $lang, " event;multiple=yes;xvalue=CaseStatusRef;typeahead=no") }
    </site:field>
    <site:field Key="countries">
      { form:gen-country-selector($lang, ";multiple=yes;xvalue=Country;typeahead=yes") }
    </site:field>
    <site:field Key="nuts">
      { 
      if (access:check-sight(oppidum:get-current-user(), 'ncp')) then
        let $nuts := access:get-current-user-nuts-as('ncp')
        return (: FIXME: xValue in constant and xvalue in choice ! :)
          <xt:use types="constant" param="class=span12 a-control;xValue=Nuts;_Output={string-join($nuts, ' ')}">
            { string-join($nuts, ',') }
          </xt:use>
      else
        form:gen-selector-for-nuts($lang, ";multiple=yes;xvalue=Nuts;typeahead=yes", "span2")
      }
    </site:field>
    <site:field Key="domains-of-activities">
      { form:gen-json-selector-for('DomainActivities', $lang, "multiple=yes;xvalue=DomainActivityRef;choice2_width1=250px;choice2_width2=250px;choice2_closeOnSelect=true") }
    </site:field>
    <site:field Key="targeted-markets">
      { form:gen-json-selector-for('TargetedMarkets', $lang, "multiple=yes;xvalue=TargetedMarketRef;choice2_width1=250px;choice2_width2=250px;choice2_closeOnSelect=true") }
    </site:field>
    <site:field Key="sizes">
      { form:gen-selector-for('Sizes', $lang, ";multiple=yes;typeahead=no;xvalue=SizeRef") }
    </site:field>
    <site:field Key="creation-year">
      { form:gen-creation-year-selector() }
    </site:field>
    <site:field Key="entity">
      {
      if (access:check-sight(oppidum:get-current-user(), 'region-manager')) then
        let $regions := access:get-current-user-regions-as('region-manager')
        return (: FIXME: xValue in constant and xvalue in choice ! :)
          <xt:use types="constant" param="class=span12 a-control;xValue=RegionalEntityRef;_Output={string-join($regions, ' ')}">
            { display:gen-name-for-regional-entities( $regions, 'en') }
          </xt:use>
      else
        form:gen-selector-for-regional-entities( $lang, ";select2_complement=town;multiple=yes;xvalue=RegionalEntityRef;typeahead=yes") 
      }
    </site:field>
    <site:field Key="kam">
      {
      if (access:check-sight(oppidum:get-current-user(), 'kam')) then
        let $uid := access:get-current-person-id()
        return (: FIXME: xValue in constant and xvalue in choice ! :)
          <xt:use types="constant" param="class=span12 a-control;xValue=AccountManagerRef;_Output={ $uid }">
            { display:gen-person-name($uid, 'en') }
          </xt:use>
      else
        form:gen-kam-selector($lang, ";multiple=yes;xvalue=AccountManagerRef;typeahead=no")
      }
    </site:field>
    <site:field Key="sector">
      { form:gen-selector-for('SectorGroups', $lang, ";multiple=yes;typeahead=no;xvalue=SectorGroupRef") }
    </site:field>
    <site:field Key="ctx-initial">
      { form:gen-selector-for('InitialContexts', $lang, ";multiple=yes;xvalue=InitialContextRef;typeahead=no") }
    </site:field>
    <site:field Key="ctx-target">
      { form:gen-selector-for('TargetedContexts', $lang, ";multiple=yes;xvalue=TargetedContextRef;typeahead=no") }
    </site:field>
    <site:field Key="vectors">
      { form:gen-challenges-selector-for('Vectors', $lang, ";multiple=yes;xvalue=VectorRef;typeahead=no") }
    </site:field>
    <site:field Key="ideas">
      { form:gen-challenges-selector-for('Ideas', $lang, ";multiple=yes;xvalue=IdeaRef;typeahead=no") }
    </site:field>
    <site:field Key="resources">
      { form:gen-challenges-selector-for('Resources', $lang, ";multiple=yes;xvalue=ResourceRef;typeahead=no") }
    </site:field>
    <site:field Key="partners">
      { form:gen-challenges-selector-for('Partners', $lang, ";multiple=yes;xvalue=PartnerRef;typeahead=no") }
    </site:field>
    {
    if ($template = ('stats-activities', 'stats-kpi'))  then (
      <site:field Key="activity-coach">
        { form:gen-coach-selector($lang, ";multiple=yes;xvalue=CoachRef;typeahead=no") }
      </site:field>,
      <site:field Key="service">
        { form:gen-selector-for('Services', $lang, ";multiple=yes;xvalue=ServiceRef;typeahead=no") }
      </site:field>,
      <site:field Key="activity-status">
        { form:gen-workflow-status-selector('Activity', $lang, " event;multiple=yes;xvalue=ActivityStatusRef;typeahead=no") }
      </site:field>,
      <site:field Key="communication">
        { form:gen-selector-for('CommunicationAdvices', $lang, ";multiple=yes;xvalue=CommunicationAdviceRef;typeahead=no") }
      </site:field>,
      if ($template eq 'stats-kpi')  then 
        <site:field Key="rating">
          { form:gen-selector-for('RatingScales', $lang, ";multiple=yes;xvalue=AdviceRef;typeahead=no") }
        </site:field>
      else
        ()
      )
    else
      ()
    }
  </site:view>

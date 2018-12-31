xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Generates extension points for the stage search formular.

   Basically this is a stub file to call database field generation functions in lib/form.xqm.

   BE AWARE OF THE DEFAULT NAMESPACE !

   January 2015 - (c) Copyright may be reserved
   ----------------------------------------------- :)

declare default element namespace "http://www.w3.org/1999/xhtml";

import module namespace form = "http://oppidoc.com/oppidum/form" at "../../lib/form.xqm";

declare namespace xt = "http://ns.inria.org/xtiger";
declare namespace site = "http://oppidoc.com/oppidum/site";

declare option exist:serialize "method=xml media-type=text/xml";

let $cmd := request:get-attribute('oppidum.command')
let $lang := string($cmd/@lang)
return
  <site:view>
    <site:field Key="nuts">
      { 
      form:gen-selector-for-nuts($lang, ";multiple=yes;xvalue=Nuts;typeahead=yes;select2_width=150px", "span2")
      }
    </site:field>
    <site:field Key="po">
      { 
      form:gen-person-with-role-selector('project-officer', $lang,
        ";multiple=yes;xvalue=ProjectOfficerRef;typeahead=yes;select2_width=380px", "span2")
      }
    </site:field>
    <site:field Key="coaches">
      { form:gen-coach-selector($lang, ";multiple=yes;xvalue=CoachRef;typeahead=yes;select2_width=150px") }
    </site:field>
    <site:field Key="enterprises">
      { form:gen-beneficiary-selector($lang, ";multiple=yes;xvalue=Name;typeahead=yes;select2_width=150px") }
    </site:field>
    <site:field Key="countries">
      { form:gen-country-selector($lang, ";multiple=yes;xvalue=Country;typeahead=yes;select2_width=150px") }
    </site:field>
    <site:field Key="sizes">
      { form:gen-selector-for('Sizes', $lang, ";multiple=yes;typeahead=no;xvalue=SizeRef;select2_width=150px") }
    </site:field>
    <site:field Key="domains-of-activities">
      { form:gen-json-selector-for('DomainActivities', $lang, "multiple=yes;xvalue=DomainActivityRef;choice2_width0=150px;choice2_width1=380px;choice2_width2=400px;choice2_closeOnSelect=true") }
    </site:field>
    <!-- <site:field Key="domains-of-activities">
      { form:gen-selector-for('DomainActivities', $lang, ";multiple=yes;xvalue=DomainActivityRef;typeahead=yes;select2_width=150px") }
    </site:field> -->
    <site:field Key="targeted-markets">
      { form:gen-json-selector-for('TargetedMarkets', $lang, "multiple=yes;xvalue=TargetedMarketRef;choice2_width0=150px;choice2_width1=380px;choice2_width2=400px;choice2_closeOnSelect=true") }
    </site:field>
    <!-- <site:field Key="targeted-markets">
      { form:gen-selector-for('TargetedMarkets', $lang, ";multiple=yes;xvalue=TargetedMarketRef;typeahead=yes;select2_width=150px") }
    </site:field> -->
    <site:field Key="services">
      { form:gen-selector-for('Services', $lang, ";multiple=yes;xvalue=ServiceRef;typeahead=no;select2_width=150px") }
    </site:field>
    <site:field Key="sector-groups">
      { form:gen-selector-for('SectorGroups', $lang, ";multiple=yes;typeahead=no;xvalue=SectorGroupRef;select2_width=150px") }
    </site:field>
    <site:field Key="ctx-initial">
      { form:gen-selector-for('InitialContexts', $lang, ";multiple=yes;xvalue=InitialContextRef;typeahead=no;select2_width=150px") }
    </site:field>
    <site:field Key="ctx-target">
      { form:gen-selector-for('TargetedContexts', $lang, ";multiple=yes;xvalue=TargetedContextRef;typeahead=no;select2_width=150px") }
    </site:field>
    <site:field Key="vectors">
      { form:gen-challenges-selector-for('Vectors', $lang, ";multiple=yes;xvalue=VectorRef;typeahead=no;select2_width=380px") }
    </site:field>
    <site:field Key="ideas">
      { form:gen-challenges-selector-for('Ideas', $lang, ";multiple=yes;xvalue=IdeaRef;typeahead=no;select2_width=380px") }
    </site:field>
    <site:field Key="resources">
      { form:gen-challenges-selector-for('Resources', $lang, ";multiple=yes;xvalue=ResourceRef;typeahead=no;select2_width=380px") }
    </site:field>
    <site:field Key="partners">
      { form:gen-challenges-selector-for('Partners', $lang, ";multiple=yes;xvalue=PartnerRef;typeahead=no;select2_width=380px") }
    </site:field>
    <site:field Key="activity-status">
      { form:gen-workflow-status-selector('Activity', $lang, " event;multiple=yes;xvalue=ActivityStatusRef;typeahead=no;select2_width=150px") }
    </site:field>
    <site:field Key="communication">
      { form:gen-selector-for('CommunicationAdvices', $lang, ";multiple=no;typeahead=no;select2_width=150px") }
    </site:field>
    <site:field Key="case-phases">
      { form:gen-selector-for('Phases', $lang, ";multiple=no;xvalue=PhaseRef;typeahead=no;select2_width=150px") }
    </site:field>
    <site:field Key="case-status">
      { form:gen-workflow-status-selector('Case', $lang, " event;multiple=yes;xvalue=CaseActivityStatusRef;typeahead=no;select2_width=150px") }
    </site:field>
    <site:field Key="kam">
      { form:gen-kam-selector($lang, ";multiple=yes;xvalue=CoachRef;typeahead=no;select2_width=150px") }
    </site:field>
    <site:field Key="entities">
      { form:gen-selector-for-regional-entities( $lang, ";select2_complement=town;multiple=yes;xvalue=RegionalEntityRef;typeahead=yes;select2_width=150px") }
    </site:field>
    <site:field Key="topics">
      { form:gen-selector-for('Topics', $lang, ";multiple=yes;xvalue=TopicRef;typeahead=yes;select2_width=380px") }
    </site:field>
    <site:field Key="prog">
      { form:gen-selector-for('FundingPrograms', $lang, " event;multiple=no;typeahead=yes;select2_width=150px") }
    </site:field>
    <site:field Key="funding">
      { form:gen-selector-for(('SMEiFundings','FETActions'), $lang, " event;multiple=yes;xvalue=FundingRef;typeahead=yes;select2_width=150px") }
    </site:field>
    <site:field Key="cutoffs">
      { form:gen-json-selector-for(('SMEiCalls', 'FTICalls', 'FETCalls'), $lang, "filter=event;multiple=yes;xvalue=SMEiCallRef;choice2_width0=380px;choice2_width1=300px;choice2_width2=300px;choice2_closeOnSelect=true") }
    </site:field>
    <site:field Key="panels">
      { form:gen-json-selector-for('EICPanels', $lang, "filter=event;multiple=yes;xvalue=EICPanelRef;choice2_width0=380px;choice2_width1=300px;choice2_width2=300px;choice2_closeOnSelect=true") }
    </site:field>
    <site:field Key="fettopics">
      { form:gen-json-3selector-for('FETTopics', $lang, "filter=event;multiple=yes;xvalue=FETTopicRef;choice2_width0=380px;choice2_width1=300px;choice2_width2=300px;choice2_closeOnSelect=true") }
    </site:field>
    <site:field Key="acronyms">
      { form:gen-acronym-selector($lang, ";multiple=yes;xvalue=Acronym;typeahead=yes;select2_width=150px") }
    </site:field>
  </site:view>

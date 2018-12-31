xquery version "1.0";
(: --------------------------------------
   CCTRACKER application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Generates XTiger XML controls for insertion into stats filter masks

   January 2016 - European Union Public Licence EUPL
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
let $host-ref := '1' (: FIXME: multi-hosts :)
return
  <site:view>
    <site:field Key="coach-name">
      { 
      form:gen-coach-selector($lang, ";multiple=yes;xvalue=CoachRef;typeahead=yes", $host-ref) 
      }
    </site:field>
    <site:field Key="accreditation-status">
      { form:gen-selector-for('Acceptances', $lang, ";multiple=yes;xvalue=AccreditationStatusRef;typeahead=yes") }
    </site:field>
    <site:field Key="availability">
      { form:gen-selector-for('YesNoAvails', $lang, ";multiple=yes;xvalue=YesNoAvailRef;typeahead=yes") }
    </site:field>
    <site:field Key="visibility">
      { form:gen-selector-for('YesNoAccepts', $lang, ";multiple=yes;xvalue=YesNoAcceptRef;typeahead=yes") }
    </site:field>
    <site:field Key="sex">
      { form:gen-selector-for('Genders', $lang, ";multiple=yes;xvalue=GenderRef;typeahead=yes") }
    </site:field>
    <site:field Key="languages">
      { form:gen-selector-for('EU-Languages', $lang, " optional;multiple=yes;xvalue=EU-LanguageRef;typeahead=yes;select2_minimumResultsForSearch=1") }
    </site:field>
    <site:field Key="service-years">
      { form:gen-selector-for('ServiceYears', $lang, ";multiple=yes;xvalue=ServiceYearRef;typeahead=yes") }
    </site:field>
    <site:field Key="services">
      { form:gen-selector-for('Services', $lang, ";multiple=yes;xvalue=ServiceRef;typeahead=yes") }
    </site:field>
    <site:field Key="countries">
      { form:gen-selector-for('Countries', $lang, ";multiple=yes;xvalue=Country;typeahead=yes") }
    </site:field>
    <site:field Key="domains-of-activities">
      { form:gen-json-selector-for('DomainActivities', $lang, "multiple=yes;xvalue=DomainActivityRef;choice2_width1=250px;choice2_width2=250px;choice2_closeOnSelect=true") }
    </site:field>
    <site:field Key="targeted-markets">
      { form:gen-json-selector-for('TargetedMarkets', $lang, "multiple=yes;xvalue=TargetedMarketRef;choice2_width1=250px;choice2_width2=250px;choice2_closeOnSelect=true") }
    </site:field>
    <site:field Key="sector">
      { form:gen-selector-for('SectorGroups', $lang, ";multiple=yes;typeahead=no;xvalue=SectorGroupRef") }
    </site:field>
    <site:field Key="ctx-life-cycle">
      { form:gen-selector-for('InitialContexts', $lang, ";multiple=yes;xvalue=InitialContextRef;typeahead=no") }
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
  </site:view>

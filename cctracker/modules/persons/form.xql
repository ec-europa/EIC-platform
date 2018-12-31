xquery version "1.0";
(: --------------------------------------
   EIC Coaching application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Generates extension points for Person search and Person formulars

   FIXME:
   - replace form:gen-coach-selector by form:gen-person-selector when goal is to search ?
   - generate (and localize) sex, civility and function fields from DB content ?

   September 2013 - European Union Public Licence EUPL
   ----------------------------------------------- :)

declare default element namespace "http://www.w3.org/1999/xhtml";

declare namespace httpclient = "http://exist-db.org/xquery/httpclient";

import module namespace form = "http://oppidoc.com/oppidum/form" at "../../lib/form.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace services = "http://oppidoc.com/ns/services" at "../../lib/services.xqm";

declare namespace xt = "http://ns.inria.org/xtiger";
declare namespace site = "http://oppidoc.com/oppidum/site";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Invokes CoachMatch service to build up to date coaches selector
   ====================================================================== 
:)
declare function local:call-gen-coach-selector( $lang as xs:string ) {
  let $result := 
    services:post-to-service('ccmatch-public', 'ccmatch.coaches',
      <Coaches xmlns="">{ services:get-key-for('ccmatch-public', 'ccmatch.coaches') }</Coaches>,
      ("200"))
  return
    if (local-name($result) ne 'error') then
      $result//httpclient:body/*
    else
      <xt:use types="constant" param="noxml=true;class=uneditable-input span">invocation error : { string($result) }</xt:use>
};

let $cmd := request:get-attribute('oppidum.command')
let $lang := string($cmd/@lang)
let $target := oppidum:get-resource(oppidum:get-command())/@name
let $goal := request:get-parameter('goal', 'read')
return
  if ($target = 'persons') then (: Person search form :)
      <site:view>
        <site:field Key="persons">
        { form:gen-person-selector($lang, ";multiple=yes;typeahead=yes;xvalue=PersonRef") }
      </site:field>
      <site:field Key="countries">
        { form:gen-country-selector($lang, ";multiple=yes;xvalue=Country;typeahead=yes") }
      </site:field>
      <site:field Key="enterprises">
        { form:gen-enterprise-selector($lang, ";multiple=yes;xvalue=EnterpriseRef;typeahead=yes") }
      </site:field>
      <site:field Key="functions">
          { form:gen-role-selector($lang, ";multiple=yes;typeahead=no;xvalue=FunctionRef") }
        </site:field>
        <site:field Key="services">
          { form:gen-selector-for('Services', $lang, ";multiple=yes;typeahead=no;xvalue=ServiceRef") }
        </site:field>
      </site:view>
  else if ($target = 'coaches') then (: Coaches search form :)
    <site:view>
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
      <site:field Key="domain-activities">
      {
      form:gen-json-selector-for('DomainActivities', $lang, "multiple=yes;xvalue=DomainActivityRef;choice2_width1=250px;choice2_width2=225px;choice2_closeOnSelect=true") }
      </site:field>
      <site:field Key="targeted-markets">
      {
      form:gen-json-selector-for('TargetedMarkets', $lang, "multiple=yes;xvalue=TargetedMarketRef;choice2_width1=250px;choice2_width2=225px;choice2_closeOnSelect=true")
      }
      </site:field>
      <site:field Key="life-cycle-stages">
      { form:gen-selector-for('InitialContexts', $lang, ";multiple=yes;xvalue=InitialContextRef;typeahead=yes") }
      </site:field>
      <site:field Key="service">
        { form:gen-selector-for('Services', $lang, ";multiple=yes;xvalue=ServiceRef;typeahead=yes") }
      </site:field>
      <site:field Key="countries">
        { form:gen-selector-for('Countries', $lang, ";multiple=yes;xvalue=Country;typeahead=yes") }
      </site:field>
      <site:field Key="languages">
        { form:gen-selector-for('EU-Languages', $lang, " optional;multiple=yes;xvalue=EU-LanguageRef;typeahead=yes;select2_minimumResultsForSearch=1") }
      </site:field>
      <site:field Key="coaches">
        { local:call-gen-coach-selector($lang) }
      </site:field>
      <site:field Key="expertise">
        <xt:use types="choice" param="appearance=full;multiple=no;class=c-inline-choice" values="mid high" i18n="mid\ or\ high high\ only">high</xt:use>
       </site:field>
      <site:field Key="uuid">
        <xt:use types="constant" label="UUID">{ util:uuid() }</xt:use>
       </site:field>
    </site:view>
    (: TODO: <site:field Key="countries">
      { form:gen-selector-for('Countries', $lang, ";multiple=yes;xvalue=Country;typeahead=yes") }
    </site:field> :)
  else if ($target = 'service') then (: Service read or update form :)
    if ($goal = 'read') then
      <site:view/>
    else
      <site:view>
        <site:field Key="coaches">
          { form:gen-person-selector($lang, ";multiple=yes;typeahead=yes;xvalue=CoachRef") }
        </site:field>
      </site:view>
  else if ($goal = ('update','create')) then
    <site:view>
      {
      if ($goal = 'create') then
        <site:field Key="lastname">
          { form:gen-person-enterprise-selector($lang, ";select2_tags=yes;typeahead=yes") }
        </site:field>
      else
        <site:field Key="lastname" filter="no">
          <xt:use types="input" param="filter=optional event;class=span a-control;required=true;" label="LastName"></xt:use>
        </site:field>
      }
      <site:field Key="sex">
        <xt:use types="choice"
        values="M F"
        i18n="M F"
        param="class=span12 a-control"
        >M</xt:use>
      </site:field>
      <site:field Key="countries">
        { form:gen-country-selector($lang, " optional;multiple=no;typeahead=yes") }
      </site:field>
      <site:field Key="enterprise">
        { form:gen-enterprise-selector($lang, ' optional;multiple=no;typeahead=yes') }
      </site:field>
      <site:field Key="realm">
        { form:gen-realm-selector(";multiple=no;typeahead=no") }
      </site:field>
    </site:view>
  else (: 'read' - only constant fields  :)
    <site:view/>

xquery version "1.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Generates selectors for coach search formular

   TODO:
   - SuperGrid Constant 'html' field (for Comments in Opinions)

   November 2014 - (c) Copyright may be reserved
   ----------------------------------------------- :)

import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace form = "http://oppidoc.com/oppidum/form" at "../../lib/form.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace match = "http://oppidoc.com/ns/match" at "match.xqm";

declare namespace xhtml = "http://www.w3.org/1999/xhtml";
declare namespace xt = "http://ns.inria.org/xtiger";
declare namespace site = "http://oppidoc.com/oppidum/site";

declare option exist:serialize "method=xml media-type=text/xml";

let $m := request:get-method()
let $cmd := request:get-attribute('oppidum.command')
let $lang := string($cmd/@lang)
let $goal := request:get-parameter('goal', 'read')
let $template := string(oppidum:get-resource($cmd)/@name)
return
  if ($m eq 'POST') then (: service for list of coaches selector :)
    let $request := match:get-data('guest', 'ccmatch.coaches')
    return
      if (local-name($request) ne 'error') then
        let $host := match:get-host('guest', $request/Key)
        return
          if (local-name($host) ne 'error') then
            form:gen-coach-selector-for-host($lang, ";multiple=yes;xvalue=CoachRef;typeahead=yes", $host)
          else
            $host
      else
        $request
  else
    if ($goal = 'update') then
      if ($template = 'criteria') then
        let $host-ref := request:get-parameter('host', '0')
        return
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
            form:gen-json-selector-for('DomainActivities', $lang, "multiple=yes;xvalue=DomainActivityRef;choice2_width1=323px;choice2_width2=400px;choice2_closeOnSelect=true;choice2_position=left") }
            </site:field>
            <site:field Key="targeted-markets">
            {
            form:gen-json-selector-for('TargetedMarkets', $lang, "multiple=yes;xvalue=TargetedMarketRef;choice2_width1=323px;choice2_width2=275px;choice2_closeOnSelect=true;choice2_position=left")
            }
            </site:field>
            <site:field Key="life-cycle-stages">
             { form:gen-selector-for('LifeCycleContexts', $lang, ";multiple=yes;xvalue=ContextRef;typeahead=yes") }
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
            {
            (: FIXME: manage case when calling from suggestion tunnel ! :)
            if (access:check-user-can('search', 'Coach')) then
              <site:field Key="coaches">
                {
                form:gen-coach-selector-for-host($lang, ";multiple=yes;xvalue=CoachRef;typeahead=yes", $host-ref)
                }
              </site:field>
            else
              ()
            }
            <site:field Key="expertise">
              <xt:use types="choice" param="appearance=full;multiple=no;class=c-inline-choice" values="mid high" i18n="mid\ or\ high high\ only">high</xt:use>
             </site:field>
          </site:view>
      else
        <site:view/>
    else (: assumes 'read' - no 'create' :)
      <site:view/>

xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Generates XTiger XML controls to be inserted inside the shared templates between workflow elements

   November 2014 - (c) Copyright may be reserved
   ----------------------------------------------- :)

declare default element namespace "http://www.w3.org/1999/xhtml";

import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace form = "http://oppidoc.com/oppidum/form" at "../../lib/form.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";

declare namespace xt = "http://ns.inria.org/xtiger";
declare namespace site = "http://oppidoc.com/oppidum/site";

declare option exist:serialize "method=xml media-type=text/xml";

let $cmd := request:get-attribute('oppidum.command')
let $lang := string($cmd/@lang)
let $goal := request:get-parameter('goal', 'read')
let $template := string(oppidum:get-resource($cmd)/@name)
return
  if ($goal = 'read') then
    if ($template = ('email')) then
      <site:view>
        <site:field Key="attachment" filter="no">
          <xt:use types="attachment" param="class=span a-control" label="Attachment"/>
        </site:field>
      </site:view>
    else
      <site:view/>
  else
    let $person-id := access:get-current-person-id ()
    return
    
    if ($template = ('email')) then
      <site:view>
        <site:field Key ="date">
          <xt:use types="constant" param="class=uneditable-input span">
            {display:gen-display-date(string(current-date()),$lang)}
          </xt:use>
        </site:field>
        <site:field Key="attachment" filter="no">
          <xt:use types="attachment" param="class=span a-control" label="Attachment"/>
        </site:field>
      </site:view>
    
      else if ($template = 'notification') then
        <site:view>
          <site:field Key ="date">
            <xt:use types="constant" param="class=uneditable-input span">
              {display:gen-display-date(string(current-date()),$lang)}
            </xt:use>
          </site:field>
          <site:field Key="sender">
            <xt:use types="constant" param="class=uneditable-input span">
              { misc:gen-current-person-name() }
            </xt:use>
          </site:field>
          <site:field Key="addressees">
            {
            let $field := form:gen-person-selector($lang, ";multiple=yes;xvalue=AddresseeRef;typeahead=yes")
            return
              <xt:use types="choice" values="-1 {$field/@values}" i18n="nobody::only\ for\ archiving {$field/@i18n}" param="{$field/@param}"/>
            }
          </site:field>
        </site:view>
        
      else
        <site:view/>

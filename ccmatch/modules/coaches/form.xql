xquery version "1.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Creator: Stéphane Sire <s.sire@oppidoc.fr>

   Extension points for Coach profile formulars

   TODO:
   - SuperGrid Constant 'html' field (for Comments in Opinions)

   November 2015 - (c) Copyright may be reserved
   ----------------------------------------------- :)

declare namespace request = "http://exist-db.org/xquery/request";

import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace form = "http://oppidoc.com/oppidum/form" at "../../lib/form.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
(:import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";:)

declare namespace xhtml = "http://www.w3.org/1999/xhtml";
declare namespace xt = "http://ns.inria.org/xtiger";
declare namespace site = "http://oppidoc.com/oppidum/site";

declare option exist:serialize "method=xml media-type=text/xml";

let $cmd := request:get-attribute('oppidum.command')
let $lang := string($cmd/@lang)
let $goal := request:get-parameter('goal', 'read')
let $realm := request:get-parameter('realms', '0')
let $template := string(oppidum:get-resource($cmd)/@name)
let $user := request:get-parameter('user', ())
return
  if ($goal = ('update', 'create', 'merge')) then
    if ($template = ('contact','coach-registration')) then
      <site:view>
        <site:field Key="sex">
          <xt:use types="choice" values="M F" i18n="M F" param="class=span1 a-control;filter=select2">M</xt:use>
        </site:field>
        <site:field Key="photo">
          <xt:use types="photo" label="Photo" param="photo_URL={$user}/photo;photo_base={$user}/photo;display=above;trigger=click;class=img-polaroid"/>
        </site:field>
        <site:field Key="countries">
        { form:gen-selector-for('Countries', $lang, ";multiple=no;typeahead=yes") }
        </site:field>
        {
        if ($realm eq '1') then
          <site:field Key="realm">
            { form:gen-realm-selector(";multiple=no;typeahead=no") }
          </site:field>
        else
          ()
        }
      </site:view>
    else if ($template = 'experiences') then
      <site:view>
        <site:field Key="experience">
          { form:gen-selector-for('ServiceYears', $lang, ";multiple=no;typeahead=yes") }
        </site:field>
        <site:field Key="cv-upload">
          <xt:use types="file" label="CV-File" param="file_delete={$user}/cv/remove;file_URL={$user}/cv;file_base={$user}/cv;file_gen_name=auto;file_size_limit=1024;file_button_class=btn btn-primary"/>
        </site:field>
        <site:field Key="languages">
          { form:gen-selector-for('EU-Languages', $lang, " optional;multiple=yes;xvalue=EU-LanguageRef;typeahead=yes;select2_minimumResultsForSearch=1") }
        </site:field>
        </site:view>
    else if ($template = 'competences') then
      <site:view>
      </site:view>
    else
      <site:view/>
  else (: assumes 'read' - no 'create' :)
    <site:view/>

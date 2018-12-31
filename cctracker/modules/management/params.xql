xquery version "1.0";
(: ------------------------------------------------------------------
   EIC coaching application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Application parameters management

   NOTE: access control done at mapping level !

   May 2014 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

declare variable $local:settings-uri := '/db/www/cctracker/config/settings.xml';

(: ======================================================================
   Validates submitted $value is an integer or raises an 'INVALID-INTEGER' error
   FIXME: to be moved to a lib/validation.xqm module
   ======================================================================
:)
declare function local:validate-integer ( $value as xs:string, $hint as xs:string? ) as element()? {
  if (not($value castable as xs:integer)) then
    ajax:throw-error('INVALID-INTEGER', $hint)
  else ()
};

(: ======================================================================
   Validates submitted $value is an email address or raises an 'INVALID-EMAIL' error
   FIXME: to be moved to a lib/validation.xqm module
   ======================================================================
:)
declare function local:validate-email ( $value as xs:string, $hint as xs:string? ) as element()? {
  if (not(matches($value, "^\s*$|^\w([\-.]?\w)+@\w([\-.]?\w)+\.[a-z]{2,6}$"))) then
    ajax:throw-error('INVALID-EMAIL', $hint)
  else ()
};

(: ======================================================================
   Validates submitted $value is at least $length characters long or raises an 'INVALID-LENGTH' error
   FIXME: to be moved to a lib/validation.xqm module
   ======================================================================
:)
declare function local:validate-length ( $min as xs:integer, $value as xs:string, $hint as xs:string? ) as element()? {
  if (string-length($value) < $min) then
    ajax:throw-error('INVALID-LENGTH', $hint)
  else ()
};

(: ======================================================================
   Validates submitted application parameters
   ======================================================================
:)declare function local:validate-params-submission( $data as element() ) as element()* {
  let $rate := normalize-space($data/CoachingHourlyRate/text())
  let $server := normalize-space($data/SMTPServer/text())
  let $sender := normalize-space($data/DefaultEmailSender/text())
  return (
    (:local:validate-integer($rate, "taux horaire"),:)
    local:validate-length(2, $server, "serveur d'envoi"),
    local:validate-email($sender, "expéditeur")
    )
};

(: ======================================================================
   Updates a node's value with $value iff different from current value
   ======================================================================
:)
declare function local:replace-value ( $node as element(), $value as xs:string ) {
  if ($value ne $node/text()) then
    update value $node with $value
  else ()
};

declare function local:replace-media( $rubrik as element(), $choices as element()? ) {
  let $tokens :=
    for $token in tokenize($choices, ',')
    let $c := normalize-space($token)
    where $c = ('account', 'workflow', 'action')
    return $c
  let $new :=
    element { local-name($rubrik) } {(
      if ('account' = $tokens) then <Category>account</Category> else (),
      if ('workflow' = $tokens) then <Category>workflow</Category> else (),
      if ('action' = $tokens) then <Category>action</Category> else ()
    )}
  return
    if (deep-equal($rubrik, $new)) then
      ()
    else
     update replace $rubrik with $new
};

(: ======================================================================
   Updates application parameters
   ======================================================================
:)
declare function local:update-params( $data as element() ) as element()* {
  let $settings := fn:doc($local:settings-uri)/Settings
  (:let $rate := normalize-space($data/CoachingHourlyRate/text()):)
  let $server := normalize-space($data/SMTPServer/text())
  let $sender := normalize-space($data/DefaultEmailSender/text())
  return (
    (:local:replace-value(fn:doc($globals:global-information-uri)//Description[@Lang='fr']/CoachingHourlyRate[1]/Amount, $rate),:)
    local:replace-value($settings/SMTPServer, $server),
    local:replace-value($settings/DefaultEmailSender, $sender),
    local:replace-media($settings/Media/Allow, $data/Allow),
    local:replace-media($settings/Media/Debug, $data/Debug),
    ajax:report-success('ACTION-UPDATE-SUCCESS', ())
    )[last()]
};

(: ======================================================================
   Returns the list of application parameters suitable for generating 
   the application parameters view (either for read or update goals)
   ======================================================================
:)
declare function local:gen-params-model( $goal as xs:string ) as element()* {
  let $settings := fn:doc($local:settings-uri)/Settings
  return
    <Params Goal="{$goal}">
      <!-- <Field Type="integer" Label="Taux horaire du coaching" Tag="CoachingHourlyRate">
            { fn:doc($globals:global-information-uri)//Description[@Lang='fr']/CoachingHourlyRate[1]/Amount/text() }
          </Field> -->
      <Field Label="SMTP server" Tag="SMTPServer">
        { $settings/SMTPServer/text() }
      </Field>
      <Field Type="email" Label="Fallback e-mail sender (new password)" Tag="DefaultEmailSender">
        { $settings/DefaultEmailSender/text() }
      </Field>
      <Field Type="list" Label="Plug e-mail categories (use 'none' to unplug all categories or 'account', 'workflow', 'action')" Tag="Allow">
        { 
        if ($settings/Media/Allow/Category) then
          string-join($settings/Media/Allow/Category/text(), ', ')
        else
          'none'
        }
      </Field>
      <Field Type="list" Label="Debug e-mail categories (use 'none' to not debug anything or 'account', 'workflow', 'action')" Tag="Debug">
        { 
        if ($settings/Media/Debug/Category) then
          string-join($settings/Media/Debug/Category/text(), ', ')
        else
          'none'
        }
      </Field>
    </Params>
};

let $m := request:get-method()
let $cmd := oppidum:get-command()
let $name := string($cmd/resource/@name)
let $lang := string($cmd/@lang)
return
  if ($m = 'POST') then
    let $data := oppidum:get-data()
    let $errors := local:validate-params-submission($data)
    return
      if (empty($errors)) then
        local:update-params($data)
      else
        ajax:report-validation-errors($errors)
  else (: assumes GET :)
    let $goal := request:get-parameter('goal', 'read')
    return
      local:gen-params-model($goal)

xquery version "3.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Generic CRUD controller to manage facet documents inside Enterprise

   March 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace template = "http://oppidoc.com/ns/cctracker/template" at "../../lib/template.xqm";
import module namespace misc = "http://oppidoc.com/ns/misc" at "../../lib/util.xqm";
import module namespace access = "http://oppidoc.com/ns/xcm/access" at "../../../xcm/lib/access.xqm";
import module namespace ajax = "http://oppidoc.com/ns/xcm/ajax" at "../../../xcm/lib/ajax.xqm";
import module namespace services = "http://oppidoc.com/ns/xcm/services" at "../../../xcm/lib/services.xqm";
import module namespace enterprise = "http://oppidoc.com/ns/enterprise" at "enterprise.xqm";
import module namespace user = "http://oppidoc.com/ns/xcm/user" at "../../../xcm/lib/user.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

let $m := request:get-method()
let $cmd := oppidum:get-command()
let $lang := string($cmd/@lang)
let $admission-no := tokenize($cmd/@trail, '/')[2]
let $admission := fn:collection($globals:admissions-uri)//.[Id eq $admission-no]
let $profile := user:get-user-profile()
return
 (: TODO: use permissions API and configure rules in application.xml :)
 if (
    exists($profile) and (access:check-entity-permissions('read', 'Admission', $admission))
    ) then
        (: Profile Investor have admission and is a PendingInvestor  :)
        (: Control if the X = admission of this investor :)
        if (exists($admission)) then
          template:gen-read-model(
            if ($admission/Settings/Teams eq 'Investor') then 'admission' else 'generic-admission',
            $admission, $lang)
        else
          oppidum:throw-error('NOT-FOUND', ()) 
 else 
   oppidum:throw-error('FORBIDDEN', ())

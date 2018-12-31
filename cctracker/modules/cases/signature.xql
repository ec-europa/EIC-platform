xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>
   XML protocol

   <Export><Ask [What=XPATH]></Export> :

   Ex: <Export><Ask What="Contract/Date[. eq '']"/></Export>
   (using CASE-TRACKER-KEY)

   April 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";
declare namespace request = "http://exist-db.org/xquery/request";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace services = "http://oppidoc.com/ns/services" at "../../lib/services.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace account = "http://platinn.ch/coaching/account" at "../users/account.xqm";


declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Returns Case sample
   ======================================================================
:)
declare function local:gen-case-sample( $case as element() ) as element() {
  <ProjectId>{ string($case/Id) }</ProjectId>
};

(: *** MAIN ENTRY POINT *** :)
let $submitted := oppidum:get-data()
let $errors := services:validate('cctracker', 'cctracker.signatures', $submitted)
return
  if (empty($errors)) then
    let $search := services:unmarshall($submitted)
    return
      (:1. query stuff to be updated :)
      if ($search/Ask) then
        let $what := if ($search/Ask/@What) then string($search/Ask/@What) else ()
        return
          if ($what) then
            <Batch>
            {
            let $results := util:eval(concat("fn:collection($globals:projects-uri)//Project[",$what,']'))
            return
              (
              attribute Count { count($results) },
              for $case in $results
              return local:gen-case-sample($case)
              )
            }
            </Batch>
          else
            <Batch/>
      else if ($search/Batch) then
      (:2. results pushed :)
        <Results>
        {
        for $action in $search/Batch/*
        let $case := fn:collection($globals:projects-uri)//Project[Id eq string($action/@Id)]
        return
          if ($case) then
          system:as-user(account:get-secret-user(), account:get-secret-password(),
          (
            if (local-name($action) eq 'DoInsert') then
              update insert $action/* into util:eval(concat('$case/', $action/@Into))
            else if (local-name($action) eq 'DoReplace') then
              update replace util:eval(concat('$case/', $action/@What)) with $action/*
            else
              (),
          local:gen-case-sample($case)
          )[last()])
          else
            ()
        }
        </Results>
      else
        ()
  else
    $errors

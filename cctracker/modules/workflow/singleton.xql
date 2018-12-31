xquery version "1.0";
(: --------------------------------------
   EIC Coaching application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   CRUD controller to manage single documents linked to an Activity workflow.
   It manages operations on single documents :
   - update-XXX method to create (lazy creation) or update document content
   - gen-XXX method to return document content for static display or editing
   where XXX is the document key identifier (e.g. funding-request).
   
   Note that if two persons edit the same document at the same time, as in a wiki 
   the last saved version will be the definitive version.
   
   August 2013 - (c) Copyright may be reserved
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace activity = "http://platinn.ch/coaching/activity" at "../activities/activity.xqm";

declare option exist:serialize "method=xml media-type=text/xml";
declare variable $cases-uri := '/db/sites/cctracker/cases/cases.xml';

(:
let $case-no := tokenize($cmd/@trail, '/')[2]
let $activity-no := tokenize($cmd/@trail, '/')[4]
let $case := fn:doc($cases-uri)/Cases/Case[No = $case-no]
let $activity := $case/Activities/Activity[No = $activity-no]
:)

(: ======================================================================
   Generic method (NOT IMPLEMENTED)
   ======================================================================
:)
declare function local:update-not-implemented( $data as element(), $lang as xs:string ) as element()* {
  oppidum:throw-error("NOT-IMPLEMENTED-YET", ())
};

(: =========================
   **** Funding request ****
   =========================
:)
declare function local:update-funding-request( $data as element(), $lang as xs:string ) as element()* {
  oppidum:throw-error("SOON-AVAILABLE", 'funding-request')
};

declare function local:gen-funding-request( $lang as xs:string, $editing as xs:boolean ) as element()* {
  <Document/>
};

let $m := request:get-method()
let $cmd := oppidum:get-command()
let $facet := string($cmd/resource/@name)
let $lang := string($cmd/@lang)
(: TODO: fine grain access control and generation of action buttons :)
(: TODO: check Case and Activy exist or do this from mapping check="true" attribute :)
return
  if ($m = 'POST') then
    let $data := oppidum:get-data()
    return
      if ($facet = 'funding-request') then
        local:update-funding-request($data, $lang)
      else 
        local:update-not-implemented($data, $lang)
  else (: assumes GET :)
    let $goal := request:get-parameter('goal', 'read')
    return
      if ($facet = 'funding-request') then
        local:gen-funding-request($lang, ($goal = 'update'))
      else 
        <Document/>

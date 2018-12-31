xquery version "1.0";
(: --------------------------------------
   EIC Coaching application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   CRUD controller to manage single documents linked to an Activity workflow.
   You can use it as is or copy it and create a document specific version.
   
   NOTE:
   - all documents data should be initialized when creating the Case if not empty by default
   - if two persons edit the same document at the same time, as in a wiki, the last saved wins
   
   September 2013 - (c) Copyright may be reserved
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Validates submitted data.
   Returns a list of errors to report or the empty sequence.
   ======================================================================
:)
declare function local:validate-submission( $data as element() ) as element()* {
  let $errors := (
    )
  return $errors
};

(: ======================================================================
   Updates the document inside the Activity
   NOTE: you SHOULD persists any data not submitted
   ======================================================================
:)
declare function local:update-document( $lang as xs:string, $data as element(), $activity as element() ) {
  let $root := local-name($data)
  let $found := $activity/*[local-name(.) = $root]
  let $save := element { $root } { $data/* }
  return
    if ($found) then (
      update replace $found with $save,
      ajax:report-success('ACTION-UPDATE-SUCCESS', ())
    ) else (
      update insert $save into $activity,
      ajax:report-success('ACTION-CREATE-SUCCESS', ())
    )
};

(: =========================================================
   Returns document data either for viewing of for editing
   NOTE: you SHOULD resolve references when not $editing
   =========================================================
:)
declare function local:gen-document( $lang as xs:string, $activity as element(), $editing as xs:boolean, $root as xs:string ) as element() {
  let $found := $activity/*[local-name(.) = $root]
  return
    if ($found) then
      $found
    else
      element { $root } { }
};

let $m := request:get-method()
let $cmd := oppidum:get-command()
let $lang := string($cmd/@lang)
let $root := request:get-attribute('xquery.root')
let $nb := tokenize($cmd/@trail, '/')[4]
return
  (: TODO: check access rights :)
  let $case := fn:doc(oppidum:path-to-ref())/Case
  return
    if ($case) then
      let $activity := $case/Activities/Activity[No = $nb]
      return
        if ($activity) then
          if ($m = 'POST') then
            let $data := oppidum:get-data()
            let $errors := local:validate-submission($data)
            return 
              if (empty($errors)) then
                  local:update-document($lang, $data, $activity)
              else
                ajax:report-validation-errors($errors)
          else (: assumes GET :)
            let $goal := request:get-parameter('goal', 'read')
            return
              local:gen-document($lang, $activity, $goal = 'update', $root)
        else
          ajax:throw-error('ACTIVITY-NOT-FOUND', ())
    else
      ajax:throw-error('CASE-NOT-FOUND', ())

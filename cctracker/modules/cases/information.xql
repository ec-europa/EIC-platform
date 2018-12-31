xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Composite CRUD controller to manage Information document into Case workflow.

   Sub-documents : ManagingEntity

   November 2014 - (c) Copyright may be reserved
   ----------------------------------------------- :)

import module namespace request="http://exist-db.org/xquery/request";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace cache = "http://oppidoc.com/ns/cctracker/cache" at "../../lib/cache.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   FIXME: call display:gen-region-manager-names instead
   ======================================================================
:)
declare function local:gen-een-contacts( $ref as xs:string ) as element()* {
  fn:collection($globals:persons-uri)//Person[UserProfile/Roles/Role[FunctionRef[. eq '3']][RegionalEntityRef eq $ref]]/Id
};

(: ======================================================================
   Validates submitted data.
   Returns a list of errors to report or the empty sequence.
   ======================================================================
:)
declare function local:validate-submission( $project as element(), $case as element(), $data as element() ) as element()* {
  let $errors := (
    if ($project/Cases/Case[No ne $case/No][PIC eq $data//PIC]) then
      oppidum:throw-error("CUSTOM", "This beneficiary has been already assigned to a case. Please choose another one")
    else
      ()
    )
  return $errors
};

(: ======================================================================
   Generates a new ManagingEntity sub-document for writing
   TODO: implement SuggestedEntityRef protocol
   ======================================================================
:)
declare function local:gen-managing-entity-for-writing( $case as element(), $legacy as element()?, $submitted as element() ) as element()* {
  let $legacy-ref := string($legacy/RegionalEntityRef)
  let $submit-ref := if (string($submitted/SuggestedEntityRef) ne '') then string($submitted/SuggestedEntityRef) else string($submitted/RegionalEntityRef)
  return
    if (($submit-ref ne $legacy-ref) or (($submit-ref eq '') and ($legacy-ref ne ''))) then (: updated :)
      <ManagingEntity>
        {(
        if ($submit-ref ne '') then <RegionalEntityRef>{ $submit-ref }</RegionalEntityRef> else (),
        misc:gen-current-person-id('AssignedByRef'),
        misc:gen-current-date('Date')
        )}
      </ManagingEntity>
    else (: unchanged :)
      ()
};

(: ======================================================================
   Updates ManagingEntity inside Information document inside Case
   ======================================================================
:)
declare function local:save-managing-entity( $case as element(), $submitted as element(), $lang as xs:string ) {
  let $host := $case
  return
    if ($host) then (: per construction Information should exist first :)
      let $legacy := $host/ManagingEntity
      let $data := local:gen-managing-entity-for-writing($case, $legacy, $submitted)
      return
        misc:save-content($host, $legacy, $data)
    else
      oppidum:throw-error('DOCUMENT-NOT-FOUND', ())
};

(: ======================================================================
   Serializes new element if it exists with optional _Source annotation
   ======================================================================
:)
declare function local:persists_annotation( $current as element()?, $new as element()? ) as element()? {
  if ($new) then
    if ($current/@_Source) then (: persists importer _Source annotation :)
      element { local-name($new) } {(
        $current/@_Source,
        $new/text()
      )}
    else
      $new
  else
    ()
};

(: ======================================================================
   Updates Information document inside Case
   ======================================================================
:)
declare function local:save-document( $case as element(), $submitted as element(), $lang as xs:string ) {
  let $legacy := $case/PIC
  return
    let $res := misc:save-content($case, $legacy, $submitted/PIC)
    return 
      if (local-name($res) eq 'success') then
        <success>
         {
         $res/*
         }
        </success>
      else
        $res
};


(: ======================================================================
   Utility function to generate an notification model from existing 
   data or to generate an empty one for display
   ======================================================================
:)
declare function local:gen-notification( $tag as xs:string, $contract as element()? ) {
  if ($contract/*[local-name(.) eq $tag ]) then 
    misc:unreference($contract/*[local-name(.) eq $tag ])
  else
    element { $tag }
      {
      <Date>not sent</Date>
      }
};

(: ======================================================================
   Returns Information document model either for viewing or editing based on 'read' or 'update' goal
   ======================================================================
:)
declare function local:gen-document-for( $case as element(), $goal as xs:string, $lang as xs:string ) as element() {
  let $data := $case
  let $benef := $case/../../Information/Beneficiaries/(Coordinator|Partner)[PIC eq $case/PIC]/Name
  return
    if ($data) then
      <Information>
        {(
        <PIC>
        {
        if ($goal eq 'read') then
          attribute _Display {$benef}
        else
          (),
        $case/PIC/text()
        }
        </PIC>,
        if (($goal eq 'read') and $data/ManagingEntity) then
          <ManagingEntity>
            {(
            misc:unreference($data/ManagingEntity/*),
            if ($data/ManagingEntity/RegionalEntityRef[. != '']) then 
              <ContactPerson>
                {
                let $contacts := local:gen-een-contacts($data/ManagingEntity/RegionalEntityRef)
                return
                  string-join(
                    for $c in $contacts return display:gen-person-name($c, $lang),
                    ', ')
                }
              </ContactPerson>
            else
              ()
            )}
          </ManagingEntity>
        else
          ()
        )}
      </Information>
    else (: unlikely :)
      <Information/>
};

(: ======================================================================
   Returns ManagingEntity sub-document model
   Per-construction should be for 'update' goal only
   ======================================================================
:)
declare function local:gen-managing-entity-for( $case as element(), $goal as xs:string, $lang as xs:string ) as element() {
  <ManagingEntity>{ $case/ManagingEntity/RegionalEntityRef }</ManagingEntity>
};

let $m := request:get-method()
let $cmd := oppidum:get-command()
let $lang := string($cmd/@lang)
let $pid := tokenize($cmd/@trail, '/')[2]
let $project := fn:collection($globals:projects-uri)/Project[Id eq $pid]
let $case-no := tokenize($cmd/@trail, '/')[4]
let $case := $project/Cases/Case[No eq $case-no]
let $goal := request:get-parameter('goal', 'read')
let $resource-name := string($cmd/resource/@name)
let $root := if ($resource-name eq 'information') then 'Information' else $resource-name (: composite controller :)
let $errors := access:pre-check-case($project, $case, $m, $goal, $root)
return
  if (empty($errors)) then
    if ($m = 'POST') then
      let $submitted := oppidum:get-data()
      let $errors := local:validate-submission($project, $case, $submitted)
      return
        if (empty($errors)) then
          if ($root = 'Information') then
            local:save-document($case, $submitted, $lang)
          else
            local:save-managing-entity($case, $submitted, $lang)
        else
          ajax:report-validation-errors($errors)
    else (: assumes GET :)
      if ($root = 'Information') then
        local:gen-document-for($case, $goal, $lang)
      else
        local:gen-managing-entity-for($case, $goal, $lang)
  else
    $errors

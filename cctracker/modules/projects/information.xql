xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Composite CRUD controller to manage Information document into Case workflow.

   Sub-documents : ManagingEntity

   November 2014 - European Union Public Licence EUPL
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
declare function local:validate-submission( $project as element(), $submitted as element() ) as element()* {
  let $errors := (
    )
  return $errors
};

(: ======================================================================
   Generates a new Contract element from the submitted one and from legacy
   Case Information document within the case.
   LEGACY: Persists SME-Notification and KAM-Notification if they exists (before 2016)
   See also sign.xql
   ======================================================================
:)
declare function local:gen-contract-for-writing( $project as element(), $contract as element()? ) {
  <Contract>
    {(
    $contract/Date,
    $contract/Start,
    $contract/Duration,
    $project/Information/Contract/SME-Notification,
    $project/Information/Contract/KAM-Notification
    )}
  </Contract>
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
   Reconstructs a ClientEnterprise record from current ClientEnterprise data 
   and from new submitted ClientEnterprise data.
   Persists batch import annotations
   ======================================================================
:)
declare function local:gen-enterprise-for-writing( $current as element()?, $new as element() ) {
  <ClientEnterprise>
    {(
    $current/(@LegacyId | @EnterpriseId),
    $new/Name,
    $new/ShortName,
    local:persists_annotation($current/CreationYear, $new/CreationYear),
    local:persists_annotation($current/SizeRef, $new/SizeRef),
    local:persists_annotation($current/DomainActivityRef, $new/DomainActivityRef[. ne '']),
    $new/WebSite,
    $new/MainActivities,
    $new/TargetedMarkets[. ne ''],
    $new/Address
    )}
  </ClientEnterprise>
};

(: ======================================================================
   Generates a new document to write from legacy and submitted data
   Persists @LegacyId and @EnterpriseId (PIC) on ClientEnterprise
   ======================================================================
:)
declare function local:gen-information-for-writing( $project as element(), $legacy as element()?, $submitted as element() ) {
  let $dirty-name := $legacy/ClientEnterprise/Name/text() ne $submitted/ClientEnterprise/Name/text()
  return
    (
    if ($dirty-name) then cache:invalidate('beneficiary', 'en') else (),
    <Information LastModification="{ current-dateTime() }">
      {(
      $submitted/Title,
      $submitted/Acronym,
      $submitted/Summary,
      $submitted/Call,
      $submitted/ProjectOfficerRef,
      local:gen-contract-for-writing($project, $submitted/Contract),
      local:gen-enterprise-for-writing($legacy/ClientEnterprise, $submitted/ClientEnterprise),
      $submitted/ContactPerson,
      $legacy/ManagingEntity
      )}
    </Information>
    )
};

(: ======================================================================
   Updates Information document inside Case
   ======================================================================
:)
declare function local:save-document( $project as element(), $submitted as element(), $lang as xs:string ) {
  let $signed := ($submitted/Contract/Date[. ne '']) and (string($project/Information/Contract/Date) ne string($submitted/Contract/Date))
  let $legacy := $project/Information
  let $data := local:gen-information-for-writing($project, $legacy, $submitted)
  return
    let $res := misc:save-content($project, $legacy, $data)
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
   Returns Information document model either for viewing or editing based on 'read' or 'update' goal
   ======================================================================
:)
declare function local:gen-document-for( $project as element(), $goal as xs:string, $lang as xs:string ) as element() {
  let $data := $project/Information
  return
    if ($data) then
      <Information>
        {(
        $data/Title,
        $data/Acronym,
        $project/No,
        <ProjectId>{ string($project/Id) }</ProjectId>,
        misc:unreference($data/*[not(local-name(.) = ('Title', 'Acronym', 'Call', 'Contract', 'Beneficiaries'))]),
        <Call>
        {
        <MasterCall>{collection($globals:global-info-uri)//Selector/Group[Selector/Option/(Id | Code)[. = $data/Call/(SMEiCallRef | FTICallRef | FETCallRef)]]/Name/text()}</MasterCall>,
        <CallRef>{ misc:unreference($data/Call/(SMEiCallRef | FTICallRef | FETCallRef))/@_Display }</CallRef>,
        <FundingRef>{ misc:unreference($data/Call/(SMEiFundingRef | FETActionRef))/@_Display }</FundingRef>,
        misc:unreference($data/Call/(FundingProgramRef | CallTopics | EICPanels | FETTopics))
        }
        </Call>,
        <Contract>
          {(
          misc:unreference-date($data/Contract/Date),
          misc:unreference-date($data/Contract/Start),
          $data/Contract/Duration
          )}
        </Contract>,
        <Participants>
        {
        for $b in $data/Beneficiaries/(Coordinator|Partner)
        return
          <Participant>
            <Role>{ local-name($b) }</Role>
              <Status>
              {
              misc:unreference($b/Status/*),
              if (string($b/Status/isConformSME) eq '') then
                <isConformSME><YesNoScaleRef _Display="Yes"/></isConformSME>
              else
                ()
              }
              </Status>
              { misc:unreference($b/*) }
            </Participant>
        }
        </Participants>
        )}
      </Information>
    else (: unlikely :)
      <Information/>
};

let $m := request:get-method()
let $cmd := oppidum:get-command()
let $lang := string($cmd/@lang)
let $pid := tokenize($cmd/@trail, '/')[2]
let $project := fn:collection($globals:projects-uri)/Project[Id eq $pid]
let $goal := request:get-parameter('goal', 'read')
let $resource-name := string($cmd/resource/@name)
let $root := if ($resource-name eq 'information') then 'Information' else $resource-name (: composite controller :)
let $errors := access:pre-check-project($project, $m, $goal, $root)
return
  if (empty($errors)) then
    if ($m = 'POST') then
      let $submitted := request:get-data()
      let $errors := local:validate-submission($project, $submitted)
      return
        if (empty($errors)) then
          local:save-document($project, $submitted, $lang)
        else
          ajax:report-validation-errors($errors)
    else
      local:gen-document-for($project, $goal, $lang)
  else
    $errors

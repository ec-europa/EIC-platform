xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Exports enterprises 
   To be called from third party applications like SMEi cockpit

   WARNING: exports client enterprises directly stored inside Cases 
   and not the content of the enterprises collection !

   XML protocol

   <Export [id="number"][LastUpdate="date"]><Call [Force="listofnumbers"]><Date>YYYY-MM-DD</Date></Call></Export> :
   - get all statuses from cases/activities

   Ex: <Export><Call><Date>2016-09-07</Date></Call></Export>
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
   Returns true if the case is more recent than the subset 
   ====================================================================== 
:)
declare function local:expired( $cached as xs:string, $extract as element() ) as xs:boolean {
  some $ts in ($extract//@LastModification, $extract//Status/Date/text()) satisfies ($cached < $ts)
};

(: ======================================================================
   Returns Case sample
   ======================================================================
:)
declare function local:gen-case-sample( $project as element() ) as element() {
  <Project>
  {
  $project/Id,
  for $case in $project/Cases/Case
  return
    <Case>
      { $case/( No | StatusHistory )}
      <AccountManager Email="{ display:gen-person-email($case/Management/AccountManagerRef, 'en') }">{ display:gen-name-person( $case/Management/AccountManagerRef, 'en' )}</AccountManager>
      <BusinessNeeds>
        <Classification>
        {
          $project/Information/Beneficiaries/*[PIC eq $case/PIC]//(DomainActivityRef | TargetedMarkets),
          $case/NeedsAnalysis//SectorGroupRef
        }
        </Classification>
        { $case/NeedsAnalysis/Context }
      </BusinessNeeds>
      <Activities>
      {
        for $a in $case/Activities/Activity
        return
          <Activity>
          {
            if ($a/No = $a/../@LastIndex) then
              attribute Last { '1' }
            else
              (),
            $a/( No | StatusHistory ),
            <Assignment>
            {
              $a/Assignment/@LastModification,
              $a/Assignment/ServiceRef,
              <Coach Email="{ display:gen-person-email($a/Assignment/ResponsibleCoachRef, 'en') }">{ display:gen-person-name($a/Assignment/ResponsibleCoachRef, 'en') }</Coach>
            }
            </Assignment>
          }
          </Activity>
      }
      </Activities>
    </Case>
  }
  </Project>
};


(: *** MAIN ENTRY POINT *** :)
let $submitted := oppidum:get-data()
let $errors := services:validate('cctracker', 'cctracker.cases', $submitted)
return
  system:as-user( account:get-secret-user(), account:get-secret-password(),
  if (empty($errors)) then
    let $search := services:unmarshall($submitted)
    let $id := if ($search/@Id) then string($search/@Id) else ()
    let $force := if ($search/Call/@Force ne '') then tokenize($search/Call/@Force, ',') else ()
    return
      <Projects Id="{$id}">
        {
        for $p in fn:collection($globals:projects-uri)//Project[Information/Call/(SMEiCallRef | FETCallRef | FTICallRef) = $search/Call/CallRef]
        let $diff := local:expired($search/@LastUpdate, $p)
        where ((empty($id) or $p/Id eq $id)
          and (empty($search/@LastUpdate) or $diff)) or ($force = $p/Id)
        return local:gen-case-sample($p)
        }
      </Projects>
  else
    $errors
  )

xquery version "1.0";
(: ------------------------------------------------------------------
CCTRACKER - EIC Case Tracker Application

Author: Frédéric Dumonceaux <fred.dumonceaux@gmail.com>

GET Controller to list contracts per-user

NOTES:
- currently called from the funding-decision of an activity

April 2016 - European Union Public Licence EUPL
------------------------------------------------------------------ :)

declare namespace fo="http://www.w3.org/1999/XSL/Format";
declare namespace xslfo="http://exist-db.org/xquery/xslfo";
declare namespace xsl="http://www.w3.org/1999/XSL/Transform";

import module namespace request="http://exist-db.org/xquery/request";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";

declare function local:gen-contract-annex( $case as element(), $activity as element() ) as element() {
  <Annex Coach="{ display:gen-person-name($activity/Assignment/ResponsibleCoachRef, 'en') }" User="{ misc:gen-current-person-name() }" Date="{ substring(string(current-dateTime()), 1, 19) }" >
    { $case/../../Information/Beneficiaries/*[PIC eq $case/PIC]/Name }
    { $case/../../Information/Acronym }
    <ProjectId>{ string($case/../../Id) }</ProjectId>
    { $activity/FundingRequest/Objectives }
    { $activity/FundingRequest/Budget/Tasks }
  </Annex>
};

let $cmd := oppidum:get-command()
let $pid := tokenize($cmd/@trail, '/')[2]
let $case-no := tokenize($cmd/@trail, '/')[4]
let $activity-no := tokenize($cmd/@trail, '/')[6]
let $project := fn:collection($globals:projects-uri)/Project[Id eq $pid]
let $case := $project/Cases/Case[No eq $case-no]
let $activity := $case/Activities/Activity[No = $activity-no]
let $errors := access:pre-check-activity($project, $case, $activity, 'GET', 'list', 'AnnexFile')
return
  if (empty($errors)) then
    (
    local:gen-contract-annex($case, $activity)
    )
  else
    $errors

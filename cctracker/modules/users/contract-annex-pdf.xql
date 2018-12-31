xquery version "1.0";
(: ------------------------------------------------------------------
CCTRACKER - EIC Case Tracker Application

Author: Frédéric Dumonceaux <fred.dumonceaux@gmail.com>

GET Controller to list contracts per-user

NOTES:
- currently called from the funding-decision of an activity

TODO:
- reuse contract-annex.xql and move all fo: code generation to contract-annex-pdf.xsl

April 2016 - European Union Public Licence EUPL
------------------------------------------------------------------ :)

declare namespace fo="http://www.w3.org/1999/XSL/Format";
declare namespace xslfo="http://exist-db.org/xquery/xslfo";
declare namespace xsl="http://www.w3.org/1999/XSL/Transform";

import module namespace system = "http://exist-db.org/xquery/system";
import module namespace transform="http://exist-db.org/xquery/transform";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace response="http://exist-db.org/xquery/response";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";

declare function local:gen-fo-layout() {
    <fo:layout-master-set>
        <!-- ============= LAYOUT ============= -->
        <fo:simple-page-master master-name="page" page-height="29.7cm" page-width="21cm" margin-top="1cm" margin-bottom="2cm" margin-left="2cm" margin-right="2cm">
            <fo:region-body margin-top="1cm"/><fo:region-before extent="3cm"/>
            <fo:region-after extent="1.5cm"/>
        </fo:simple-page-master>
        <!-- ============= PAGES LAYOUT ============= -->
        <fo:page-sequence-master master-name="all">
            <fo:repeatable-page-master-alternatives>
                <fo:conditional-page-master-reference master-reference="page" page-position="any"/>
            </fo:repeatable-page-master-alternatives>
        </fo:page-sequence-master>
    </fo:layout-master-set>
};


declare function local:gen-fo-cell-objectives( $activity as element()? ) as element() {
    <fo:table-cell text-align="center">
    {
        if ($activity/FundingRequest/Objectives/Text) then
          for $txt in $activity/FundingRequest/Objectives/Text
          return
              <fo:block>
              { data($txt) } 
              </fo:block>
        else
          <fo:block/>
    }
    </fo:table-cell>
};


declare function local:gen-fo-cell-activity( $activity as element()? ) as element()* {
    for $tsk in $activity/FundingRequest/Budget/Tasks/Task
    return
        <fo:table-row>
          <fo:table-cell>
            <fo:block>
            { data($tsk/Description) }
            </fo:block>
          </fo:table-cell>
          <fo:table-cell>
            <fo:block>
            { data($tsk/NbOfHours) }
            </fo:block>
          </fo:table-cell>
        </fo:table-row>
};


declare function local:gen-fo-cell-total-activity( $activity as element()? ) as element() {
    <fo:table-cell>
        <fo:block>
        { 
            sum($activity/FundingRequest/Budget/Tasks/Task/NbOfHours[. castable as xs:decimal])
        }
        </fo:block>
    </fo:table-cell>
};

let $cmd := oppidum:get-command()
let $pid := tokenize($cmd/@trail, '/')[2]
let $case-no := tokenize($cmd/@trail, '/')[4]
let $activity-no := tokenize($cmd/@trail, '/')[6]
let $project := fn:collection($globals:projects-uri)/Project[Id eq $pid]
let $case := $project/Cases/Case[No eq $case-no]
let $activity := $case/Activities/Activity[No = $activity-no]
let $coach-ref := $activity/Assignment/ResponsibleCoachRef

(: ================= FO Template + data ================== :)
let $fo :=
<fo:root xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:fo="http://www.w3.org/1999/XSL/Format" xmlns:fox="http://xmlgraphics.apache.org/fop/extensions">
    { local:gen-fo-layout() }
    {
      if (request:get-parameter('terms', '0') eq '1') then
       (: note that system:get-exist-home() starts with a slash and we need file:/// :)
        <fox:external-document content-type="pdf" src="{concat('url(file://', system:get-exist-home(),'/webapp/', globals:app-folder(), '/cctracker/untracked/Coaching_ToR_EMI.pdf)')}"/>
      else
        ()
    }
    <fo:page-sequence master-reference="all">
        <fo:flow flow-name="xsl-region-body">
        <fo:block font-family="helvetica,sans-serif" font-size="20pt" text-align="center">Business Coaching Plan</fo:block>
        <fo:block font-family="helvetica,sans-serif" font-size="9pt">
        <fo:table id="summary" table-layout="fixed" width="100%">
        <fo:table-column column-number="1" column-width="40%"/>
        <fo:table-column column-number="2" column-width="60%"/>
        <fo:table-body>
        <fo:table-row>
            <fo:table-cell>
                <fo:block>Name of the company</fo:block>
            </fo:table-cell>
            <fo:table-cell>
                <fo:block>
                { data($case/../../Information/Beneficiaries/*[PIC eq $case/PIC]/Name) }
                </fo:block>
            </fo:table-cell>
        </fo:table-row>
        <fo:table-row>
            <fo:table-cell>
                <fo:block>Acronym of the grant agreement</fo:block>
            </fo:table-cell>
            <fo:table-cell>
                <fo:block>
                { data($case/../../Information/Acronym) }
                </fo:block>
            </fo:table-cell>
        </fo:table-row>
        <fo:table-row>
            <fo:table-cell>
                <fo:block>Number of the grant agreement</fo:block>
            </fo:table-cell>
            <fo:table-cell>
                <fo:block>
                { data($case/../../Id) }
                </fo:block>
            </fo:table-cell>
        </fo:table-row>
        <fo:table-row>
            <fo:table-cell>
                <fo:block>Name of the coach</fo:block>
            </fo:table-cell>
            <fo:table-cell>
                <fo:block>
                { display:gen-person-name($coach-ref, 'en') }
                </fo:block>
            </fo:table-cell>
        </fo:table-row>
        </fo:table-body>
        </fo:table>
        </fo:block>
        
        <fo:block>
        <fo:table id="objectives" table-layout="fixed" width="100%">
        <fo:table-column column-number="1" column-width="100%"/>
        <fo:table-header>
        <fo:table-row>
            <fo:table-cell>
                <fo:block>Objectives</fo:block>
            </fo:table-cell>
        </fo:table-row>
        </fo:table-header>
        <fo:table-body>
        <fo:table-row>
        {    local:gen-fo-cell-objectives($activity) }
        </fo:table-row>
        </fo:table-body>
        </fo:table>
        </fo:block>
        <fo:block>
        <fo:table id="activity" table-layout="fixed" width="100%">
        <fo:table-column column-number="1" column-width="70%"/>
        <fo:table-column column-number="2" column-width="30%"/>
        <fo:table-header>
        <fo:table-row>
            <fo:table-cell>
                <fo:block>Activity</fo:block>
            </fo:table-cell>
            <fo:table-cell>
                <fo:block>Number of hours</fo:block>
            </fo:table-cell>
        </fo:table-row>
        </fo:table-header>
        <fo:table-body>
        { local:gen-fo-cell-activity($activity) }
        <fo:table-row>
            <fo:table-cell>
                <fo:block text-align="right">Total</fo:block>
            </fo:table-cell>
            { local:gen-fo-cell-total-activity($activity) }
        </fo:table-row>
        </fo:table-body>
        </fo:table>
        </fo:block>
        </fo:flow>
        
    </fo:page-sequence>
</fo:root>

let $errors := access:pre-check-activity($project, $case, $activity, 'GET', 'list', 'AnnexFile')
return
    if (empty($errors)) then
        $fo
    else
    <fo:root xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:fo="http://www.w3.org/1999/XSL/Format">
        { local:gen-fo-layout() }
        <fo:page-sequence master-reference="all">
            <fo:flow flow-name="xsl-region-body">
            <fo:block font-family="helvetica,sans-serif" font-size="20pt" text-align="center">Not allowed</fo:block>
            </fo:flow>
        </fo:page-sequence>
    </fo:root>
        

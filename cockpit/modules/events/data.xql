xquery version "3.0";
(: --------------------------------------
   Cockpit - EIC SME Dashboard Application

   Authors:
   - Stéphane Sire <s.sire@oppidoc.fr>
   - Frédéric Dumonceau <Frederic.DUMONCEAUX@ext.ec.europa.eu>

   CRUD controller to 
   - read / write a company application data to an event
   - export all the applications to an event to a tabular XML data model
     which can be converted to an Excel file on the fly

   TODO:
   - take workflow state into account into access control
   - use data templates 

   DEPRECATED : should be replaced by document.xql and export.xql !

   March 2017 - European Union Public Licence EUPL
   ----------------------------------------------- :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";
declare namespace site = "http://oppidoc.com/oppidum/site";
declare namespace xt = "http://ns.inria.org/xtiger";
declare namespace xhtml = "http://www.w3.org/1999/xhtml";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace custom = "http://oppidoc.com/ns/application/custom" at "../../app/custom.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace user = "http://oppidoc.com/ns/xcm/user" at "../../../xcm/lib/user.xqm";
import module namespace access = "http://oppidoc.com/ns/xcm/access" at "../../../xcm/lib/access.xqm";
import module namespace misc = "http://oppidoc.com/ns/xcm/misc" at "../../../xcm/lib/util.xqm";
import module namespace ajax = "http://oppidoc.com/ns/xcm/ajax" at "../../../xcm/lib/ajax.xqm";
import module namespace workflow = "http://oppidoc.com/ns/xcm/workflow" at "../../../xcm/modules/workflow/workflow.xqm";
import module namespace template = "http://oppidoc.com/ns/cctracker/template" at "../../lib/template.xqm";
import module namespace enterprise = "http://oppidoc.com/ns/enterprise" at "../enterprises/enterprise.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

declare function local:get-event-processing( $event-def as element(), $type as xs:string ) as element()? {
  if ($type eq '1') then
    $event-def/Processing[empty(@Role) or @Role eq 'beneficiary']
  else
    $event-def/Processing[@Role='investor']
};

(: ======================================================================
   Bootstraps the Event element inside the Events stream of the Enterprise
   if it does not exist to record the Application.
   FIXME: use a data template
   ====================================================================== 
:)
declare function local:lazy-initialize( $enterprise as element(), $event as element() ) {
  let $parent := if ($enterprise/Events) then () else update insert <Events/> into $enterprise
  return
    let $wrapper :=
      if ($enterprise/Events/Event[Id eq $event/Id]) then 
        ()
      else
        update insert 
          <Event>
            { $event/Id }
            <StatusHistory> 
              <CurrentStatusRef>1</CurrentStatusRef>
              <PreviousStatusRef/>
              <Status>
                <Date>{ substring(string(fn:current-date()), 1, 10) }</Date>
                <ValueRef>1</ValueRef>
              </Status>
            </StatusHistory>
            <Data/>
          </Event> into $enterprise/Events
    return
      ()
};
(: ======================================================================
   Whether the registration has been made outside registration period
   We have to push the submission to the lists
   ====================================================================== 
:)
declare function local:push-to-rankings( $enterprise as element(), $event-def as element() ) {
  if ($event-def/Rankings and not($event-def/FinalRankings)) then
    (
    update insert 
      <Applicant>
        <EnterpriseRef>{ $enterprise/Id/text() }</EnterpriseRef>
        <ProjectId Tag="Acronym">{ $enterprise/Events/Event[Id = $event-def/Id]//Data/Application//Acronym/text() }</ProjectId>
      </Applicant>
    into $event-def/Rankings//MainList
    )
  else
    ()

};

(: ======================================================================
   Changes Application status (increment by 1 which should move to Evaluation)
   See also status.xql
   ====================================================================== 
:)
declare function local:post-submit( $enterprise as element(), $event-def as element() ) {
  let $prog-id := $event-def/Programme/@WorkflowId
  let $event-application := $enterprise/Events/Event[Id = $event-def/Id]
  let $from := $event-application/StatusHistory/CurrentStatusRef/text()
  let $to := request:get-parameter('to', $event-application/StatusHistory/CurrentStatusRef/text() + 1)
  let $transition := workflow:get-transition-for($prog-id, $from, $to)
  let $validation := template:assert-event-transition($transition, $event-def, $event-application, $enterprise)
  return
    if (local-name($validation) eq 'valid') then 
      (
      workflow:apply-transition-to($transition/@To, $event-application, ()),
      local:push-to-rankings( $enterprise, $event-def )
      )
    else 
      $validation
};

(: ======================================================================
   Cleans up submitted event registration data
   - removes meaningless conditional values
   FIXME: use a data template
   ====================================================================== 
:)
declare function local:clean-data( $submitted as element(), $event-def as element(), $enterprise as element() ) as element() {
  let $processing := custom:get-event-processing($event-def, $enterprise)
  let $generator := $processing/Document[@Tab eq 'apply']/Create
  return
    if (exists($generator)) then
      template:gen-document($generator, 'create', $submitted)
    else (: DEPRECATED - replace with throw-error :)
      <Event>
      {
        $submitted/*[not(local-name(.) = ('EBITDA', 'Revenue', 'CoachAttending'))],
        for $t in ('EBITDA', 'Revenue')
        let $e := $submitted/*[local-name(.) eq $t]
        return
          if ($e) then
            element { $t } { if ($e//ApplicabilityRankRef eq '1') then $e/* else $e/ApplicabilityRanks }
          else
            (),
        let $e := $submitted/CoachAttending
        return
          if ($e) then
            element CoachAttending { $e/YesNoScaleRef, if ($e/YesNoScaleRef eq '1') then $e/HowCoachParticipationHelps else () }
          else
            ()
      }
      </Event>
};

(: ======================================================================
   Note: persists @ImportDate for imported events, saving back imported 
   events will also change some elements by adding an extra Text element
   ====================================================================== 
:)
declare function local:save-data( $cmd as element(), $enterprise as element(), $event as element(), $submitted as element() ) as element() {
  let $useless := local:lazy-initialize($enterprise, $event)
  let $current := $enterprise/Events/Event[Id eq $event/Id]
  (: FIXME: following command to be replaced in order to take into account subsequent formulars to implement (facetting?) :)
  let $ress := $cmd/resource/@name
  let $what :=
    if ($ress eq 'apply') then
      'Application'
    else if ($ress eq 'evaluation') then
      'Evaluation'
    else
      ()
  let $ts := substring(string(current-dateTime()), 1, 19)
  let $legacy := $current/Data/*[local-name(.) eq $what]
  let $has-legacy := exists($legacy)
  let $save := misc:save-content($current/Data, $legacy, element { $what }{ attribute LastModification { $ts }, $legacy/@ImportDate, $submitted/node() })
  return
    if ('submit' = request:get-parameter-names()) then
      let $res := local:post-submit($enterprise, $event)
      return
        if (local-name($res) eq 'error') then (
          if (not($has-legacy)) then (: to get Submit button :)
            (
            response:set-status-code(201),
            response:set-header('Location', concat($cmd/@base-url, 'events/', $enterprise/Id, '/form/', $event/Id)),
            oppidum:add-error('CUSTOM', $res/message, true())
            )
          else
            $res
        )
      else
        ajax:report-success-redirect('WFS-APPLICATION-SUBMITTED', (), concat($cmd/@base-url, 'events/', $enterprise/Id, '/form/', $event/Id ))
    else if (not($has-legacy)) then (: redirect to get Submit command in menu bar :)
      (
      response:set-header('Location', concat($cmd/@base-url, 'events/', $enterprise/Id, '/form/', $event/Id)),
      $save
      )
    else
      $save
};

declare function local:prefill-data( $enterprise as element(), $person as element() ) as element()* {
  (
  <Company>{ $enterprise/Information/Name }</Company>,
  let $member := $enterprise//Member[PersonRef = $person/Id]
  return
    <Contact>{ $member/Information/Name/node(), $member/Information/Civility, $member/Information/Contacts/node() }</Contact>
  )
};

declare function local:print-rejected( $enterprise as element(), $event-def as element() ) {
  let $rankings := $event-def/Rankings[@Iteration eq 'cur']
  let $reopened := exists($event-def/Rankings[empty(Lists/RejectList/*)])
  let $rejected-rankings := $event-def/Rankings[not($reopened) or preceding-sibling::Rankings[empty(Lists/RejectList/*)]][Lists/RejectList/Applicant/EnterpriseRef = $enterprise/Id]
  return
    if ($rankings/Lists/RejectList/Applicant/EnterpriseRef = $enterprise/Id) then (: actually rejected :)
      let $last-confirmed := ($rejected-rankings ! ./Confirmed)[last()]
      return
        concat('. Application rejected on ', display:gen-display-date-time($last-confirmed/@TS), '.')
    else if ($reopened) then
      let $rejected-rankings := $event-def/Rankings[Lists/RejectList/Applicant/EnterpriseRef = $enterprise/Id]
      let $last-confirmed := ($rejected-rankings ! ./Confirmed)[last()]
      return
        if (exists($rejected-rankings)) then
          concat('. Application reopened after it was initially rejected on ', display:gen-display-date-time($rejected-rankings/Confirmed/@TS), '.')
        else
          ()
    else 
      ()
};

declare function local:load-data( $cmd as element(), $enterprise as element(), $event-def as element() ) as element() {
  let $ress := $cmd/resource/@name
  let $event-application := $enterprise/Events/Event[Id eq $event-def/Id]
  let $processing := custom:get-event-processing($event-def, $enterprise)
  return
    if ($ress eq 'apply') then
      if (exists($processing/Document[@Tab eq 'apply']/Read)) then
        template:gen-read-model($processing/Document[@Tab eq 'apply']/Read, $enterprise, $event-application, 'en')
      else
        let $data := $event-application/Data/Application
        return
          <Event>
          {
            if (not($data)) then
              let $person := user:get-user-profile()/parent::Person
              return
                local:prefill-data( $enterprise, $person )
            else
              (
              misc:unreference($data/*[not(local-name(.) = 'Company')]),
              <Company>
              {
                $data/Company/*[not(local-name(.) = 'Acronym')],
                if ($data/Company/Acronym/text()) then 
                  let $deref :=  concat($enterprise/Projects//ProjectId[. = $data/Company/Acronym]/../Acronym, ' (', $data/Company/Acronym,')' )
                  return <Acronym _Display="{$deref}">{ $data/Company/Acronym/text() }</Acronym>
                else
                  ()
              }
              </Company>
              )
          }
          </Event>
    else if ($ress eq 'evaluation') then
      <Evaluation>
        <Something>
          <Field class="evaluation">
          { 
            if ($event-application/StatusHistory/CurrentStatusRef >= 2) then
              if ($event-application/Data/Application/@ImportDate) then 
                let $date := $event-application/Data/Application/@ImportDate
                return concat('Application imported on ', display:gen-display-date-time($date), 
                         local:print-rejected($enterprise, $event-def))
              else
                let $date := $event-application//Status[ValueRef eq '2']/Date
                return concat('Application submitted on ', display:gen-display-date-time($date), 
                         local:print-rejected($enterprise, $event-def))
            else if ($event-application/StatusHistory/CurrentStatusRef = 1) then 
              let $date := $event-application/Data/Application/@LastModification
              return concat('Application draft saved on ', display:gen-display-date-time($date), ' not yet submitted')
            else 
              ()
          }
          </Field>
        </Something>
      </Evaluation>
    else if ($ress eq 'finalization') then
      <Finalization>
        <Something>
          <Field>
          {
          let $rankings := $event-def/FinalRankings[@Iteration eq 'cur']
          return
            string-join(
              (
              let $date := fn:head(($rankings/Confirmed/@TS, $event-def/Rankings[@Iteration eq 'cur']/Confirmed/@TS))
              return
                if ($date) then
                  if ($rankings//MainList//Applicant/EnterpriseRef[text() eq $enterprise/Id]) then
                    concat('Participation approved on ', display:gen-display-date-time($date))
                  else if ($rankings//ReserveList//Applicant/EnterpriseRef[text() eq $enterprise/Id]) then
                    concat('Participation approved on reserve list on ', display:gen-display-date-time($date))
                  else if ($rankings//CancelList//Applicant/EnterpriseRef[text() eq $enterprise/Id]) then
                    concat('Cancelled on ', display:gen-display-date-time($date))
                  else
                    ()
                else
                  (),
              if (exists($event-application/Data/Confirmation)) then 
                let $date := $event-application/Data/Confirmation/@LastModification
                return concat('Confirmation received on ', display:gen-display-date-time($date))
              else
                (),
              if ($rankings/Confirmed/@TS) then
                ()
              else
                'Waiting for decision.'
              ),
              '. ')
          }
          </Field>
        </Something>
      </Finalization>
    else
      ()
};

(: ======================================================================
   Returns the Template element (path of XTiger template mesh questionnaire)
   to use with the Workflow's Document element passed as second parameter
   TODO: factorize with local:set-template in formular.xql
   ====================================================================== 
:)
declare function local:get-template-for( $event-def as element(), $doc-def as element(), $type as xs:string ) as xs:string {
  let $base := $doc-def/parent::Documents/@TemplateBaseURL
  let $tab := $doc-def/@Tab
  let $processing := local:get-event-processing($event-def, $type)
  return
      if ($processing/Document[@Tab eq $tab]/Template) then
        $processing/Document[@Tab eq $tab]/Template
      else if ($tab eq 'apply' and $event-def/Template and $type eq '1') then
        $event-def/Template
      else
        $doc-def/Template
};

(: ======================================================================
   Converts template URI to mesh file URI and returns corresponding mesh
   First choice is to replace REST URI nesting with dashed name,
   second choice is to consider only the last segment of the URI
   NOTE: actually all formulars/mesh files are flattened in a single folder/collection
   ====================================================================== 
:)
declare function local:get-mesh-for( $template as xs:string ) {
  let $tpl := replace($template, '/', '-')
  let $fp := concat('/db/www/cockpit/mesh/', $tpl, '.xhtml')
  return
    if (fn:doc-available($fp)) then
      fn:doc($fp)
    else
      fn:doc(
        concat('/db/www/cockpit/mesh/', tokenize($template, '/')[last()], '.xhtml')
        )
};

(: ======================================================================
   Climb to the father of the xt:use passed as parameter. 
   This is xt:use instantiating the xt:component which contains the xt:use.
   ====================================================================== 
:)
declare function local:climb( $use as element(), $mesh as document-node() ) as element()? {
  let $above := $use/ancestor::xt:component/@name
  return 
    if ($above) then $mesh//xt:use[@types eq $above][1] else ()
    (: should be unique but I had to pick up first one :)
};

(: ======================================================================
   Builds a specification of the columns to extract from the data
   using heuristics to extract them from the XTiger template mesh questionnaire
   ====================================================================== 
:)
declare function local:generate-headers($extra as element()*, $template-name as xs:string) as element() {
  let $mesh := local:get-mesh-for($template-name)
  let $black-list := for $r in $extra where $r/@Replace return tokenize($r/@Replace, ' ')
  return
    <Columns BL="{ $black-list }">
      {
      for $f in $extra
      return <Column Tag="{local-name($f)}"/>,
      for $f at $i in $mesh//site:field
      let $tag := if ($f/xt:use) then string($f/xt:use/@label) else string($f/@Tag)
      let $component := $f/ancestor::xt:component/@name
      let $parent := (: heuristic algorithm to get parent's XML label :)
        if ($component) then 
          let $origin :=  $mesh//xt:use[@types eq $component]
          return 
            if ($origin/@label) then
              $origin/@label
            else (: tries one container above :)
              if (count($origin) eq 1) then
                local:climb($origin, $mesh)/@label 
              else (: cannot say anything :)
                ()
        else
          ()
      (: trick to handle supergrid Repeat and div.no-export guard :)
      let $use := $mesh//xt:use[@types eq $component]
      where empty($f/ancestor::xhtml:div[contains(@class, 'no-export')])
      return
        if (exists($use/ancestor::xhtml:div[contains(@class, 'no-export')])
            or exists($f/ancestor::site:conditional[@meet eq 'read'])
            or ($tag = $black-list)) then (: skip it :)
          ()
        else
          <Column Tag="{$tag}" Parent="{$parent}" Rank="{$i}">
            {
            if (count($use) eq 1) then (: repeat sniffing heuristic :)
              if (exists($use/ancestor::xhtml:div[contains(@class, 'unroll-export')])) then
                attribute { 'Annotation' } { 'unroll'}
              else if ($use/ancestor::xt:repeat or (local:climb($use, $mesh)/ancestor::xt:repeat)) then
                attribute { 'Annotation' } { 'repeat'}
              else
                ()
            else (: other cases cannot be parsed for repeat detection :)
              (),
            $f/parent::xhtml:div/parent::xhtml:div/xhtml:label/text()
            }
          </Column>
      }
    </Columns>
};

declare function local:generate-filename($event as element(), $what as xs:string) as xs:string {
  let $prg := $event/Programme/@WorkflowId
  let $event := $event/Information/Name
  return
    concat($prg, '_', $what, '_', replace($event, ' ', '_'), '-', fn:current-dateTime())
};


(: ======================================================================
   Try to find a selector matching $name using pluralization heuristics
   ====================================================================== 
:)
declare function local:guess-selector-for ( $name as xs:string ) as xs:string? {
  let $selectors := fn:collection($globals:global-info-uri)//Description[@Lang = 'en']
  let $plural := concat($name, "s")
  let $ref-to-plural := if (ends-with($name, "Ref")) then replace($name, "Ref$", "s") else ()
  let $y-plural := if (ends-with($name, "y")) then replace($name, "y$", "ies") else ()
  return
    if (exists($selectors//Selector[@Name eq $name])) then
      $name
    else if (exists($selectors//Selector[@Name eq $plural])) then
      $plural
    else if (exists($selectors//Selector[@Name eq $ref-to-plural])) then
      $ref-to-plural
    else if (exists($selectors//Selector[@Name eq $y-plural])) then
      $y-plural
    else 
      ()
};

(: ======================================================================
   For debugging by tracing in a cache attribute on root (see below)
   ====================================================================== 
:)
declare function local:guess-cachable-selectors ( $columns as element() ) as xs:string* {
  for $cur in distinct-values($columns/Column/@Tag)
  let $cachable := local:guess-selector-for($cur)
  return 
    if ($cachable) then
      if ($cachable eq $cur) then
        $cur
      else 
      concat($cur, '[', $cachable, ']')
    else
      ()
};

(: ======================================================================
    Generate all possible caches from Selectors for $columns
   ====================================================================== 
:)
declare function local:generate-cache( $columns as element()* ) as map() {
  map:new(
    for $name in distinct-values($columns/Column/@Tag)
    let $candiname := local:guess-selector-for($name)
    where exists($candiname)
    return
      let $defs := fn:collection($globals:global-info-uri)//Description[@Lang = 'en']//Selector[@Name eq $candiname]
      return
        if (exists($defs)) then (: should always pass :)
          let $value := string(($defs/@Value, 'Value')[1]) 
          let $key := replace(string(($defs/@Label, 'Name')[1]), "^\w+\+", "")
          let $decode := exists($defs/@Value) or exists($defs/@Label)
          return
            map:entry(
              $name,
              if ($decode) then (: costly vesrion :)
                map:new(
                  for $opt in $defs//Option
                  return
                    map:entry($opt/*[local-name() eq $value]/text(), $opt/*[local-name() eq $key]/text())
                )
              else (: fast version :)
                map:new(
                  for $opt in $defs//Option
                  return
                    map:entry($opt/Value/text(), $opt/Name/text())
                )
            )
        else
          ()
  )
};

(: ======================================================================
   Converts a data element into a string taking into account data types  
   encoded from selectors (*Ref convention) and multi-paragraphs texts
   ====================================================================== 
:)
declare function local:decode-column( $content as element()?, $tag as xs:string?, $cache as map() ) as xs:string? {
  if (empty($content)) then
    ()
  else if ($content/Text) then 
    string-join($content/Text, codepoints-to-string((13, 10, 13, 10)))
  else if (empty($content/*)) then
    if (map:contains($cache, $tag)) then (: cached singleton field :) 
      let $sel := map:get($cache, $tag)
      let $key := $content/text()
      return
        if (empty($key)) then
          $key
        else if (map:contains($sel, $key)) then
          map:get($sel, $key)
        else (: false positive : field must not be a data type but a free text :)
          $key
    else if (ends-with($tag, 'Ref')) then 
      let $scale := replace(replace($tag, "Ref$", "s"), "ys$", "ies")
      return display:gen-name-for ($scale, $content, 'en')
    else
      $content/text()
  else if (map:contains($cache, $tag)) then (: cached selector list field :) 
    let $sel := map:get($cache, $tag)
    return
      string-join(
        for $key in $content/*/text()
        return map:get($sel, $key), 
        ', ')
  else (: tries with selector list :) 
    let $content-tag := if (ends-with($tag, "ies")) then
                          replace($tag, "ies$", "yRef")
                        else
                          replace($tag, "s$", "Ref")
    let $refs := $content/*[local-name() eq $content-tag]
    return
      if (exists($refs)) then
        display:gen-name-for ($tag, $refs, 'en')
      else (: fallback to string serialization :) 
        string($content)
};

(: ======================================================================
   Generates extra columns to add to export applying the corresponding
   export data template to the (Enterprise, Project, Event) triplet
   ====================================================================== 
:)
declare function local:gen-extra-rows( $extra-template as xs:string?, $doc as element() ) as element()? {
  if ($extra-template) then
    let $enterprise := $doc/ancestor::Enterprise
    let $data := $doc/ancestor::Data
    (: NOTE: imposes structure on contact e-mail address in all Application forms :)
    let $pid := ($data/Application/Company/Acronym, $data/Application/SMEIgrantagreementnumber, $data/Application/Project/Acronym, $data/Application/CompanyProfile/Acronym)[1]
    let $project := $enterprise/Projects/Project[ProjectId eq normalize-space($pid)]
    return
      template:gen-document($extra-template, 'export', $enterprise, $project, $data/parent::Event)
  else
    ()
};

declare function local:make-row( $unroll-pos as xs:integer, $data as element()*, $columns as element(), $status-def as xs:string, $cache as map() ) as element()* {
  <row>
    <col explicit="Current status">{ if (number($data/ancestor::Event/StatusHistory/CurrentStatusRef) > number($status-def)) then 'Submitted' else 'Draft' }</col>
    {
    for $c in $columns/Column
    let $content := $data//*[local-name(.) = $c/@Tag]
    return
      <col tag="{$c/@Tag}" explicit="{if ($c ne '') then $c else $c/@Tag}">
        {
        if ($c/@Parent) then 
          attribute { 'parent' } { string($c/@Parent) }
        else
          (),
        if ($c/@Rank) then 
          attribute { 'key' } { string($c/@Rank) }
        else
          (),
        (: first test if repeated tags in template data model
           second test if repeated tags in saved data in case it contains more data 
           than template data model :)
        if ((count($columns/Column[@Tag eq $c/@Tag]) > 1) or count($content) > 1) then
          (: use @Parent tag for decoding too ! :)
          if ($c/@Parent ne '') then
            let $filtered := for $x in $content 
                             where local-name($x/parent::*) eq $c/@Parent
                             return $x
            return
              if (count($filtered) > 1) then 
                if ($c/@Annotation eq 'repeat') then
                  (: FIXME: assumes plain text field (no Selector) :)
                  string-join(for $f in $filtered return local:decode-column($f, $c/@Tag, $cache), ', ')
                else
                  concat('AMBIGOUS: could not decode ', $c/@Parent, ' amongst ', count($filtered), ' potential matching elements : ', string-join(for $f in $content return concat(local-name($f/parent::*), '/', local-name($f)), ', '))
              else
                local:decode-column($filtered, $c/@Tag, $cache)
          else (: filters with preceding-sibling, does not work if ambiguity on 1st column :)
            let $filtered := for $x in $content
                             where local-name($x/preceding-sibling::*[1]) eq $c/preceding-sibling::Column[1]/@Tag
                             return $x
            return local:decode-column($filtered, $c/@Tag, $cache)
        else
          if ($c/@Annotation eq 'unroll') then
            local:decode-column($content[$unroll-pos],$c/@Tag, $cache)
          else if ($c/@Annotation eq 'repeat') then
            (: FIXME: assumes plain text field (no Selector) :)
            string-join(for $f in $content return local:decode-column($f,$c/@Tag, $cache), ', ')
          else if (count($content) > 1) then
            concat('AMBIGOUS: could not decode ', $c/@Parent, ' amongst ', count($content), ' potential matching elements : ', string-join(for $f in $content return concat(local-name($f/parent::*), '/', local-name($f)), ', '))
          else
            local:decode-column($content,$c/@Tag, $cache)
        }
      </col>
    }
  </row>,
  if (some $c in $columns/Column[@Annotation eq 'unroll'] 
      satisfies count($data//*[local-name(.) = $c/@Tag]) > $unroll-pos) then
    local:make-row($unroll-pos + 1, $data, $columns, $status-def, $cache)
  else
    ()
};

(: ======================================================================
   Handles the exportation of all events forms to a row table model 
   suitable for Excel file packaging in epilogue.
   Export Beneficiary ($type eq 1) or Investor ($type eq 2) submissions
   Access control must be implemented up front.
   ====================================================================== 
:)
declare function local:handle-export ( $cmd as element(), $type as xs:string ) {
  let $ress := string($cmd/resource/@name)
  let $event-id := tokenize($cmd/@trail,'/')[2]
  let $event := fn:collection('/db/sites/cockpit/events')//Event[Id = $event-id]
  (: uses Selector for the workflow type to find which status to match for export and which document contains submitted data :)
  let $selector := fn:collection($globals:global-info-uri)//Description[@Lang = $cmd/@lang]//Selector[@Name eq $event/Programme/@WorkflowId]
  let $status-def := $selector/Option[Export/@Link eq $ress]/Value
  let $export := $selector/Option/Export[@Link eq $ress]
  (: gets optional extra columns :)
  let $processing := local:get-event-processing($event, $type)
  let $extra-template := ($export/@Extra, $processing/Document[@Tab eq $ress]/Export)[1]
  (: dry run to get extra columns name, implies no pruning on data template :)
  let $more-columns := template:gen-document($extra-template, 'export', ())
  (: now finds the questionnaire template name applying priority rules :)
  let $prog-id := $event/Programme/@WorkflowId
  let $workflow-app := fn:doc($globals:application-uri)//Workflow[@Id eq $prog-id]
  let $document-app := $workflow-app//Document[@Tab eq $ress]
  let $template-name := local:get-template-for($event, $document-app, $type)
  (: now builds the spec of the columns to extract by analysing the template mesh  :)
  let $columns := local:generate-headers($more-columns/*, $template-name)
  let $cache := local:generate-cache($columns)
  let $all-data := fn:collection($globals:enterprises-uri)//Enterprise//Event[Id = $event-id and number(StatusHistory/CurrentStatusRef) >= ($status-def, $status-def + 1)]//Data/*[local-name(.) eq $export]
  return
    <root fn="{local:generate-filename($event, $export)}"  template="{$template-name}" extra="{$extra-template}" cached="{ string-join(local:guess-cachable-selectors($columns), ' ') }">
    {
      (: uncomment to debug :) (:$columns,:)
      if ($all-data) then
        for $doc in $all-data
        let $data := (local:gen-extra-rows($extra-template, $doc), $doc)
        (: filter by enteprise type :)
        where ($type eq '1' and empty($doc/ancestor::Enterprise/Settings/Teams))
              or
              ($type eq '2' and enterprise:is-a($doc/ancestor::Enterprise, 'Investor'))
        return
          local:make-row(1, $data, $columns, $status-def, $cache)
      else
        <row>
          <col explicit="No data to export"/>
        </row>
    }
    </root>
};
  
(: MAIN ENTRY POINT :)
let $cmd := oppidum:get-command()
let $m := request:get-method()
let $export-type := request:get-parameter('export', ()) (: 1 for Beneficiary, 2 for Investor :)
let $export := string($cmd/@format) eq 'xlsx' or $export-type = ('1', '2')
               (: uncomment $export-type test to support .xml for debugging :)
return
  if ($export) then
    let $event-def := fn:collection($globals:events-uri)//Event[Id eq tokenize($cmd/@trail, '/')[2]]
    let $access := access:get-entity-permissions('export', 'Events', <Unused/>, $event-def)
    return
      if (local-name($access) eq 'allow') then
        local:handle-export($cmd, ('1', $export-type)[last()])
      else
        $access
  else
    let $enterprise := fn:collection($globals:enterprises-uri)//Enterprise[Id eq tokenize($cmd/@trail, '/')[2]]
    let $event-def := fn:collection($globals:events-uri)//Event[Id eq tokenize($cmd/@trail, '/')[4]]
    (: FIXME: access control against workflow state ? :)
    let $access := access:get-entity-permissions('view', 'Event', $enterprise, $event-def)
    return
      if (local-name($access) eq 'allow') then
        (: FIXME: check POST with access:check-tab-permissions for 'update' ? :)
        if ($m eq 'POST') then
          let $submitted := oppidum:get-data()
          return
            let $data := local:clean-data($submitted, $event-def, $enterprise)
            return 
              if (local-name($data) ne 'error') then
                local:save-data($cmd, $enterprise, $event-def, $data)
              else
                $data
        else
          local:load-data($cmd, $enterprise, $event-def)
      else
        $access

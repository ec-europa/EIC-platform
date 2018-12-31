xquery version "1.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Batch importation of Call beneficiaries

   DEPRECATED: see modules/calls/import.xql for direct import from .xlsx file

   Currently can translate two versions of Excel column names
   which are detected with the name used for the project ID

   PARAMETERS
   - batch : file name in /db/batch to import
   - max : max number of cases to import
   - action : type of execution, dry (no side effect), run (creates enterprises
     and cases, skips existing), force (creates enterprises and cases, overwrites
     existing ones), assert (reports MISSING elements), diff (reports differences
     in duplicated enterprises)
   - id : project ID to import

   TODO:
   - REWRITE ENTERPRISE GENERATION to be directly stored inside the Case !

   January 2015 - (c) Copyright may be reserved
   ------------------------------------------------------------------ :)

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace cases = "http://oppidoc.fr/ns/ctracker/cases" at "case.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace cache = "http://oppidoc.com/ns/cctracker/cache" at "../../lib/cache.xqm";
import module namespace compat = "http://oppidoc.com/oppidum/compatibility" at "../../../oppidum/lib/compat.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Diff algorithm functional for enterprise models
   Only diffs terminal nodes and not attributes
   ======================================================================
:)
declare function local:diff-enterprises( $e1 as element(), $e2 as element() ) as element()* {
  let $nodeset := $e1//*[count(./*) eq 0]
  return (
    for $n in $nodeset
    let $name := local-name($n)
    let $match := $e2//*[local-name(.) eq $name]
    where $name ne 'Id'
    return
      if (string($match) ne string($n)) then
        element { $name } {
          (
          <old>{string($n)}</old>,
          <new>{string($match)}</new>
          )
        }
      else
        (),
    let $names := for $n in $nodeset return local-name($n)
    return
      for $n in $e2//*[(count(./*) eq 0) and not(local-name(.) = $names)]
      return
        element { local-name($n) } {
          (
          <old></old>,
          <new>{string($n)}</new>
          )
        }
    )
};

declare function local:gen-opt-element( $e as element()?, $tag as xs:string ) as element()? {
  if ($e and ($e/text() ne '') and ($e/text() ne 'N/A')) then
    element { $tag } {
      $e/text()
    }
  else
    ()
};

declare function local:gen-opt-element( $e as element()?, $satellite as element()?, $tag as xs:string ) as element()? {
  if ($e and ($e/text() ne '') and ($e/text() ne 'N/A')) then
    element { $tag } {
      if ($satellite and ($satellite/text() ne '')) then
        concat($e/text(), ' (', $satellite/text(), ')')
      else
        $e/text()
    }
  else
    ()
};

declare function local:gen-creation-year( $data as element()? ) {
  if ($data) then
    <CreationYear _Source="{ $data/text() }">{ substring($data, 1, 4) }</CreationYear>
  else
    ()
};

(: ======================================================================
   TODO: automatize tests from global-information
   ======================================================================
:)
declare function local:gen-size( $data as element()? ) {
  if ($data and ($data castable as xs:integer)) then
    <SizeRef _Source="{ $data/text() }">
      {
      let $size := number($data)
      return
        if ($size < 10) then
          '1'
        else if ($size < 50) then
          '2'
        else if ($size < 250) then
          '3'
        else
          '4'
      }
    </SizeRef>
  else
    ()
};

declare function local:gen-nace( $data as element()?, $assert as xs:boolean ) {
  if ($data) then
    let $nace := fn:collection($globals:global-info-uri)//Description[@Lang = 'en']/Selector[@Name = 'DomainActivities']//Option[ends-with(Code/text(), $data/text())]
    return
      if ($nace) then
        <DomainActivityRef _Source="{ $data/text() }">{ $nace/Code/text() }</DomainActivityRef>
      else if ($assert) then
        <MISSING Name="DomainActivity">{ $data/text() }</MISSING>
      else
        ()
  else
    ()
};

declare function local:gen-project-officer( $data as element()?, $assert as xs:boolean ) {
  if ($data) then
    let $po := fn:collection($globals:persons-uri)//Person[@PersonId eq $data/text()]
    return
      if ($po) then
        <ProjectOfficerRef>{ $po/Id/text() }</ProjectOfficerRef>
      else if ($assert) then
        <MISSING Name="ProjectOfficer">{ $data/text() }</MISSING>
      else
        ()
  else
    ()
};

(: ======================================================================
   Converts an EC Excel Topic code into a database TopicRef code
   ======================================================================
:)
declare function local:gen-topic-for( $code as xs:string?, $assert as xs:boolean ) {
  if ($code) then
    let $KEY := upper-case($code)
    let $option := fn:collection($globals:global-info-uri)/GlobalInformation/Description[@Lang = 'en']//Selector[@Name eq 'Topics']/Option[starts-with($KEY, upper-case(./ShortName/text()))]
    return
      if ($option) then
        <CallTopics>
          <TopicRef>{ $option/Id/text() }</TopicRef>
        </CallTopics>
      else if ($assert) then
        <MISSING Name="CallTopic">{ $code }</MISSING>
      else
        ()
  else
    ()
};

(: ======================================================================
   Pre-assigns EEN entity into ManagingEntity
   TODO:
   - to be do in a second pass (with e-mail sending) in importer/een-assigner.xql
   { local:gen-managing-entity-for( $row/EEN_Consortium_name/text(), $row/KAM_coordinator_email/text() ) }
   ======================================================================
:)
declare function local:gen-managing-entity-for( $een-name as xs:string?, $coord-email as xs:string? ) {
  if ($een-name and ($een-name ne '')) then
    let $KEY := upper-case($een-name)
    let $option := fn:collection($globals:regions-uri)//Region[starts-with($KEY, upper-case(./Acronym/text()))]
    return
      if (count($option) = 1) then
        <ManagingEntity>
          <RegionalEntityRef>{ $option/Id/text() }</RegionalEntityRef>
          <AssignedByRef>import</AssignedByRef>
          <Date>{ current-dateTime() }</Date>
        </ManagingEntity>
      else
        ()
  else
    ()
};

(: ======================================================================
   Converts an EC full Excel country name into a database Country code
   ======================================================================
:)
declare function local:gen-country-code-for( $country as xs:string, $assert as xs:boolean ) {
  let $option := fn:collection($globals:global-info-uri)/GlobalInformation/Description[@Lang = 'en']//Selector[@Name eq 'Countries']/Option[CountryName eq $country]
  return
    if ($option) then
      <Country>{ $option/CountryCode/text() }</Country>
    else if ($assert) then
      <MISSING Name="Country">{ $country }</MISSING>
    else
      ()
};

(: ======================================================================
   Turns a row into a project XML model for importation
   ======================================================================
:)
declare function local:gen-project( $row as element(), $assert as xs:boolean ){
  <Project>
    <Case ProjectId="{ $row/Project_Number/text() }">
      <Title>{ $row/Project_Title/text() }</Title>
      <Acronym>{ $row/Project_Acronym/text() }</Acronym>
      { local:gen-topic-for( $row/Eval_Panel_Name/text(), $assert ) }
      { if ($row/Abstract[. ne '']) then local:textualize($row/Abstract, "Summary") else () }
      {
      if ($row/Project_Duration[. ne '']) then
        <Contract><Duration>{ $row/Project_Duration/text() }</Duration></Contract>
      else
        ()
      }
      { local:gen-project-officer($row/PO_ID, $assert)  }
      <ContactPerson>
        { if ($row/Contact_Gender[. ne '']) then <Sex>{ substring($row/Contact_Gender, 1, 1) }</Sex> else () }
        { local:gen-opt-element($row/Contact_Title, 'Civility') }
        <Name>
          <FirstName>{ $row/Contact_First_Name/text() }</FirstName>
          <LastName>{ $row/Contact_Last_Name/text() }</LastName>
        </Name>
        <Contacts>
          { local:gen-opt-element($row/Contact_Phone1, 'Phone') }
          { local:gen-opt-element($row/Contact_Phone2, 'Mobile') }
          <Email>{ $row/Contact_Email/text() }</Email>
        </Contacts>
        { local:gen-opt-element($row/Contact_Position, $row/Contact_Department, 'Function') }
      </ContactPerson>
    </Case>
    <Enterprise EnterpriseId="{ $row/Participant_PIC/text()}">
      <Name>{ $row/Participant_Legal_Name/text() }</Name>
      <ShortName>{ $row/Participant_Short_Name/text() }</ShortName>
      { local:gen-creation-year($row/Legal_Registration_Date[. ne '']) }
      { local:gen-size($row/Nbr_Of_Employees[. ne '']) }
      { local:gen-nace($row/Nace[. ne ''], $assert) }
      { local:gen-opt-element($row/WebSite, 'WebSite') }
      <Address>
        <StreetNameAndNo>{ $row/Contact_Street/text() }</StreetNameAndNo>
        <Town>{ $row/Contact_City/text() }</Town>
        <PostalCode>{ $row/Contact_Postal_Code/text() }</PostalCode>
        { local:gen-country-code-for( $row/Country_Name/text(), $assert ) }
      </Address>
    </Enterprise>
  </Project>
};

(: ======================================================================
   Turns an EC Excel raw XML row into a project XML
   Legacy versino for 2014-06-18.xml
   DEPRECATED
   ======================================================================
:)
declare function local:gen-project_v1( $row as element() ){
  <Project>
    <Case ProjectId="{ $row/Project_Number/text() }">
      <Title>{ $row/Project_Title/text() }</Title>
      <Acronym>{ $row/Project_Acronym/text() }</Acronym>
      { local:gen-topic-for( $row/Project_Topic_Code/text(), false() ) }
      { if (count($row/Abstract/Text) > 0) then <Summary>{ $row/Abstract/Text }</Summary> else () }
      <ContactPerson>
        {
        if ($row/Appl_Main_Pers_Title eq 'Mr.') then
          <Sex>M</Sex>
        else if ($row/Appl_Main_Pers_Title eq 'Mrs') then
          <Sex>F</Sex>
        else
          ()
        }
        <Name>
          <FirstName>{ $row/Appl_Main_Pers_First_Name/text() }</FirstName>
          <LastName>{ $row/Appl_Main_Pers_Last_Name/text() }</LastName>
        </Name>
        <Civility>{ $row/Appl_Main_Pers_Title/text() }</Civility>
        <Contacts>
          <Email>{ $row/Appl_Main_Pers_Email/text() }</Email>
        </Contacts>
      </ContactPerson>
    </Case>
    <Enterprise EnterpriseId="{ $row/Participant_PIC/text()}">
      <Name>{ $row/Participant_Legal_Name/text() }</Name>
      <ShortName>{ $row/Participant_Short_Name/text() }</ShortName>
      { local:gen-opt-element($row/Applicant_Web_Page, 'WebSite') }
      <Address>
        <StreetNameAndNo>{ $row/Applicant_Street/text() }</StreetNameAndNo>
        <Town>{ $row/Applicant_City/text() }</Town>
        { local:gen-country-code-for( $row/Applicant_Country_Name/text(), false() ) }
      </Address>
    </Enterprise>
  </Project>
};

(: ======================================================================
   Turns an EC Excel raw XML row into a project XML
   FIXME:
   - gender
   DEPRECATED
   ======================================================================
:)
declare function local:gen-project_v2( $row as element() ){
  <Project>
    <Case ProjectId="{ $row/Proposal_Number/text() }">
      <Title>
        {
        if ($row/Project_Title/text()) then
          $row/Project_Title/text()
        else
          $row/Proposal_Acronym/text()
        }
      </Title>
      <Acronym>{ $row/Proposal_Acronym/text() }</Acronym>
      { local:gen-topic-for( $row/Topic/text(), false() ) }
      {
      if ($row/Proposal_Duration[. ne '']) then
        <Contract><Duration>{ $row/Proposal_Duration/text() }</Duration></Contract>
      else
        ()
      }
      <ContactPerson>
        { if ($row/Gender[. ne '']) then <Sex>{ substring($row/Gender, 1, 1) }</Sex> else () }
        <Name>
          <FirstName>{ $row/Contact_First_Name/text() }</FirstName>
          <LastName>{ $row/Contact_Surname/text() }</LastName>
        </Name>
        <Contacts>
          <Email>{ $row/Email/text() }</Email>
          { local:gen-opt-element($row/Telephone, 'Phone') }
        </Contacts>
        { local:gen-opt-element($row/Department, 'Function') }
      </ContactPerson>
      { local:gen-managing-entity-for( $row/EEN_Consortium_name/text(), $row/KAM_coordinator_email/text() ) }
    </Case>
    <Enterprise EnterpriseId="{ $row/PIC/text()}">
      <Name>{ $row/Business_Name/text() }</Name>
      <ShortName>{ $row/Legal_Name/text() }</ShortName>
      { local:gen-opt-element($row/Applicant_Web_Page, 'WebSite') }
      <Address>
        <StreetNameAndNo>{ $row/Address/text() }</StreetNameAndNo>
        <Town>{ $row/City/text() }</Town>
        <PostalCode>{ $row/Postal_Code/text() }</PostalCode>
        <Country>{ $row/Country/text() }</Country>
      </Address>
    </Enterprise>
  </Project>
};

(: ======================================================================
   Transforms the EC Excel row XML file into an internal XML pivot format
   which is used to generate the enterprises and cases to import
   TODO :
   - parameterize Call data
   - show projects with several partners if any
   ======================================================================
:)
declare function local:gen-patch( $batch-uri, $max as xs:integer?, $pid as xs:string?, $assert as xs:boolean ) {
  let $id := if (fn:doc(concat('/db/batch/', $batch-uri))//Project_Number) then 'Project_Number' else 'Proposal_Number'
  let $projects :=
    if ($pid) then
      fn:doc(concat('/db/batch/', $batch-uri))//row[*[local-name(.) eq $id] eq $pid]
    else
      if ($max) then
        fn:doc(concat('/db/batch/', $batch-uri))//row[position() < $max]
      else
        fn:doc(concat('/db/batch/', $batch-uri))//row
  return
    <Projects>
      { fn:doc(concat('/db/batch/', $batch-uri))/*/Call }
      {
      for $d in distinct-values($projects/*[local-name(.) eq $id]/text())
      where count($projects[*[local-name(.) eq $id] eq $d]) = 1 (: de-duplicates rows :)
      return
        local:gen-project($projects[Project_Number eq $d][1], $assert)
(:        if ($id eq 'Project_Number') then
          local:gen-project_v1($projects[Project_Number eq $d][1])
        else
          local:gen-project_v2($projects[Proposal_Number eq $d][1]):)
      }
    </Projects>
};

(: ======================================================================
   Inserts a new enterprise record into the database

   See also gen-enterprise-for-writing in enterprise.xql
   ======================================================================
:)
declare function local:import-enterprise( $enterprise as element(), $action as xs:string ) {
  let $newkey :=
    max(for $key in fn:doc($globals:enterprises-uri)/Enterprises/Enterprise/Id
        return if ($key castable as xs:integer) then number($key) else 0) + 1
  let $data := <Enterprise EnterpriseId="{$enterprise/@EnterpriseId}">
                 <Id>{ $newkey }</Id>
                 { $enterprise/* }
               </Enterprise>
  return (
    if ($action = ('run', 'force')) then
      update insert $data into fn:doc($globals:enterprises-uri)/Enterprises
    else
      (),
    (:local:cache-invalidate(('enterprise', 'town'), 'en'),:)
    $newkey
    )[last()]
};

declare function local:replace-enterprise( $enterprise as element(), $id as element() ) {
  let $data := <Enterprise EnterpriseId="{$enterprise/@EnterpriseId}">
                 <Id>{ $id/text() }</Id>
                 { $enterprise/* }
               </Enterprise>
  return
    update replace fn:doc($globals:enterprises-uri)//Enterprise[Id eq $id/text()] with $data
};

(: ======================================================================
   Turns a case in patch model into a case record for database insertion
   ======================================================================
:)
declare function local:gen-case-for-writing(
  $case as element(),
  $call as element(),
  $enterprise as element(),
  $case-no as xs:string
   )
{
  let $now := current-dateTime()
  let $date :=  substring(string($now),1,10)
  return
    <Case ProjectId="{$case/@ProjectId}">
      <No>{ $case-no }</No>
      <CreationDate>{ $date }</CreationDate>
      <StatusHistory>
        <CurrentStatusRef>1</CurrentStatusRef>
        <Status>
          <Date>{ $date }</Date>
          <ValueRef>1</ValueRef>
        </Status>
      </StatusHistory>
      <Information LastModification="{ $now }">
        {(
        $case/(Title | Acronym),
        $case/Summary,
        <Call>
          {
          $call/*,
          $case/CallTopics
          }
        </Call>,
        $case/Contract,
        $case/ProjectOfficerRef,
        <ClientEnterprise>
					{ $enterprise/(@* | *) }
        </ClientEnterprise>,
        $case/ContactPerson
        )}
      </Information>
    </Case>
};

(: ======================================================================
   Inserts a new Case into the databse
   Currently the target Collection is based on the current Year cases/YYYY
   ======================================================================
:)
declare function local:import-case( $case as element(), $call as element(), $enterprise as element(), $action as xs:string ) {
  let $case-refs := cases:create-case-collection($call/Date/text())
  let $case-uri := $case-refs[1]
  let $case-no := $case-refs[2]
  return
    if (not(empty($case-refs))) then
      let $data := local:gen-case-for-writing($case, $call, $enterprise, $case-no)
      let $stored-path := if ($action = 'dry') then concat($case-uri, "/case.xml") else xdb:store($case-uri, "case.xml", $data)
      return
        if(not($stored-path eq ())) then (
          if ($action = ('run', 'force')) then
            compat:set-owner-group-permissions(concat($case-uri, '/', "case.xml"), 'admin', 'users', "rwxrwxr-x")
          else
            (),
          <p>Created case { $case/Acronym/text() } as <a href="../cases/{ $case-no }">{ $case-no }</a> into { $case-uri }</p>
          )
        else
          <p>Failed to store case { $case/Acronym/text() } with project Id { string($case/@ProjectId) } into { $case-uri }</p>
    else
      <p>Failed to create container for case { $case/Acronym/text() } with project Id { string($case/@ProjectId) } into { $case-uri }</p>
};

(: ======================================================================
   Replaces a case.xml resource file with a fresh generated Case
   ======================================================================
:)
declare function local:replace-case( $patch as element(), $call as element(), $enterprise as element(), $case as element() ) {
  let $data := local:gen-case-for-writing( $patch, $call, $enterprise, string($case/No))
  let $case-col-uri := util:collection-name($case)
  let $case-uri := concat($case-col-uri, '/case.xml')
  return
    let $stored-path := xdb:store($case-col-uri, "case.xml", $data)
    return
      if(not($stored-path eq ())) then (
        compat:set-owner-group-permissions(concat($case-col-uri, '/', "case.xml"), 'admin', 'users', "rwxrwxr-x"),
        <p>Replaced case { $data/Acronym/text() } at { $case-uri }</p>
        )
      else
        <p>Failed to replace case { $case/Acronym/text() } at { $case-uri }</p>
};

(: ======================================================================
   Batch imports a set of Cases described in the internal XML pivot format
   into the database, for each case it imports the client enterprise
   Avoids duplicitas by checking the EC project number and the EC enterprise PIC number
   which are also preserved in the Case Tracker database
   The last parameter dry allows to run a dry run without importing any data
   (in which case the generated case identifiers and enterprise identifiers are not incremented )
   ======================================================================
:)
declare function local:import( $set as element()*, $call as element(), $action as xs:string ) {
 <ul>
 {
 for $project in $set
 return
   <li>
     {
     let $case := fn:collection($globals:cases-uri)//Case[@ProjectId eq $project/Case/@ProjectId]
     return
      if ($case) then (: case already exists :)
        if ($action eq 'force') then 
					(
          if ($case/Information/ClientEnterprise/@EnterpriseId eq string($project/Enterprise/@EnterpriseId)) then
            <p>Case already exists with enterprise with same PIC { string($project/Enterprise/@EnterpriseId) } ({ $case/Information/ClientEnterprise/ShortName/text() } / { $project/Enterprise/ShortName/text() })</p>
          else
						<p>Case already exists with enterprise with different PIC { string($case/ClientEnterprise/@EnterpriseId) } instead of { string($project/Enterprise/@EnterpriseId) } ({ $case/Information/ClientEnterprise/ShortName/text() } / { $project/Enterprise/ShortName/text() })</p>,
          <p>Force re-importation of project { $case/Acronym/text() } with Id { string($case/@ProjectId) } because it already exists as case <a href="../cases/{$case/No}">{$case/No/text()}</a></p>,
					(: FIXME: we could set a flag to overwrite or not enterprise data :)
          local:replace-case($project/Case, $call, $project/Enterprise, $case)
          )
        else
          <p>Skip creation of project {$project/Case/Acronym/text()} with Id {string($project/Case/@ProjectId)} because it already exists as case <a href="../cases/{$case/No}">{$case/No/text()}</a></p>
      else  (: new case :)
	      let $e := fn:collection($globals:cases-uri)//Information/ClientEnterprise[@EnterpriseId = $project/Enterprise/@EnterpriseId]
	      return
					(
	        if ($e) then
	          <p>Create an extra project {$project/Case/Acronym/text()} for { $project/Enterprise/ShortName/text() } with PIC { string($project/Enterprise/@EnterpriseId) }</p>
	        else
	          <p>Create a first project {$project/Case/Acronym/text()} for { $project/Enterprise/ShortName/text() } with PIC { string($project/Enterprise/@EnterpriseId) }</p>,
	        local:import-case($project/Case, $call, $project/Enterprise, $action)
	      	)
     }
   </li>
 }
 </ul>
};

(: ======================================================================
   Turns node with text() content into node with <Text> content splitted by line return
   ======================================================================
:)
declare function local:textualize( $node as item(), $tag as xs:string? ) as item() {
  element { if ($tag) then $tag else local-name($node) }
    {
      for $text in tokenize($node/text(), '\n')
      where $text ne ''
      return
        <Text>{ $text }</Text>
    }
};

(: ======================================================================
   Inserts a column from a row file inside a batch
   WARNING: it uses column names as is (no Abstract to Summary conversion) !!!
   ======================================================================
:)
declare function local:insert( $batch-uri as xs:string, $key as xs:string, $row-uri as xs:string, $field-name as xs:string ) {
  <ul>
    {
    for $row in fn:doc($row-uri)//row
    let $name := $row/*[local-name(.) eq $key]/text()
    let $project := fn:doc($batch-uri)//Project[*[local-name(.) eq $key] eq $name]
    let $column := $row/*[local-name(.) eq $field-name]
    let $legacy := $project/*[local-name(.) eq $field-name]
    return
      if ($column) then
        if ($project) then
          if ($legacy) then
            (
            update replace $legacy with local:textualize($column, ()),
            <li>Replaced { $field-name } in { $name }</li>
            )
          else
            (
            update insert local:textualize($column, ()) into $project,
            <li>Inserted { $field-name } in { $name }</li>
            )
        else
          <li>Missing { $key } in { $name }</li>
      else
        <li>Missing column { $field-name } for { $key } in { $name }</li>
    }
  </ul>
};

(: ======================================================================
   Compares enterprises in set enterprises in database and shows differences
   ======================================================================
:)
declare function local:diff( $set as element()*, $call as element(), $action as xs:string ) as element()* {
  for $project in $set
  let $e := fn:doc($globals:enterprises-uri)/Enterprises/Enterprise[@EnterpriseId = $project/Enterprise/@EnterpriseId]
  return
    if ($e) then
      let $diff := local:diff-enterprises($e, $project/Enterprise)
      return
        if (count($diff) > 0) then
          <Diff Name="{$e/Name}" Id="{$e/Id}" PIC="{$e/@EnterpriseId}">
            { $diff }
          </Diff>
        else
          <Same Id="{$e/Id}" PIC="{$e/@EnterpriseId}"/>
    else
      ()
};

let $batch-uri := request:get-parameter('batch', ())
let $tmp := request:get-parameter('max', ())
let $max := if ($tmp) then number($tmp) else ()
let $action := request:get-parameter('action', 'dry')
let $id := request:get-parameter('id', ())
return
  if (false()) then
    (: hack to add a column to a batch file  :)
    local:insert("/db/batch/2014-06-18.xml", "Project_Acronym", "/db/batch/2014-06-18-abstract.xml", "Abstract")
  else
    if ($batch-uri) then
      if ($action eq 'officers') then
        <Missings>
          {
          let $truth := distinct-values(fn:collection($globals:persons-uri)//Person[.//FunctionRef[. eq '12']]/@PersonId)
          return 
            for $x in distinct-values(fn:doc(concat('/db/batch/', $batch-uri))//PO_ID/text())
            where not($x = $truth)
            return <PersonId>{ $x }</PersonId>
          }
        </Missings>
      else
        let $projects := local:gen-patch($batch-uri, $max, $id, $action eq 'assert')
        return
          if ($action = ('patch', 'assert')) then
            $projects
          else if ($action eq 'diff') then
            let $res :=
              if ($max) then
                local:diff(($projects//Project)[position() <  $max], $projects/Call, $action)
              else
                local:diff(($projects//Project), $projects/Call, $action)
            return
              <DuplicateEnterprises Duplicated="{count($res[local-name(.) eq 'Diff'])}" Total="{count($res)}">
                { $res }
              </DuplicateEnterprises>
          else (: assumes :)
            (
            util:declare-option("exist:serialize", "method=html5 media-type=text/html encoding=utf-8 indent=yes"),
            <html><style>p{{margin:0}}</style><body>
              {
              if ($max) then
                local:import(($projects//Project)[position() <  $max], $projects/Call, $action)
              else
                local:import(($projects//Project), $projects/Call, $action),
                if ($action = ('run', 'force')) then
                  for $cache in ('beneficiary', 'acronym')
                  return
                    if (fn:doc($globals:cache-uri)/Cache/Entry[@Id eq $cache][@lang eq 'en']) then (
                      cache:invalidate($cache, 'en'),
                      <p>Invalidate cache for { $cache }</p>
                      )
                    else
                      <p>No cache for { $cache }</p> 
                else
                  ()
              }
            </body></html>
            )
    else (
      util:declare-option("exist:serialize", "method=html5 media-type=text/html encoding=utf-8 indent=yes"),
      <html>
        <h1>Usage</h1>
        <ul>
          <li>give the name of the beneficiaries to import as a <i>batch</i> parameter</li>
          <li>add an <i>action</i> parameter with values :
            <ul>
              <li><i>officers</i> to assert MISSING project officers</li>
              <li><i>patch, assert, dry or run</i> and optionaly a <i>max</i> number of cases to handle; use <i>id</i> to target a specific case by project ID</li>
            </ul>
          </li>
        </ul>
      </html>
      )

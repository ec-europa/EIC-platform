xquery version "1.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Authors: Stéphane Sire <s.sire@opppidoc.fr>
            Frédéric Dumonceaux <Frederic.DUMONCEAUX@ext.ec.europa.eu>

   Automatic Case import utility

   Imports Cases from an Excel file

   Pre-condition: 
   - edit $local:mapping to fit Excel column names
   - in case of multiple beneficiaries be sure to have an Applicant Role 
     column with a single Coordinator

   February 2017 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace response="http://exist-db.org/xquery/response";
import module namespace compression="http://exist-db.org/xquery/compression";
import module namespace util="http://exist-db.org/xquery/util";
import module namespace xdb="http://exist-db.org/xquery/xmldb";

declare namespace ms = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace compat = "http://oppidoc.com/oppidum/compatibility" at "../../../oppidum/lib/compat.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace ajax = "http://oppidoc.com/oppidum/ajax" at "../../lib/ajax.xqm";
import module namespace display = "http://oppidoc.com/oppidum/display" at "../../lib/display.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "../../lib/util.xqm";
import module namespace assign = "http://oppidoc.com/ns/cctracker/assign" at "assign.xqm";
import module namespace alert = "http://oppidoc.com/ns/cctracker/alert" at "../workflow/alert.xqm";
import module namespace workflow = "http://platinn.ch/coaching/workflow" at "../workflow/workflow.xqm";
import module namespace media = "http://oppidoc.com/ns/cctracker/media" at "../../lib/media.xqm";
import module namespace check = "http://oppidoc.com/ns/cctracker/check" at "../../lib/check.xqm";
import module namespace account = "http://platinn.ch/coaching/account" at "../users/account.xqm";
import module namespace excel = "http://oppidoc.com/oppidum/excel" at "../../lib/excel.xqm";
import module namespace cache = "http://oppidoc.com/ns/cctracker/cache" at "../../lib/cache.xqm";
import module namespace cases = "http://oppidoc.fr/ns/ctracker/cases" at "../cases/case.xqm";

(: ======================================================================
   
   ======================================================================
:)
declare variable $local:meta-call :=
  <Meta>
    <Entry Position="1">
      <Src>Proposal Call Id</Src>
      <Dest Eval="tokenize($src, '-')[3]">PhaseRef</Dest>
    </Entry>
    <Entry Position="2">
      <Src>Proposal Call Deadline Date</Src>
      <Dest Eval="xs:date('1899-12-30') + xs:dayTimeDuration(concat('P', $src ,'D'))">Date</Dest>
    </Entry>
  </Meta>;

(: ======================================================================
   pre-condition: define a single @Key='1' column
   ======================================================================
:)
declare variable $local:mapping :=
  <Mapping SheetName="sheet2.xml">
    <Entry>
      <Src>Eval Panel Name</Src>
      <Dest Eval="replace($src, '([a-zA-Z]+)-(\d&#123;1&#125;)-(\d&#123;2&#125;)-(\d&#123;4&#125;)-(\d&#123;4&#125;)', '$1-$3-$4-$5')">Topic</Dest>
    </Entry>
    <Entry Key="1">
      <Src>Proposal Number</Src>
      <Dest Attr="1">Project_Number</Dest>
    </Entry>
    <Entry>
      <Src>Proposal Acronym</Src>
      <Dest>Project_Acronym</Dest>
    </Entry>
    <Entry>
      <Src>Proposal Title</Src>
      <Dest Text="1">Project_Title</Dest>
    </Entry>
    <Entry>
      <Src>Proposal Abstract</Src>
      <Dest Text="1">Abstract</Dest>
    </Entry>
    <Entry>
      <Src>Project Duration</Src>
      <Dest>Project_Duration</Dest>
    </Entry>
    <Entry>
      <Src>[PP] Core Country Name</Src>
      <Dest>Country_Name</Dest>
    </Entry>
    <Entry>
      <Src>Applicant Legal Name</Src>
      <Dest>Participant_Legal_Name</Dest>
    </Entry>
    <Entry>
      <Src>Applicant Short Name</Src>
      <Dest>Participant_Short_Name</Dest>
    </Entry>
    <Entry>
      <Src>Applicant PIC</Src>
      <Dest>Participant_PIC</Dest>
    </Entry>
    <Entry>
      <Src>Applicant Web Page</Src>
      <Dest>WebSite</Dest>
    </Entry>
    <Entry>
      <Src>[PP] Core Legal Registration Date</Src>
      <Dest Eval="xs:date('1899-12-30') + xs:dayTimeDuration(concat('P', floor($src) ,'D'))">Legal_Registration_Date</Dest>
    </Entry>
    <Entry>
      <Src>Number of Employees</Src>
      <Dest>Nbr_Of_Employees</Dest>
    </Entry>
    <Entry>
      <Src>Applicant Street</Src>
      <Dest>Contact_Street</Dest>
    </Entry>
    <Entry>
      <Src>Applicant Postal Code</Src>
      <Dest>Contact_Postal_Code</Dest>
    </Entry>
    <Entry>
      <Src>Applicant City</Src>
      <Dest>Contact_City</Dest>
    </Entry>
    <Entry>
      <Src>Appl Main Pers Title</Src>
      <Dest>Contact_Title</Dest>
    </Entry>
    <Entry>
      <Src>Appl Main Pers First Name</Src>
      <Dest>Contact_First_Name</Dest>
    </Entry>
    <Entry>
      <Src>Appl Main Pers Last Name</Src>
      <Dest>Contact_Last_Name</Dest>
    </Entry>
    <Entry>
      <Src>Appl Main Pers Gender</Src>
      <Dest>Contact_Gender</Dest>
    </Entry>
    <Entry>
      <Src>Appl Main Pers Position</Src>
      <Dest>Contact_Position</Dest>
    </Entry>
    <Entry>
      <Src>Appl Main Pers Department</Src>
      <Dest>Contact_Department</Dest>
    </Entry>
    <Entry>
      <Src>Appl Main Pers Email</Src>
      <Dest>Contact_Email</Dest>
    </Entry>
    <Entry>
      <Src>Appl Main Pers Phone</Src>
      <Dest>Contact_Phone1</Dest>
    </Entry>
    <Entry>
      <Src>EC Project Officer Login</Src>
      <Dest>PO_ID</Dest>
    </Entry>
    <Entry>
      <Src>Applicant Role</Src>
      <Dest>Applicant_Role</Dest>
    </Entry>    
  </Mapping>;

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

declare function local:gen-project-officer( $data as element()?, $assert as xs:boolean ) {
  if ($data) then
    let $po := fn:collection($globals:persons-uri)//Person[@PersonId eq $data or UserProfile/Remote[. eq $data and @Name eq 'ECAS']]
    let $remotes := fn:doc('/db/sites/cctracker/persons/remotes.xml')/Remotes
    return
      if ($po or $remotes/Remote[Key/text() eq $data/text()]) then
        <ProjectOfficerRef>{ $po/Id/text() }</ProjectOfficerRef>
      else if ($assert) then
        (
        update insert 
          <Remote>
            <Name>{$data/text()}</Name>
            <Key>{$data/text()}</Key>
            <Realm>ECAS</Realm>
            <UserProfile><Roles><Role><FunctionRef>12</FunctionRef></Role></Roles></UserProfile>
          </Remote>
        into $remotes,
        <MISSING Name="ProjectOfficer">{ $data/text() }</MISSING>
        )[last()]
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
   Turns a row into a project XML model for importation
   ======================================================================
:)
declare function local:gen-project( $row as element(), $assert as xs:boolean ){
  if ($assert) then
    <Project>
    {
      local:gen-topic-for( $row/Topic/text(), $assert ),
      local:gen-project-officer($row/PO_ID, $assert),
      local:gen-country-code-for( $row/Country_Name/text(), $assert )
    }
    </Project>
  else
  <Project>
    <Case ProjectId="{ $row/Project_Number/text() }">
      <Title>{ $row/Project_Title/text() }</Title>
      <Acronym>{ $row/Project_Acronym/text() }</Acronym>
      { local:gen-topic-for( $row/Topic/text(), $assert ) }
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
   
   ======================================================================
:)
declare function local:escape-for-regex( $arg as xs:string? )  as xs:string {
  replace($arg,'(\.|\[|\]|\\|\||\-|\^|\$|\?|\*|\+|\{|\}|\(|\))','\\$1')
} ;

(: ======================================================================
   
   ======================================================================
:)
declare function local:substring-before-last( $arg as xs:string?, $delim as xs:string ) as xs:string {
  if (matches($arg, local:escape-for-regex($delim))) then 
    replace($arg, concat('^(.*)', local:escape-for-regex($delim),'.*'), '$1')
  else
    ''
};

(: ======================================================================
   
   ======================================================================
:)
declare function local:substring-after-last( $arg as xs:string?, $delim as xs:string ) as xs:string {
 replace($arg, concat('^.*', local:escape-for-regex($delim)),'')
};

(: ======================================================================
   Process each extracted xml files from a zip package
   ======================================================================
:)
declare function local:entry-data($path as xs:anyURI, $type as xs:string, $data as item()?, $param as item()*) as item()?
{
  system:as-user(account:get-secret-user(), account:get-secret-password(),
    if ($param[@name eq 'list']/@value eq 'true') then
      <entry>
        <path>{$path}</path>
        <type>{$type}</type>
      </entry>
    else
      let $base-collection := $param[@name="base-collection"]/@value/string()
      let $zip-collection := 
        concat(
          local:substring-before-last($param[@name="zip-filename"]/@value, '.'),
          '_',
          local:substring-after-last($param[@name="zip-filename"]/@value, '.'),
          '_parts/'
        )
      let $inner-collection := local:substring-before-last($path, '/')
      let $filename := if (contains($path, '/')) then local:substring-after-last($path, '/') else $path
      (: we need to encode the filename to account for filenames with illegal characters like [Content_Types].xml :)
      let $filename := xdb:encode($filename)
      let $target-collection := concat($base-collection, $zip-collection, $inner-collection)
      let $mkdir := 
          if (xdb:collection-available($target-collection)) then () 
          else xdb:create-collection($base-collection, concat($zip-collection, $inner-collection))
      let $store := 
          (: ensure mimetype is set properly for .docx rels files :)
          if (ends-with($filename, '.rels')) then 
              xdb:store($target-collection, $filename, $data, 'application/xml')
          else
              xdb:store($target-collection, $filename, $data)
      return 
          <result object="{$path}" destination="{concat($target-collection, '/', $filename)}"/>
  )
};

(: ======================================================================
   Filter only worksheets and string references 
   ======================================================================
:)
declare function local:unzip-entry-filter($path as xs:anyURI, $type as xs:string, $param as item()*) as xs:boolean
{
  fn:contains($path,'worksheets') or fn:ends-with($path, 'sharedStrings.xml')
};

(: ======================================================================
   Create a collection from an excel (Open Xml)
   ======================================================================
:)
declare function local:unzip($zip-filename as xs:string, $action as xs:string) {
  if (not($action = ('list', 'unzip'))) then
    <error>Invalid action</error>
  else
    let $file := util:binary-doc(concat('/db/batch/', $zip-filename))
    let $entry-filter := util:function(QName("local", "local:unzip-entry-filter"), 3)
    let $entry-filter-params := ()
    let $entry-data := util:function(QName("local", "local:entry-data"), 4)
    let $entry-data-params := 
        (
        if ($action eq 'list') then <param name="list" value="true"/> else (), 
        <param name="base-collection" value="/db/batch/"/>,
        <param name="zip-filename" value="{$zip-filename}"/>
        )
    
    (: recursion :)
    let $unzip := compression:unzip($file, $entry-filter, $entry-filter-params, $entry-data, $entry-data-params)
    return
      <results action="{$action}">{$unzip}</results>
};

(: ======================================================================
   Replace all string references by their value in all worksheets
   ======================================================================
:)
declare function local:unreference-strings( $feedback as element() ) {
  let $shared-strings := $feedback//result[ends-with(string(@destination), 'sharedStrings.xml')]/@destination
  let $sheets := $feedback//result[not(ends-with(string(@destination), 'sharedStrings.xml'))]/@destination
  return
    if (doc-available($shared-strings)) then
    (
      for $res in $sheets
      let $sheet := fn:doc($res)
      let $ss := fn:doc($shared-strings)//ms:sst
      return
        for $cell in $sheet//ms:c[ms:v]
        let $deref := excel:cell-string-value($cell, $ss)
        return
          if ($deref eq string($cell/ms:v/text())) then
            ()
          else
            update value $cell/ms:v with $deref,
      system:as-user(account:get-secret-user(), account:get-secret-password(),
        xdb:remove(concat(local:substring-before-last($shared-strings, '/'), '/'), local:substring-after-last($shared-strings, '/'))
      )
    )
    else
      ()
};

(: ======================================================================
   Tries to retrieve the first data row modelling the headers
   ======================================================================
:)
declare function local:look-for-headers( $feedback as element(), $filename as xs:string ) as element() {
  let $main-sheet := $feedback//result[ends-with(string(@destination), $filename)]/@destination
  return
    if (count($main-sheet) eq 0) then
      oppidum:throw-error('IMPORT-TARGET-SHEET-NOT-FOUND', substring(substring-after($filename, 'sheet'), 0, 1))
    else
      let $datasheet := fn:doc($main-sheet)//ms:sheetData
      let $src-count := count($local:mapping//Src)
      let $headersrow := (for $r in $datasheet/ms:row[count(child::ms:c) ge $src-count][position() < 10] return $r)[1]
      return
        if ($headersrow) then
          let $colsname := for $v in $headersrow//ms:v return <name>{$v/text()}</name>
          return
            <headers position="{count($headersrow/preceding-sibling::ms:row) + 1}">
            {
              $colsname
            }
            </headers>
        else
          oppidum:throw-error('IMPORT-NO-HEADERS', ())
};

(: ======================================================================
   Make a match between the data model ($mapping) and the raw data headers 
   ======================================================================
:)
declare function local:compute-index( $mapping as element(), $headers as element()) as element() {
  <Mapping DataBeginsAt="{ number($headers/@position) + 1 }">
  {
    for $e in $mapping//Entry
    let $match := $headers//name[text() eq $e/Src/text()]
    return
      element Entry
      {
        attribute Position { if ($match) then count($headers//name[text() eq $e/Src/text()]/preceding-sibling::name) + 1 else '-1' },
        $e/node()
      }
  }
  </Mapping>
};

(: ======================================================================
   Check that every tag in the model has been properly indexed
   ======================================================================
:)
declare function local:validate-index( $index as element() ) as element()* {
  let $out-of-range := string-join($index//Entry[@Position eq '-1']/Src/text(), ', ')
  return
    if (string-length($out-of-range) eq 0) then
      ()
    else
      oppidum:throw-error('IMPORT-MISMATCHING-HEADERS', $out-of-range)
};

(: ======================================================================
   Inserts a new Case into the databse
   Currently the target Collection is based on the current Year cases/YYYY
   ======================================================================
:)
declare function local:import-case( $case as element(), $call as element(), $enterprise as element() ) {
  let $case-refs := cases:create-case-collection($call/Date/text())
  let $case-uri := $case-refs[1]
  let $case-no := $case-refs[2]
  return
    if (not(empty($case-refs))) then
      let $data := local:gen-case-for-writing($case, $call, $enterprise, $case-no)
      let $stored-path := xdb:store($case-uri, "case.xml", $data)
      return
        let $succ :=
          if(not($stored-path eq ())) then
          (
            system:as-user(account:get-secret-user(), account:get-secret-password(), compat:set-owner-group-permissions(concat($case-uri, '/', "case.xml"), 'admin', 'users', "rwxrwxr-x")),
            'Created'
          )[last()]
          else
            'Failed'
        return
          element { $succ }
          {
            element Ac { $case/Acronym/text() },
            element CaseNo { $case-no },
            element ProjectId { string($case/@ProjectId) },
            element CaseURI { $case-uri }
          }
    else
      element FailedColl
      {
        element Ac { $case/Acronym/text() },
        element ProjectId { string($case/@ProjectId) },
        element CaseURI { $case-uri }
      }
};

(: ======================================================================
   MAIN FUNCTIONS
   ======================================================================
:)

(: ======================================================================
   Batch imports a set of Cases described in the internal XML pivot format
   into the database, for each case it imports the client enterprise
   Avoids duplicitas by checking the EC project number and the EC enterprise PIC number
   which are also preserved in the Case Tracker database
   The last parameter dry allows to run a dry run without importing any data
   (in which case the generated case identifiers and enterprise identifiers are not incremented )
   ======================================================================
:)
declare function local:import( $projects as element()*, $call as element() ) as element()* {
  for $project in $projects
  return
    let $case := fn:collection($globals:cases-uri)//Case[@ProjectId eq $project/Case/@ProjectId]
    return
      if ($case) then (: case already exists :)
        <Skip><Ac>{$project/Case/Acronym/text()}</Ac><Id>{string($project/Case/@ProjectId)}</Id><Former>{$case/No/text()}</Former><Company>{$project/Enterprise/Name/text()}</Company></Skip>
      else  (: new case :)
    let $e := fn:collection($globals:cases-uri)//Information/ClientEnterprise[@EnterpriseId = $project/Enterprise/@EnterpriseId]
    return
      (
        element { if ($e) then 'Extra' else 'First' }
        {
          element Ac {$project/Case/Acronym/text()},
          element Ent { $project/Enterprise/ShortName/text() },
          element PIC { string($project/Enterprise/@EnterpriseId) }
        },
        local:import-case($project/Case, $call, $project/Enterprise)
      )
};

(: ======================================================================
   Transforms the EC Excel row XML file into an internal XML pivot format
   which is used to generate the enterprises and cases to import
   ======================================================================
:)
declare function local:gen-patch( $filename as xs:string, $assert as xs:boolean ) {
  let $key := $local:mapping//Entry[@Key]/Dest/text()
  let $xml := fn:doc(concat('/db/batch/', $filename ,'.xml'))/rows
  return
    <Projects>
      <Call>{$xml/metadata/child::*}</Call>
      {
      for $d in distinct-values($xml/row/*[local-name(.) eq $key]/text())
      return
        let $data := $xml/row[*[local-name(.) eq $key]/text() eq $d]
        return
          if (count($data) eq 1) then
            local:gen-project($data, $assert)
          else if (count($data) > 1) then
            local:gen-project($data[Applicant_Role eq 'Coordinator'], $assert)
          else
            ()
      }
    </Projects>
};

(: ======================================================================
   See above
   Version used to dump a patch for debug purpose
   ======================================================================
:)
declare function local:gen-patch( $row as element()+) {
  let $data:= if (count($row) > 1) then $row[Applicant_Role eq 'Coordinator'] else $row
  return
    <Projects>
      <Call>{$data/preceding-sibling::metadata/child::*}</Call>
      {
      local:gen-project($data, false())
      }
    </Projects>
};

(: ======================================================================
   Build the data model from the worksheet
   ======================================================================
:)
declare function local:build-data( $feedback as element(), $mapping as element(), $filename as xs:string ) as element() {
  let $main-sheet := $feedback//result[ends-with(string(@destination), $filename)]/@destination
  return
    <rows>
      <metadata>
      {
        let $first := fn:doc($main-sheet)//ms:sheetData/ms:row[position() eq number($mapping/@DataBeginsAt)]
        return
          for $e in $local:meta-call/Entry
          let $src := $first/ms:c[position() = number($e/@Position)]/ms:v/text()
          return
            element { $e/Dest/text() } { if ($e/Dest/@Eval) then util:eval($e/Dest/@Eval) else $src }
      }
      </metadata>
      {
      for $datarow in fn:doc($main-sheet)//ms:sheetData/ms:row[position() ge number($mapping/@DataBeginsAt)]
      return
        <row>
        {
          for $e in $mapping/Entry
          let $src := $datarow/ms:c[position() = number($e/@Position)]/ms:v/text()
          return
            element { $e/Dest/text() } {
              if ($e/Dest/@Text) then
                replace($src, '_x000D_', '&#10;')
              else if ($e/Dest/@Eval and $src) then
                util:eval($e/Dest/@Eval)
              else
                $src
            }
        }
        </row>
      } 
    </rows>
};

(: ======================================================================
   Unzip the worksheets and replace all referenced strings by their values
   ======================================================================
:)
declare function local:preprocessing( $filename as xs:string ) {
  let $unzipped := local:unzip($filename, 'unzip')
  let $decoded := system:as-user(account:get-secret-user(), account:get-secret-password(), local:unreference-strings( $unzipped ))
  return
    (
      system:as-user(account:get-secret-user(), account:get-secret-password(),
        xdb:store('/db/batch/', concat('feedback-',$filename,'.xml'), $unzipped, 'application/xml')
      ),
      $unzipped
    )[last()]
};

(: ======================================================================
   Process the targeted worksheet and build the Excel raw XML row data 
   Returns row data
   ======================================================================
:)
declare function local:validate-and-build( $filename as xs:string ) as element() {
  let $unzipped := fn:doc(concat('/db/batch/feedback-', $filename ,'.xml'))/results
  let $headers := local:look-for-headers( $unzipped, string($local:mapping/@SheetName))
  return
    if (local-name($headers) eq 'error') then
      $headers
    else
      let $index := local:compute-index($local:mapping, $headers)
      let $res := local:validate-index($index)
      return 
        if (local-name($res) eq 'error') then
          $res
        else
          local:build-data($unzipped, $index, string($local:mapping/@SheetName))
};

(: ======================================================================
   Writes binary file to target collection
   ======================================================================
:)
declare function local:write-file(
  $col-uri as xs:string,
  $user as xs:string,
  $group as xs:string,
  $filename as xs:string,
  $data as xs:base64Binary,
  $perms as xs:string ) as xs:string?
{
    system:as-user(account:get-secret-user(), account:get-secret-password(),
      if (xdb:store($col-uri, $filename, $data, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')) then (
        compat:set-owner-group-permissions(concat($col-uri, '/', $filename), $user, $group,$perms),
        $filename
        )
      else
        ()
    )
};

(: ======================================================================
   Upload the excel file into the collection /db/batch to be processed 
   ======================================================================
:)
declare function local:upload-file( $col-uri as xs:string, $cmd as element() ) as xs:string {
  (: get uploaded file binary stream :)
  let $data := request:get-uploaded-file-data('xt-file')
  return
    if ($data instance of xs:base64Binary) then
      (: check file binary stream has compatible MIME-TYPE :)
      let $filename := request:get-uploaded-file-name('xt-file')
      (: TODO : check request:get-uploaded-file-size('xt-file') for limit !!! :)
      let $extension := misc:get-extension($filename)
      let $mime-error := misc:check-extension($extension, ('xlsx'))
      return
        if (empty($mime-error)) then
          if (xdb:collection-available($col-uri)) then
            let $res := local:write-file($col-uri, 'admin', 'users', $filename,  $data, "rwxrwxr-x")
            return
              if ($res) then (
                ajax:report-file-plugin-success($res, 201),
                response:set-header('Location', concat($cmd/@base-url, 'import?next=', $filename)))
              else
                ajax:report-file-plugin-error("Error while writing file, please try another one", 500)
          else
            ajax:report-file-plugin-error(concat("Server failed to create collection ", $col-uri, " to store image"), 500)
          (: TBD: update experiences  :)
        else
          ajax:report-file-plugin-error($mime-error, 400)
    else
      ajax:report-file-plugin-error("Invalid file : not a binary file", 400)
};

(: ======================================================================
   Returns all collections related to an unpackaged Excel file to avoid 
   renewing a complete cycle (unpackaging, unreferencing)
   ======================================================================
:)
declare function local:get-unzipped-batches() as element()* {
  let $coll := '/db/batch'
  return
    for $child in xdb:get-child-collections($coll)
    where 'xl' = xdb:get-child-collections(concat($coll,'/',$child)) and 'worksheets' = xdb:get-child-collections(concat($coll,'/',$child, '/xl'))
    return
      let $has-sss := 'sharedStrings.xml' = xdb:get-child-resources(concat($coll,'/',$child))
      return
        let $fn := concat(fn:substring-before($child, '_xlsx'), '.xlsx')
        return
          <Unzipped Deref="{$has-sss}">{$fn}</Unzipped>
};

(: ======================================================================
   MAIN ENTRY POINT
   ======================================================================
:)

let $m := request:get-method()
let $next := request:get-parameter('next',())
let $validate := request:get-parameter('validate',())
let $assert := request:get-parameter('assert',())
let $run := request:get-parameter('run',())
let $patch := request:get-parameter('patch',()) (: debug :)
let $dry := request:get-parameter('dry',()) (: debug :)
let $cmd := request:get-attribute('oppidum.command')
let $target := $cmd/@action
return
  if ($target eq 'POST') then
    let $data := request:get-uploaded-file-data('xt-file')
    return
      local:upload-file('/db/batch', $cmd)
  else if ($m eq 'GET' and not(empty($next))) then
  (
    <Deref>{ local:preprocessing($next) }</Deref>,
    oppidum:redirect(concat($cmd/@base-url, 'import?validate=', $next))
  )[1]
  else if ($m eq 'GET' and not(empty($validate))) then
    let $res := local:validate-and-build($validate)
    return
      (
      system:as-user(account:get-secret-user(), account:get-secret-password(),xdb:store('/db/batch/',concat($validate, '.xml'), $res, 'application/xml')),
      <Validate fn="{$validate}">{$local:mapping, $res}</Validate>
      )[last()]
  else if ($m eq 'GET' and not(empty($assert))) then
    <Broken fn="{$assert}">{local:gen-patch($assert, true())}</Broken>
  else if ($m eq 'GET' and not(empty($run))) then
    <Run>
    {
      let $projects := local:gen-patch($run, false())
      return
        local:import($projects//Project, $projects/Call),
      for $cache in ('beneficiary', 'acronym')
      let $status := 
        if (fn:doc($globals:cache-uri)/Cache/Entry[@Id eq $cache][@lang eq 'en']) then
        (
          cache:invalidate($cache, 'en'),
          'Invalidate'
        )[last()]
        else
          'NoCache'
      return
        element { $status } { $cache }
    }
    </Run>
  else if ($m eq 'GET' and (exists($patch))) then (: for debugging :)
    let $row := fn:collection('/db/batch')/rows/row[Project_Number eq $patch]
    return
      if ($row) then
        <Patch>{ local:gen-patch($row)/* }</Patch>
      else
        oppidum:throw-error('CUSTOM', concat('Project "', $patch, '" not found in batch rows'))
  else if ($m eq 'GET' and (exists($dry))) then (: for debugging :)
    let $row := fn:collection('/db/batch')/rows/row[Project_Number eq $dry]
    return
      if ($row) then
        <Patch>
          { 
          let $data := local:gen-patch($row)
          return
            local:gen-case-for-writing($data/Project/Case, $data/Call, $data/Project/Enterprise, 
              let $case := fn:collection($globals:cases-uri)//Case[@ProjectId eq $dry]
              return
                if ($case) then (: case already exists :)
                  concat('FOUND(',$case/No,')')
                else
                  'NEW'
              )
           }
        </Patch>
      else
        oppidum:throw-error('CUSTOM', concat('Project "', $patch, '" not found in batch rows'))
  else
    <Choose><List>{local:get-unzipped-batches()}</List></Choose>


xquery version "3.1";
(: ------------------------------------------------------------------
   Cockpit - EIC SME Dashboard Application

   Authors: Stéphane Sire <s.sire@opppidoc.fr>
            Frédéric Dumonceaux <Frederic.DUMONCEAUX@ext.ec.europa.eu>

   LEAR import from an Excel file

   Pre-condition: 
   - edit $local:mapping to fit Excel column names

   Workflow :
   1. upload an Excel file (POST)
   2. unzip the Excel file (?next=filename.xslx)
   3. decode the Excel file and creates filename.xslx.xml (?validate=filename.xslx)
   4. generate pivot XML patch taking into account current database content 
      shows result in a table (?assert=filename.xslx)
   5. generate pivot XML patch, then generate XML commands for updating database 
      and execute it (?run=filename.xslx)
   Steps 1 to 3 can be run on a different instance and workflow can start at step 4
   if you manually upload the .xslx.xml file into the /db/batch collection

   WARNING: delete all unecessary columns from the Excel file before !

   Debug :
   - show raw pivot XML for project Id or whole file ?patch=projectID or ?patch=filename.xslx
   - show raw XML command for project Id or whole file ?patch=projectID or ?patch=filename.xslx

   TODO: 
   - factorize some functions in an excel-export.xqm module
   - delete ZIP archive and raw unzipped Excel files at step 3

   May 2017 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace response="http://exist-db.org/xquery/response";
import module namespace compression="http://exist-db.org/xquery/compression";
import module namespace util="http://exist-db.org/xquery/util";
import module namespace xdb="http://exist-db.org/xquery/xmldb";

declare namespace ms = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace ajax = "http://oppidoc.com/ns/xcm/ajax" at "../../../xcm/lib/ajax.xqm";
import module namespace account = "http://oppidoc.com/ns/xcm/account" at "../../../xcm/modules/users/account.xqm";
import module namespace access = "http://oppidoc.com/ns/xcm/access" at "../../../xcm/lib/access.xqm";
import module namespace misc = "http://oppidoc.com/ns/misc" at "../../lib/util.xqm";
import module namespace template = "http://oppidoc.com/ns/cctracker/template" at "../../lib/template.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

declare variable $local:set := 'lear';
declare variable $local:tagset := <Tags>
                                   <Tag Set="lear">LEAR</Tag>
                                   <Tag Set="pcoco">PCOCO</Tag>
                                   <Tag Set="signature">Signature</Tag>
                                 </Tags>;
declare variable $local:enterprises := globals:collection('enterprises-uri');
declare variable $local:persons := globals:collection('persons-uri');

(: ======================================================================
   Meta data can be used to automatically add the same information 
   to a whole batch import
   ======================================================================
:)
declare variable $local:meta-call := 
  <Meta/>;
(:  <Meta>
    <Entry Position="1">
      <Src>Proposal Call Id</Src>
      <Dest Eval="tokenize($src, '-')[3]">PhaseRef</Dest>
    </Entry>
    <Entry Position="2">
      <Src>Proposal Call Deadline Date</Src>
      <Dest Eval="xs:date('1899-12-30') + xs:dayTimeDuration(concat('P', $src ,'D'))">Date</Dest>
    </Entry>
  </Meta>;:)

(: ======================================================================
   pre-condition: define a single @Key='1' column
   @MinCols is the minimum number of columns a row must have to contain 
   the column names, this is a hint for look-for-headers
   ======================================================================
:)
declare variable $local:mapping :=
  <Mapping SheetName="sheet2.xml" MinCols="10">
    <Entry Key="1" Set="signature">
      <Src>Proposal Number</Src>
      <Dest>ProjectId</Dest>
    </Entry>
    <Entry>
      <Src>Applicant PIC</Src>
      <Dest>EnterpriseId</Dest>
    </Entry>
    <Entry>
      <Src>[PP] Legal Entity PIC In Use</Src>
      <Dest>MasterId</Dest>
    </Entry>
    <Entry>
      <Src>[PJ] LEAR First Name</Src>
      <Dest>LEAR_First_Name</Dest>
    </Entry>
    <Entry>
      <Src>[PJ] LEAR Last Name</Src>
      <Dest>LEAR_Last_Name</Dest>
    </Entry>
    <Entry Key="1" Set="lear">
      <Src>[PJ] LEAR Email</Src>
      <Dest>LEAR_Email</Dest>
    </Entry>
    <Entry>
      <Src>Proposal PCOCO First Name</Src>
      <Dest>PCOCO_First_Name</Dest>
    </Entry>
    <Entry>
      <Src>Proposal PCOCO Family Name</Src>
      <Dest>PCOCO_Last_Name</Dest>
    </Entry>
    <Entry Key="1" Set="pcoco">
      <Src>Proposal PCOCO Email</Src>
      <Dest>PCOCO_Email</Dest>
    </Entry>
    <Entry>
      <Src>Project EC Signature Date</Src>
      <Dest Eval="xs:date('1899-12-30') + xs:dayTimeDuration(concat('P', floor($src) ,'D'))">Signature</Dest>
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

declare function local:gen-mandatory-element( $e as element()?, $tag as xs:string, $assert as xs:boolean ) as element() {
  if (exists($e) and ($e ne '')) then
    element { $tag } { $e/text() }
  else if ($assert) then
    <MISSING Name="{$tag}"/>
  else
    ()
};

(: ======================================================================
   Generates the EnterpriseId if the Enteprise is available 
   in database, or the empty sequence or a MISSING element if asserting
   ====================================================================== 
:)
declare function local:gen-enterprise( $id as element()?, $master as element()?, $assert as xs:boolean ) {
  if ($id) then
    let $enterprise := $local:enterprises//Enterprise[@EnterpriseId eq $id]
    return
      if ($enterprise) then
        ($id, $master)
      else (: second chance with master ID :) 
        let $enterprise := $local:enterprises//Enterprise[@EnterpriseId eq $master]
        return
          if ($enterprise) then
            ($id, $master)
          else if ($assert) then
            (<MISSING Name="EnterpriseId (not found)">{ $id/text() }</MISSING>, $master)
          else
            ()
  else if ($assert) then 
    (<MISSING Name="EnterpriseId"/>, $master)
  else
    ()
  };
  
(: ======================================================================
   Generates the ProjectOfficerKey if the project officer is available 
   in database, or the empty sequence or a MISSING element if asserting

   FIXME: actually matching on PO_Last_Name (should be on Remote(@Type=@ECAS)

   FIXME: hard coded EnterpriseId of '1' for EASME 
  
   DEPRECATED: imported using case tracker enterprises export service
   ====================================================================== 
:)
declare function local:gen-project-officer( $data as element()?, $assert as xs:boolean ) {
  if ($data) then
    let $po-ref := $local:enterprises//Enterprise[Id eq '1']//Member[upper-case(Information/Name/LastName) eq upper-case($data)]/PersonRef
    return
      if ($po-ref) then
        let $po-key := $local:persons//Person[Id eq $po-ref]/UserProfile/Remote[@Name eq 'ECAS']
        return
          if ($po-key) then
            <ProjectOfficerKey>{ $po-key/text() }</ProjectOfficerKey>
          else if ($assert) then
            <MISSING Name="ProjectOfficerKey (no known Remote)">{ $data/text() }</MISSING>
          else
            ()
      else if ($assert) then
        <MISSING Name="ProjectOfficerKey (no known team)">{ $data/text() }</MISSING>
      else
        ()
  else if ($assert) then
    <MISSING Name="ProjectOfficerKey">undefined PO_Last_Name</MISSING>
  else
    ()
};

(: ======================================================================
   Utility to generate error messages
   ====================================================================== 
:)
declare function local:gen-member-signature( $patch as element() ) as xs:string {
  concat(
    $patch/Information/Name/FirstName, 
    " ",
    $patch/Information/Name/LastName,
    " (", $patch/Information/Contacts/Email, ')'
    )
};

(: ======================================================================
   Returns the Enterprise element with a given pic (@EnterpriseId)
   Fallbacks to the corresponding master pic available in patch if not found
   ====================================================================== 
:)
declare function local:get-enterprise-for-pic( $pic as xs:string, $patch as element()* ) as element()? {
  let $enterprise := $local:enterprises//Enterprise[@EnterpriseId eq $pic]
  return
    if (exists($enterprise)) then
      $enterprise
    else (: fallback to MasterId identification :)
      let $project := $patch//Project[EnterpriseId eq $pic]
      let $master := $project/MasterId
      return
        $local:enterprises//Enterprise[@EnterpriseId eq $master]
};

(: ======================================================================
   Generates downgrade elements to maintain unicity of LEAR constraint 
   while accrediting a new LEAR in one or more company
   ====================================================================== 
:)
declare function local:check-lear-replacement( $new-lear as xs:string?, $enterprises-ref as xs:string*, $patch as element()* ) as element()* {
  for $r in $enterprises-ref
  let $enterprise := local:get-enterprise-for-pic($r, $patch)
  let $cie-ref := $enterprise/Id
  return
    <downgrade checked="{ $cie-ref }">
      {
      let $cur-lear := $local:persons//Person[.//Role[EnterpriseRef eq $cie-ref][ FunctionRef eq '3']]
      return
        
        if (exists($cur-lear) and (empty($new-lear) or ($cur-lear/Id ne $new-lear))) then (
          attribute { 'key' } { $cur-lear/Id/text() },
          attribute { 'proceed' } { 'yes' },
          <Enterprises>
            <EnterpriseRef>{ $cie-ref/text() }</EnterpriseRef>
          </Enterprises>
          )
        else 
          ()
      }
    </downgrade>
};

(: ======================================================================
   Turns a LEAR or PCOCO in patch model into a sequence of instructions to update 
   the database content using data templates

   Works with $role eq '3' for LEAR and $role eq '4' for PCOCO

   Note :
   - a team member (LEAR or PCOCO) has always a Person/UserProfile 
   - a team member (LEAR or PCOCO) is always Member of at least one Team
   ======================================================================
:)
declare function local:gen-member-for-writing( $patch as element(), $template as xs:string, $role as xs:string ) as element()
{
  let $enterprise-refs := distinct-values($patch//EnterpriseId)
  return
    <Batch>
      {
      if (exists($patch/Information//MISSING)) then (: sanity check on LEAR information :)
        <failed reason="{ $patch/Information//MISSING/@Name }">{ local:gen-member-signature($patch) }</failed>
    
      else if (exists($patch//EnterpriseId)) then (: there must be at least one complete record :)
        let $person-key := $patch/Information/Contacts/Email
        let $person := $local:persons//Person[UserProfile/Email[@Name eq 'ECAS'] eq $person-key]
        return (
          element 
            { 
            if (exists($person)) then (: non destructive update : only adds relation with enterprises :)
              let $linked-to := $person//Role[FunctionRef eq $role]/EnterpriseRef
              let $member-of := $local:enterprises//Enterprise[Team/Members/Member/PersonRef = $person/Id]/Id
              let $add-to := $local:enterprises//Enterprise[@EnterpriseId = $enterprise-refs]/Id
              (: TODO: fallback to MasterId identification - see below - ? :)
              return
                if ((every $x in $add-to satisfies ($x = $member-of and $x = $linked-to))) then
                  'same'
                else
                  'update'
            else
              'create' 
              (: note the data template will check if it already exists as a Member and accredit it if so :)
            } 
            {
              attribute { 'template' } { $template },
              if (exists($person)) then
                attribute { 'key' } { $person/Id }
              else
                (),
              $person/Id,
              <FunctionRef>{ $role }</FunctionRef>,
              $patch/Information,
              (:<Debug>
                <LearOf>{ string-join($person//Role[FunctionRef eq '3']/EnterpriseRef, ' ') }</LearOf>
                <MemberOf>{ string-join($local:enterprises//Enterprise[Team/Members/Member/PersonRef = $person/Id]/Id, ' ') }</MemberOf>
                <AddTo>{ string-join($local:enterprises//Enterprise[@EnterpriseId = $enterprise-refs]/Id, ' ') }</AddTo>
              </Debug>,:)
              <Enterprises>
                {
                for $id in $enterprise-refs
                let $enterprise := $local:enterprises//Enterprise[@EnterpriseId eq $id]
                return 
                  <EnterpriseRef>
                    { 
                    attribute { 'MasterId' } { string($patch//Project[EnterpriseId eq $id][1]/MasterId) },
                    if (exists($enterprise)) then
                      $enterprise/Id/text() 
                    else (: fallback to MasterId identification :)
                      let $project := $patch//Project[EnterpriseId eq $id]
                      let $master := $project/MasterId
                      return
                        $local:enterprises//Enterprise[@EnterpriseId eq $master]/Id/text()
                    }
                  </EnterpriseRef>
                }
              </Enterprises>
            },
            if ($role eq '3') then local:check-lear-replacement($person/Id, $enterprise-refs, $patch) else ()
          )
      else (: reports incomplete records :)
        for $p in $patch//Project[MISSING]
        return
          <failed reason="{ $p/MISSING/@Name }">project { $p/ProjectId/text() } of { local:gen-member-signature($patch) }</failed>
      }
    </Batch>
};

(: ======================================================================
   Turns a row into a LEAR XML model for importation
   ======================================================================
:)
declare function local:gen-lear( $rows as element()+, $assert as xs:boolean ){
  <LEAR Flatten="{ count($rows) }">
    <Information>
      <Name>
        {
        local:gen-mandatory-element($rows[1]/LEAR_First_Name, 'FirstName', $assert),
        local:gen-mandatory-element($rows[1]/LEAR_Last_Name, 'LastName', $assert)
        }
      </Name>
      <Contacts>
        {
        local:gen-mandatory-element($rows[1]/LEAR_Email, 'Email', $assert)
        }
      </Contacts>
    </Information>
    <Projects>
      {
      for $row in $rows 
      return
        <Project>
          {
          (: TODO: local:gen-project($row/ProjectId, $row/EnterpriseId, $assert) :)
          $row/ProjectId,
          local:gen-enterprise($row/EnterpriseId, $row/MasterId, $assert)
          (: NOT USED (imported through companies import) : local:gen-project-officer($row/PO_Last_Name, $assert):)
          }
        </Project>
      }
    </Projects>
  </LEAR>
};

(: ======================================================================
   Turns a row into a PCOCO XML model for importation
   ======================================================================
:)
declare function local:gen-pcoco( $rows as element()+, $assert as xs:boolean ){
  <PCOCO Flatten="{ count($rows) }">
    <Information>
      <Name>
        {
        local:gen-mandatory-element($rows[1]/PCOCO_First_Name, 'FirstName', $assert),
        local:gen-mandatory-element($rows[1]/PCOCO_Last_Name, 'LastName', $assert)
        }
      </Name>
      <Contacts>
        {
        local:gen-mandatory-element($rows[1]/PCOCO_Email, 'Email', $assert)
        }
      </Contacts>
    </Information>
    <Projects>
      {
      for $row in $rows 
      return
        <Project>
          {
          (: TODO: local:gen-project($row/ProjectId, $row/EnterpriseId, $assert) :)
          $row/ProjectId,
          local:gen-enterprise($row/EnterpriseId, $row/MasterId, $assert)
          (: NOT USED (imported through companies import) : local:gen-project-officer($row/PO_Last_Name, $assert):)
          }
        </Project>
      }
    </Projects>
  </PCOCO>
};

(: ======================================================================
   Turns a Signature in patch model into a sequence of instructions to update 
   the database content using data templates
   ======================================================================
:)
declare function local:gen-signature-for-writing( $patch as element() ) as element()
{
  <Batch>
    {
    if (count($patch//ProjectId) > 1) then
      <failed reason="too many rows ({count($patch//ProjectId)}) with same ProjectId">projet { $patch/Project[1]/ProjectId/text }</failed>
    else (
      for $p in $patch//Project[MISSING]
      return
        <failed reason="{ $p/MISSING/@Name } missing">project { $p/ProjectId/text() }</failed>,
      for $p in $patch//Project[not(MISSING)]
      return
        let $project := $local:enterprises//Enterprise/Projects/Project[ProjectId eq $p/ProjectId]
        return
          if (empty($project)) then
            <failed reason="missing">project { $p/ProjectId/text() } has not yet been imported to application</failed>
          else if ($project/GAP/CommissionSignature eq $p/Date) then
            <same>
              { $p/* }
              <EnterpriseRef>{ $project/ancestor::Enterprise/Id/text() }</EnterpriseRef>
            </same>
          else
            <update template="import-signature" key="{ $p/ProjectId }">
              { $p/* }
              <EnterpriseRef>{ $project/ancestor::Enterprise/Id/text() }</EnterpriseRef>
            </update>
      )
    }
  </Batch>
};

(: ======================================================================
   Turns a row into a Signature XML model for importation
   ======================================================================
:)
declare function local:gen-signature( $rows as element()+, $assert as xs:boolean ){
  <Signature Flatten="{ count($rows) }">
    {
    for $row in $rows 
    return
      <Project>
        {
        $row/ProjectId,
        if (empty($local:enterprises//Enterprise/Projects/Project[ProjectId eq $row/ProjectId])) then
          <MISSING Name="Project"/>
        else 
          (),
        local:gen-mandatory-element($rows[1]/Signature, 'Date', $assert)
        }
      </Project>
    }
  </Signature>
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
   Tries to retrieve the first data row modelling the headers
   Returns :
       <headers position="index">
          <name column="letter">label</name>
          ...
       </headers> 
   a list of name elements with the column label
   @column is the column letter in the spreadsheet coordinate system
   when it can be found
   @position is the index of the row used to extract column names
   ======================================================================
:)
declare function local:look-for-headers( $filemap as element(), $filename as xs:string, $sourcename as xs:string ) as element() {
  let $main-sheet := $filemap//result[ends-with(string(@destination), $filename)]/@destination
  return
    if (count($main-sheet) eq 0) then
      oppidum:throw-error('IMPORT-TARGET-SHEET-NOT-FOUND', substring(substring-after($filename, 'sheet'), 0, 1))
    else
      let $datasheet := fn:doc($main-sheet)//ms:sheetData
      let $src-count := if ($local:mapping/@MinCols) then xs:integer($local:mapping/@MinCols) else count($local:mapping//Src)
      (: heuristic to extract the first row element with enough columns :)
      let $headersrow  := (for $r in $datasheet/ms:row[count(child::ms:c[@t eq 's']) ge $src-count][position() < 10] return $r)[1]
      let $ss-uri := concat('/db/batch/', substring-before($sourcename, '.xlsx'), '_xlsx_parts/xl/sharedStrings.xml')
      let $decodeStrings := fn:doc($ss-uri)//ms:si/ms:t/text()
      return
        if ($headersrow) then
          <headers position="{ count($headersrow/preceding-sibling::ms:row) + 1 }" sharedStrings="{$ss-uri}">
          {
          for $v in $headersrow//ms:v
          return 
            <name>
              {
              if (exists($v/parent::ms:c/@r)) then
                attribute { 'column' } {
                  replace($v/parent::ms:c/@r,'\d*', '')
                }
              else
                (),
              $decodeStrings[xs:integer($v) + 1]
              }
            </name>
          }
          </headers>
        else
          oppidum:throw-error('IMPORT-NO-HEADERS', ())
};

(: ======================================================================
   Make a match between the data model ($mapping) and the raw data headers 
   Returns :
      <Mapping DataBeginsAt="3">
        <Entry Position="i" Column="letter">
          <Src>label</Src>
          <Dest>tag</Dest>
        </Entry>
        ...
      </Mapping>
   a list of Entry elements 
   @Position is the supposed index of the ms:c element in an ms:row 
   that contains the label column or '-1' if the column was not found in the headers
   @Column is the column letter in the spreadsheet coordinate systeem
   Dest is the XML tag that will be generated to contain the label element
   @DataBeginsAt is the index of the first ms:row in the ms:sheetData 
   that contains some data to extract
   ======================================================================
:)
declare function local:compute-index( $mapping as element(), $headers as element()) as element() {
  <Mapping DataBeginsAt="{ xs:integer($headers/@position) + 1 }">
  {
    for $e in $mapping//Entry
    let $match := $headers//name[text() eq $e/Src/text()]
    return
      element Entry
      {
        attribute Position { 
          if ($match) then count($headers//name[text() eq $e/Src/text()]/preceding-sibling::name) + 1 else '-1' 
          },
        if ($match/@column) then
          attribute Column {
            string($match/@column)
            }
        else
          (),
        $e/node()
      }
  }
  </Mapping>
};

(: ======================================================================
   Check that every tag in the model has been properly indexed
   Returns the empty sequence or throws an oppidum error with the name 
   of the header columns that could not be located
   ======================================================================
:)
declare function local:validate-index( $index as element() ) as element()* {
  let $not-found := $index//Entry[(@Position eq '-1') and not(@Column)]
  return
    if (exists($not-found)) then
      oppidum:throw-error('IMPORT-MISMATCHING-HEADERS', string-join($not-found/Src/text(), ', '))
    else
      ()
};


(: ======================================================================
   MAIN FUNCTIONS
   ======================================================================
:)

(: ======================================================================
   Downgrades a LEAR into a Delegate
   To be called when another LEAR has been imported
   ====================================================================== 
:)
declare function local:downgrade( $form as element() ) as element()? {
  if ($form/@proceed eq 'yes') then
    let $lear := $local:persons//Person[Id = $form/@key]
    let $member := $local:enterprises//Enterprise[Id = $form//EnterpriseRef]/Team//Member[PersonRef eq $form/@key]
    return 
      if (exists($lear) and exists($member)) then (: updates previous LEAR roles in Enterprise :)
        let $action := <Roles>
                         <Remove><FunctionRef>3</FunctionRef></Remove>
                         <Add><FunctionRef>4</FunctionRef></Add>
                       </Roles>
        let $res := template:do-update-resource('roles', (), $lear, $member, $action)
        return
          if (local-name($res) ne 'error') then
            <done reason="downgraded LEAR account of { $lear//Email } to simple delegate">{ $form/* }</done>
          else 
            <failed reason="error while downgrading account { $form/@key } because { $res }">{ $form/* }</failed>
      else
        <failed reason="cannot downgrade missing account { $form/@key } or missing member">{ $form/* }</failed>
  else
    ()
};

(: ======================================================================
   Batch imports a LEAR, PCOCO or Signature specification
   This can results in adding the LEAR to new companies if s/he already exists
   ======================================================================
:)
declare function local:import( $batch as element() ) as element()* {
  for $form in $batch/*
  return
    if (local-name($form) eq 'create') then
      let $res := template:do-create-resource($form/@template, (), $local:enterprises, $form, '-1')
      return
        if (local-name($res) eq 'success') then
          <created key="{string($res/@key)}">{ $form/* }<DEBUG>{ $res }</DEBUG></created>
        else
          <failed reason="{ string($res) }">{ $form/* }</failed>
    else if (local-name($form) eq 'update') then (: could be signature :)
      if ($form/@template eq 'import-person') then
        let $person := $local:persons//Person[Id eq $form/@key]
        let $res := template:do-update-resource($form/@template, $person/Id, $person, $local:enterprises, $form)
        return
          if (local-name($res) eq 'success') then
            <updated key="{ $person/Id }">{ $form/* }<DEBUG>{ $res }</DEBUG></updated>
          else
            <failed reason="{ string($res) }">{ $form/* }</failed>
      else if ($form/@template eq 'import-signature') then
        let $key := $form/ProjectId
        let $project := $local:enterprises//Enterprise/Projects/Project[ProjectId eq $key]
        let $res := template:do-update-resource($form/@template, $key, $project, (), $form)
        return
          if (local-name($res) eq 'success') then
            <updated key="{ $key }">{ $form/* }<DEBUG>{ $res }</DEBUG></updated>
          else
            <failed reason="{ string($res) }">{ $form/* }</failed>
      else
        <failed reason="unkown template { string($form/@template) }">{ $form/* }</failed>
    else if (local-name($form) eq 'downgrade') then 
      local:downgrade($form)
    else if (local-name($form) eq 'same') then
      $form
    else if (local-name($form) eq 'failed') then
      <skipped>{ $form/@*, $form/*, $form/text() }</skipped>
    else
      <failed reason="unkown instruction { local-name($form) }"/>
};

(: ======================================================================
   Transforms Excel raw XML file containing extracted rows into an internal
   XML pivot format that can be used to make the database import
   Flatten multiple rows with same Key into a single Row
   ======================================================================
:)
declare function local:gen-patch( $filename as xs:string, $assert as xs:boolean, $set as xs:string ) {
  let $key := $local:mapping//Entry[@Key][@Set eq $set]/Dest/text()
  let $xml := fn:doc(concat('/db/batch/', $filename ,'.xml'))//rows
  return
  (:no metadata to copy :)
    (:<Call>{$data/preceding-sibling::metadata/child::*}</Call>:)
    <Import>
      {
      if ($set eq 'lear') then
        for $projects in $xml/row
        let $lear-email := $projects/*[local-name(.) eq $key]
        group by $lear-email
        (: a LEAR may belong to several companies :)
        return
          local:gen-lear($projects, $assert)
      else if ($set eq 'pcoco') then
        for $projects in $xml/row
        let $pcoco-email := $projects/*[local-name(.) eq $key]
        group by $pcoco-email
        (: a PCOCO may belong to several companies :)
        return
          local:gen-pcoco($projects, $assert)
      else if ($set eq 'signature') then
        for $projects in $xml/row
        (: a Signature belongs to a single project  :)
        return
          local:gen-signature($projects, $assert)
      else 
        ()
      }
    </Import>
};

(: ======================================================================
   See above
   Version used to dump a patch for debug purpose
   ======================================================================
:)
declare function local:gen-patch( $rows as element()+, $set as xs:string ) {
  (:no metadata to copy :)
  (:<Call>{$data/preceding-sibling::metadata/child::*}</Call>:)
  <Import>
    {
    if ($set eq 'lear') then
      local:gen-lear($rows, true())
    else if ($set eq 'pcoco') then
      local:gen-pcoco($rows, true())
    else if ($set eq 'signature') then
      local:gen-signature($rows, true())
    else
      ()
    }
  </Import>
};

(: ======================================================================
   Extracts worksheet data from  the excel worksheet filename 
   using the filemap to locate raw unzipped excel data 
   using $mapping data model construction instructions

   Returns :
    <rows>
      <metadata>...</metadata>
      <row><{tag}>value</{tag}>...</row>
      ...
    </rows>
   ======================================================================
:)
declare function local:build-data( $filename as xs:string, $filemap as element(), $mapping as element(), $sourcename as xs:string ) as element() {
  let $main-sheet := $filemap//result[ends-with(string(@destination), $filename)]/@destination
  let $ss-uri := concat('/db/batch/', substring-before($sourcename, '.xlsx'), '_xlsx_parts/xl/sharedStrings.xml')
  let $decodeStrings := fn:doc($ss-uri)//ms:si/ms:t/text()
  return
    <rows>
      <metadata>
      {
        let $first := fn:doc($main-sheet)//ms:sheetData/ms:row[position() eq xs:integer($mapping/@DataBeginsAt)]
        return
          for $e in $local:meta-call/Entry
          let $src := $first/ms:c[position() = xs:integer($e/@Position)]/ms:v/text()
          return
            element { $e/Dest/text() } {
              if ($e/Dest/@Eval) then
                try {
                  util:eval($e/Dest/@Eval)
                } catch * {
                  "EXCEPTION"
                }
              else 
                $src
            }
      }
      </metadata>
      {
      (: starts at ms:row at @DataBeginsAt :)
      for $datarow in fn:doc($main-sheet)//ms:sheetData/ms:row[position() ge xs:integer($mapping/@DataBeginsAt)]
      where exists($datarow/*) (: discards empty rows :)
      return
        <row>
        {
          for $e in $mapping/Entry
          let $c-src := 
            if (exists($e/@Column)) then (: tries to match using ms:c/@r cell coordinates :)
              let $found := $datarow/ms:c[starts-with(@r, $e/@Column)]
              return
                if (exists($found)) then 
                  $found 
                else (: fallback to @Position algorithm :)
                  $datarow/ms:c[position() = xs:integer($e/@Position)]
            else (: fallback to @Position algorithm :)
              $datarow/ms:c[position() = xs:integer($e/@Position)]
              (: FIXME: utiliser count pour supprrimer les ms:c sans ms:v precedents ? :)
          let $src := 
            if ($c-src/@t eq 'n') then 
              $c-src/ms:v/text() 
            else 
              try {
                $decodeStrings[xs:integer($c-src/ms:v) + 1]
              } 
              catch * {
                "EXCEPTION"
              }
          return
            element { $e/Dest/text() } {
              if ($e/Dest/@Text) then
                replace($src, '_x000D_', '&#10;')
              else if ($e/Dest/@Eval and $src) then
                try {
                  util:eval($e/Dest/@Eval)
                } catch * {
                  ""
                }
              else
                $src
            }
        }
        </row>
      } 
    </rows>
};

(: ======================================================================
   Unzip the worksheets
   ======================================================================
:)
declare function local:preprocessing( $filename as xs:string ) {
  let $unzipped := local:unzip($filename, 'unzip')
  (: DEPRECATED: let $decoded := local:unreference-strings( $unzipped ) :)
  return
    (
      xdb:store('/db/batch/', concat('feedback-',$filename,'.xml'), $unzipped, 'application/xml'),
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
  let $headers := local:look-for-headers( $unzipped, string($local:mapping/@SheetName), $filename)
  return
    if (local-name($headers) eq 'error') then
      $headers
    else
      let $index := local:compute-index($local:mapping, $headers)
      let $res := local:validate-index($index)
      return 
        if (local-name($res) eq 'error') then
          <Batch>{ $headers, $index, $res }</Batch>
          (:$res:)
        else
          let $import := local:build-data(string($local:mapping/@SheetName), $unzipped, $index, $filename)
          return
            <Batch>{ $headers, $index, $import }</Batch>
           (: $import :)
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
  $perms as xs:integer ) as xs:string?
{
  if (xdb:store($col-uri, $filename, $data, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')) then (
    xdb:set-resource-permissions($col-uri, $filename, $user, $group, $perms),
    $filename
    )
  else
    ()
};

(: ======================================================================
   Upload Excel file into the collection /db/batch to be processed
   Returns an Ajax response to AXEL 'file' plugin with a redirection to
   the next step "teams/import?next=filename" or returns an oppidum error
   ======================================================================
:)
declare function local:POST-Excel-file( $col-uri as xs:string, $cmd as element() ) as xs:string {
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
            let $res := local:write-file($col-uri, 'admin', 'users', $filename,  $data, util:base-to-integer(0774, 8))
            return
              if ($res) then (
                ajax:report-file-plugin-success($res, 201),
                response:set-header('Location', concat($cmd/@base-url, 'teams/import?next=', $filename)))
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
  let $processed := 
    for $child in xdb:get-child-resources($coll)
    where not(starts-with($child, 'feedback')) and ends-with($child, '.xlsx.xml')
    return 
      <Unzipped Deref="true">{fn:substring-before($child, '.xml')}</Unzipped>
  return 
    (
    for $child in xdb:get-child-collections($coll)
    where 'xl' = xdb:get-child-collections(concat($coll,'/',$child)) and 'worksheets' = xdb:get-child-collections(concat($coll,'/',$child, '/xl'))
    return
      let $has-sss := 'sharedStrings.xml' = xdb:get-child-resources(concat($coll,'/',$child))
      return
        let $fn := concat(fn:substring-before($child, '_xlsx'), '.xlsx')
        return
          if ($fn = $processed/text()) then (: already extracted :)
            ()
          else
            <Unzipped Deref="{$has-sss}">{$fn}</Unzipped>,
    $processed
    )
};

(: ======================================================================
   Handes ?next step of the import wizard workflow
   Unzip the file filename.xslx
   ====================================================================== 
:)
declare function local:handle-NEXT( $cmd as element(), $filename as xs:string ) {
  <Deref>
    {
    let $next := oppidum:redirect(concat($cmd/@base-url, 'teams/import?validate=', $filename))
    return local:preprocessing($filename)
    }
  </Deref>
};

(: ======================================================================
   Handes ?validate=filename step of the import wizard workflow
   Decode the columns from filename.xslx according to $local:mapping,
   save the result inside filename.xslx.xml
   ====================================================================== 
:)
declare function local:handle-VALIDATE( $cmd as element(), $filename as xs:string ) {
  let $output-file := concat('/db/batch/', $filename, '.xml')
  return
    <Validate fn="{ $filename }">
      {
      if (fn:doc-available($output-file) and (request:get-parameter('_confirmed', '0') ne '1')) then (
        <Confirm/>,
        $local:mapping,
        fn:doc($output-file)/Batch
        )
      else
        let $res := local:validate-and-build($filename)
        return
          let $save := xdb:store('/db/batch/', concat($filename, '.xml'), $res, 'application/xml')
          return (
            $local:mapping,
            $res
            )
      }
    </Validate>
};

(: ======================================================================
   Handes ?run=filename step of the import wizard workflow
   Generates pivot XML for filename, transform it to XML commands for 
   updating the database, updates the database
   ====================================================================== 
:)
declare function local:handle-RUN( $cmd as element(), $filename as xs:string, $set as xs:string ) {
  <Run>
    {
    let $import := local:gen-patch($filename, true(), $set)
    return
      if ($set eq 'lear') then
        for $item in $import/LEAR
        return
          local:import(local:gen-member-for-writing($item, 'import-person', '3'))
      else if ($set eq 'pcoco') then
        for $item in $import/PCOCO
        return
          local:import(local:gen-member-for-writing($item, 'import-person', '4'))
      else if ($set eq 'signature') then
        for $item in $import/Signature
        return
          local:import(local:gen-signature-for-writing($item))
      else
        ()
    }
  </Run>
};

(: ======================================================================
   Handes ?patch=key debug command (with Excel Proposal Number key)
   Same as ?assert command to generate pivot XML taking into account
   current database format but simply shows raw result
   ====================================================================== 
:)
declare function local:handle-PATCH( $cmd as element(), $key as xs:string, $set as xs:string ) {
  if (ends-with($key, '.xlsx') or exists(fn:collection('/db/batch')//row[ProjectId eq $key])) then
    <Patch Set="{ $set }">
      {
      fn:serialize(
        if (ends-with($key, '.xlsx')) then
          local:gen-patch($key, true(), $set)
        else
          local:gen-patch(fn:collection('/db/batch')//row[ProjectId eq $key], $set),
        <output:serialization-parameters>
          <output:indent value="yes"/>
        </output:serialization-parameters>
        )
      }
    </Patch>
  else
    oppidum:throw-error('CUSTOM', concat('Project "', $key, '" not found in batch rows'))
};

(: ======================================================================
   Handes ?dry=key debug command (with Excel Proposal Number key)
   Same as local:handle-RUN but does not execute updates
   and returns XML commands for a project ID or for a file
   ====================================================================== 
:)
declare function local:handle-DRY( $cmd as element(), $key as xs:string, $set as xs:string ) {
  let $import := 
    if (ends-with($key, '.xlsx')) then
      local:gen-patch($key, true(), $set)
    else
      let $row := fn:collection('/db/batch')//row[ProjectId eq $key]
      return if ($row) then local:gen-patch($row, $set) else ()
  return
    if ($import) then
      <Patch Set="{ $set }">
        {
        fn:serialize(
          if ($set eq 'lear') then
            for $item in $import/LEAR
            return local:gen-member-for-writing($item, 'import-person', '3')/*
          else if ($set eq 'pcoco') then
            for $item in $import/PCOCO
            return local:gen-member-for-writing($item, 'import-person', '4')/*
          else if ($set eq 'signature') then
            for $item in $import/Signature
            return local:gen-signature-for-writing($item)/*
          else
            (),
          <output:serialization-parameters>
            <output:indent value="yes"/>
          </output:serialization-parameters>
        )
        }
      </Patch>
    else
      oppidum:throw-error('CUSTOM', concat('Project "', $key, '" not found in batch rows'))
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
let $set := lower-case(request:get-parameter('set', $local:set))
let $access := access:get-entity-permissions('import', 'LEAR', <Unused/>)
return
  (: NOTE: to use a Navigation Model you MUST add explicit xhtml namespace in custom menu generation function :)
  if (local-name($access) eq 'allow') then
    <Page StartLevel="1" skin="fonts">
      <Window>SME Dashboard LEAR import Wizard</Window>
      <Content>
        {
        if ($target eq 'POST') then
          local:POST-Excel-file('/db/batch', $cmd) (: redirect => NEXT :)

        else if ($m eq 'GET' and not(empty($next))) then (: button to => VALIDATE :)
          local:handle-NEXT($cmd, $next)

        else if ($m eq 'GET' and not(empty($validate))) then (: button to => ASSERT :)
          local:handle-VALIDATE($cmd, $validate)

        else if ($m eq 'GET' and not(empty($assert))) then (: button to => RUN :)
          <Assert fn="{ $assert }" Set="{ $set }" Tag="{ $local:tagset/Tag[@Set eq $set]/text() }">
            {
            local:gen-patch($assert, true(), $set)
            }
          </Assert>
 
        else if ($m eq 'GET' and not(empty($run))) then (: show results *END* :)
          local:handle-RUN($cmd, $run, $set)

        else if ($m eq 'GET' and (exists($patch))) then (: for debugging :)
          local:handle-PATCH($cmd, $patch, $set)
      
        else if ($m eq 'GET' and (exists($dry))) then (: for debugging :)
          local:handle-DRY($cmd, $dry, $set)

        else (: ENTRY POINT :)
          (: Excel file import + legacy Excel files selection view :)
          <Choose>
            <List>{ local:get-unzipped-batches() }</List>
          </Choose>
        }
      </Content>
    </Page>
  else
    $access


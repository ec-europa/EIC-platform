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

   TEMPORARY FILES CREATED (in /db/batch):
   - {file}.xlsx (uploaded Excel file)
   - collection {file}_xlsx_parts (uncompressed Excel file)
   - feedback-{file}.xlsx.xml (resource index of uncompressed collection)
   - {file}.xlsx.xml (raw XML content extraced in XML row format)
   - {file}.xlsx.xhtml (generated XTiger template before moving to mesh collection)
   - event-{file}.xml (event meta-data file before moving to events collections)

   May 2017 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace response="http://exist-db.org/xquery/response";
import module namespace compression="http://exist-db.org/xquery/compression";
import module namespace util="http://exist-db.org/xquery/util";
import module namespace xdb="http://exist-db.org/xquery/xmldb";

declare namespace ms = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";
declare namespace xhtml = "http://www.w3.org/1999/xhtml";
declare namespace xt = "http://ns.inria.org/xtiger";
declare namespace site = "http://oppidoc.com/oppidum/site";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/ns/xcm/globals" at "../../lib/globals.xqm";
import module namespace ajax = "http://oppidoc.com/ns/xcm/ajax" at "../../../xcm/lib/ajax.xqm";
import module namespace account = "http://oppidoc.com/ns/xcm/account" at "../../../xcm/modules/users/account.xqm";
import module namespace misc = "http://oppidoc.com/ns/misc" at "../../lib/util.xqm";
import module namespace template = "http://oppidoc.com/ns/cctracker/template" at "../../lib/template.xqm";
import module namespace form = "http://oppidoc.com/ns/xcm/form" at "../../../xcm/lib/form.xqm";
import module namespace mesh = "http://oppidoc.com/ns/mesh" at "../../lib/mesh.xqm";
import module namespace enterprise = "http://oppidoc.com/ns/enterprise" at "../../modules/enterprises/enterprise.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

declare variable $local:enterprises := globals:collection('enterprises-uri');
declare variable $local:events := globals:collection('events-uri');
declare variable $local:persons := globals:collection('persons-uri');

(: ======================================================================
   pre-condition: define a single @Key='1' column
   @MinCols is the minimum number of columns a row must have to contain 
   the column names, this is a hint for look-for-headers
   ======================================================================
:)
declare variable $local:mapping :=
  <Mapping SheetName="sheet1.xml" MinCols="10">
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

declare function local:gen-mandatory-element( $e as element()?, $tag as xs:string, $assert as xs:boolean, $key as xs:boolean ) as element() {
  if (exists($e) and ($e ne '')) then
    element { $tag } { if ($key) then attribute Key { '1' } else (), $e/text() }
  else if ($assert) then
    <MISSING Name="{$tag}"/>
  else
    ()
};

(: ======================================================================
   Turns an event in patch model into a sequence of instructions to update 
   the database content using data templates
   Note :
   - an event must be related to a valid project 
   ======================================================================
:)
declare function local:gen-event-for-writing( $patch as element(), $template as xs:string, $event-def as element() ) as element()
{
  <Batch>
    {
    let $key := $patch/*[@Key = "1"][1] (: no composite key yet :)
    return
      if (exists($patch//MISSING)) then (: sanity check :)
        <failed reason="{ $patch//MISSING/@Name }">Missing "{string($patch//MISSING/@Name)}"</failed>
      else (: given project must be valid :)
        let $p := $local:enterprises//Enterprise/Projects/Project[ProjectId eq $key]
        return
          if (not($p)) then
            <failed>Missing project { $key }</failed>
          else if (not($p/GAP/CommissionSignature) or $p/TerminationFlagRef) then
            <failed>Missing GAP sign. or terminated project { $p/ProjectId/text() }</failed>
          else
            <update template="{$template}"  key="{ $event-def/Id }">{ $patch/* }</update>
    }
  </Batch>
};

(: ======================================================================
   Generates event registration form XTiger template editor
   ====================================================================== 
:)
declare function local:gen-mesh-for-writing( $mapping as element(), $filename as xs:string ) as element() {
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:site="http://oppidoc.com/oppidum/site" xmlns:xt="http://ns.inria.org/xtiger" xmlns:xhtml="http://www.w3.org/1999/xhtml">
  <head>
    <meta http-equiv="content-type" content="text/html; charset=UTF-8" />
    <title></title>
      <link rel="stylesheet" type="text/css" href="../resources/bootstrap/css/bootstrap.css"/>
      <link rel="stylesheet" type="text/css" href="../resources/bootstrap/css/bootstrap-responsive.css"/>
      <link rel="stylesheet" type="text/css" href="../resources/bootstrap/css/bootstrap-responsive.min.css"/>
      <link rel="stylesheet" type="text/css" href="../resources/css/site.css"/>
      <link rel="stylesheet" type="text/css" href="../resources/css/forms.css"/>
      <link rel="stylesheet" type="text/css" href="../resources/css/index.css"/> 
    <xt:head version="1.1" templateVersion="1.0" label="Event">
      <xt:component name="t_main">
        <form action="" onsubmit="return false;" tabindex="-1">
          <div class="ecl-fieldset">
            <p class="a-cell-legend">Registration form</p>
            {
            for $entry in $mapping/*[local-name(.) = 'Entry']
            return
              <div class="ecl-form-group">
               
                  <label class="ecl-form-label">{ $entry/*[local-name(.) = 'Src']/text() }</label>
                  <div class="controls" data-binding="mandatory" data-variable="_undef" data-validation="off" data-mandatory-invalid-class="af-mandatory" data-mandatory-type="textarea">
                    <site:field filter="copy" force="true" signature="multitext">
                      <xt:use types="input" label="{ $entry/*[local-name(.) = 'Dest']/text() }" param="type=textarea;multilines=normal;class=sg-multitext span a-control;filter=optional event"></xt:use>
                    </site:field>
                  </div>
                
              </div>
            }
          </div>
        </form>
      </xt:component>
    </xt:head>
  </head>
  <body>
    <xt:use types="t_main"></xt:use>
  </body>
</html>
};

(: ======================================================================
   
   ======================================================================
:)
declare function local:gen-event( $mapping as element(), $rows as element()+, $assert as xs:boolean ){
  let $key := $mapping//Dest[../@Key = "1"]/text()
  return
    <Event Flatten="{ count($rows) }">
    {
      local:gen-mandatory-element($rows[1]/*[local-name(.) = $key], $key, $assert, true()),
      for $cur in $rows[1]/*[not(local-name(.) = $key)]
      return local:textualize($cur, ())
    }
    </Event>
};

(: ======================================================================
 Turns node with text() content into node with <Text> content splitted by line return
 Does not generate Text wrapper if text doesn not contain newline character
 (thanks to AXEL input plugin in multitext mode that supports plain text content)
 ======================================================================
:)
declare function local:textualize( $node as item(), $tag as xs:string? ) as item() {
  if (contains($node/text(), '_x000D_')) then
    element { if ($tag) then $tag else local-name($node) }
      {
        for $text in tokenize($node/text(), '_x000D_')
        where not(matches($text, "^\s*$"))
        return
          <Text>{ $text }</Text>
      }
  else
    $node
};

declare function local:words-to-camel-case( $arg as xs:string? ) as xs:string {
  string-join(
    (tokenize($arg,'\s+')[1],
    for $word in tokenize($arg,'\s+')[position() > 1]
    return
        concat(upper-case(substring($word,1,1)), substring($word,2)))
    ,''
  )
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
      (: heuristic to extract the first row element with enough columns :)
      let $headersrow  := $datasheet/ms:row[1]
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
    for $match at $i in $headers//name
    return
      element Entry
      {
        attribute Position { $i },
        if ($match/@column) then
          attribute Column {
            string($match/@column)
            }
        else
          (),
        <Src>{ $match/text() }</Src>,
        <Dest>{ if (string-length(replace($match, "[a-zA-Z():,;\.\-]", "")) > 5) then concat('Comments', $i) else local:words-to-camel-case( replace($match, "[^a-zA-Z]", "")) }</Dest>
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
   Batch imports an event registration form
   ======================================================================
:)
declare function local:import( $batch as element() ) as element()* {
  for $form in $batch/*
  return 
    if (local-name($form) eq 'update') then (: add event forms to an enterprise :)
      if ($form/@template eq 'import-application-event') then
        let $proj-key :=  $form/*[@Key][1]
        let $enterprise := $local:enterprises//Enterprise[Projects//ProjectId/text() eq $proj-key]
        return
          if ($enterprise) then
            let $res := template:do-update-resource($form/@template, $form/@key, $enterprise, (), $form)
            return
              if (local-name($res) eq 'success') then
                <updated key="{ $form/@key }">{ $form/* }<DEBUG>{ $res }</DEBUG></updated>
              else
                <failed reason="{ string($res) }">{ $form/* }</failed>
          else
            <failed reason="project key { $proj-key } not found in enterprise { $enterprise/Information/Name }">{ $form/* }</failed>
      else
        <failed reason="unkown template { string($form/@template) }">{ $form/* }</failed>
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
declare function local:gen-patch( $filename as xs:string, $assert as xs:boolean ) {
  let $output-file := fn:doc(concat('/db/batch/', $filename, '.xml'))
  let $mapping := $output-file//Mapping
  let $xml := $output-file//rows
  return
    <Import>
      {
        for $projects in $xml/row
        return
          local:gen-event($mapping, $projects, $assert)
      }
    </Import>
};

(: ======================================================================
   Extracts worksheet data from  the excel worksheet filename 
   using the filemap to locate raw unzipped excel data 
   using $mapping data model construction instructions

   Returns :
    <rows>
      <row><{tag}>value</{tag}>...</row>
      ...
    </rows>
   ======================================================================
:)
declare function local:build-data( $filename as xs:string, $filemap as element(), $mapping as element(), $sourcename as xs:string ) as element() {
  let $main-sheet := $filemap//result[ends-with(string(@destination), $filename)]/@destination
  let $ss-uri := concat('/db/batch/', substring-before($sourcename, '.xlsx'), '_xlsx_parts/xl/sharedStrings.xml')
  let $decodeStrings := fn:doc($ss-uri)//ms:si/ms:t
  return
    <rows>
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
            if ($c-src/@t eq 's') then 
              try {
                $decodeStrings[xs:integer($c-src/ms:v) + 1]/text()
              }
              catch * {
                "EXCEPTION"
              }
            else
              $c-src/ms:v/text() 
          return
            element { $e/Dest/text() } {
              $src
              (:replace($src, '_x000D_', '&#10;') - see local:textualize ! :)
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
  if (xdb:store($col-uri, $filename, $data, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')) then
    $filename
  else
    ()
};

(: ======================================================================
   Upload Excel file into the collection /db/batch to be processed
   Returns an Ajax response to AXEL 'file' plugin with a redirection to
   the next step "events/import?next=filename" or returns an oppidum error
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
                response:set-header('Location', concat($cmd/@base-url, 'events/import?next=', $filename)))
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
   Register the metadata of an event and the key needed for building the 
   join between projects and the forms to integrate
   Manages Validate button submission
   ======================================================================
:)
declare function local:POST-Key( $col-uri as xs:string, $cmd as element(), $fn as xs:string ) as element() {
  let $meta := ('Programme', 'Name', 'Topic', 'Town', 'Country', 'From', 'To')
  let $data := oppidum:get-data()
  let $event := $data/Event
  let $n := count($data//*[not(local-name(.) =  $meta)][not(child::*)])
  let $n2 := count($data//*[local-name(.) =  $meta][. ne ''])
  return
    if ($n eq 0) then
      ajax:throw-error('CUSTOM', 'A key was intended. Please tick a column before proceeding further.')
    else if ($n gt 1) then
      ajax:throw-error('CUSTOM', 'Only one key is intended. Please proceed accordingly')
    else if ($n2 ne 9) then (: FIXME could it be computed from count($meta) + stg ? :)
      ajax:throw-error('CUSTOM', concat('All fields are mandatory. ',$n2))
    else
      let $key := local-name($data/*[not(local-name(.) eq 'Event')])
      (: 1. creates event-XXX.xml file to be copied to the events definition collection later :)
      let $event-def :=
        <Event ProjectKeyTag="{ $key }">
          <Programme Selector="EventsPrograms" WorkflowId="{ $event/Programme/text() }">{ $event/Programme/text() }</Programme>
          { $event/Information }
        </Event>
      return
        let $store-event-def := xdb:store('/db/batch/', concat('event-', fn:substring-before($fn, '.xlsx'), '.xml'), $event-def )
        (: 2. creates XXX.xhtml XTiger template file with dynamically generated registration form to be copied to the mesh collection later :)
        let $output-file := fn:doc(concat('/db/batch/', $fn, '.xml'))//Mapping
        let $key-entry := $output-file/Entry[Dest eq $key]
        let $put := update replace $key-entry with <Entry Key="1">{ $key-entry/(@*[not(local-name(.) eq 'Key')]|*) }</Entry>
        let $mesh := xdb:store('/db/batch/', concat($fn, '.xhtml'), local:gen-mesh-for-writing( $output-file, $fn ) )
        return (
          response:set-header('Location', concat($cmd/@base-url, 'events/import?assert=', $fn )), 
          <Redir/>
          )
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
   Handes ?delete step of the import wizard workflow
   Post-installation temporary files cleanup
   ====================================================================== 
:)
declare function local:handle-DELETE( $cmd as element(), $filename as xs:string ) {
  let $next := oppidum:redirect(concat($cmd/@base-url, 'events/import'))
  let $batch := "/db/batch"
  let $base := fn:substring-before($filename, '.xlsx')
  let $excel-file := concat($batch, '/', $filename)
  let $uncompressed-col := concat($batch, '/', $base, '_xlsx_parts')
  let $feedback-file := concat($batch, '/', 'feedback-', $base, '.xlsx.xml')
  let $raw-file := concat($batch, '/', $base, '.xlsx.xml')
  let $mesh-file := concat($batch, '/', $base, '.xlsx.xhtml')
  let $meta-file := concat($batch, '/', 'event-', $base, '.xml')
  return
    <Redirected>
      {
      if (util:binary-doc-available($excel-file)) then (
        xdb:remove($batch, substring-after($excel-file, concat($batch, '/'))),
        oppidum:throw-message('INFO', concat('File "', $excel-file, '" deleted')) 
        )
      else
        oppidum:throw-message('INFO', concat('File "', $excel-file, '" not found, ok')),
      if (xdb:collection-available($uncompressed-col)) then (
        xdb:remove($uncompressed-col),
        oppidum:throw-message('INFO', concat('Collection "', $uncompressed-col, '" deleted')) 
        )
      else
        oppidum:throw-message('INFO', concat('Collection "', $uncompressed-col, '" not found, ok')),
      for $file in ($feedback-file, $raw-file, $mesh-file, $meta-file)
      return
        if (fn:doc-available($file)) then (
          xdb:remove($batch, substring-after($file, concat($batch, '/'))),
          oppidum:throw-message('INFO', concat('File "', $file, '" deleted')) 
          )
        else
          oppidum:throw-message('INFO', concat('File "', $file, '" not found, ok'))
      }
    </Redirected>
};

(: ======================================================================
   Handes ?next step of the import wizard workflow
   Unzip the file filename.xslx
   ====================================================================== 
:)
declare function local:handle-NEXT( $cmd as element(), $filename as xs:string ) {
  <Deref>
    {
    let $next := oppidum:redirect(concat($cmd/@base-url, 'events/import?validate=', $filename))
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
      let $meta := fn:doc(concat('/db/batch/event-', fn:substring-before($filename, '.xlsx'), '.xml'))
      return
        <EnterMetadata>
          <xt:use types="Data"/>
        </EnterMetadata>,
      <SelectKey/>,
      if (fn:doc-available($output-file) and (request:get-parameter('_confirmed', '0') ne '1')) then (
        <Confirm/>,
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
   Build and load online the mesh for editing the metadata of an event
   based on its tree structure
   ======================================================================
:)
declare function local:handle-VALIDATE-component( $cmd as element(), $filename as xs:string ) {
  let $doc := concat('/db/batch/event-', fn:substring-before($filename, '.xlsx'), '.xml')
  let $today := substring(string(fn:current-date()),1,10)
  let $meta := 
    if (fn:doc-available($doc)) then 
      fn:doc($doc)
    else
    <root>
      <Event>
        <Programme Selector="EventsPrograms"/>
        <Information>
          <Name/><Topic/>
          <Location><Town/><Country/></Location>
          <Date><From>{$today}</From><To>{$today}</To></Date>
          <Application><From>{$today}</From><To>{$today}</To></Application>
        </Information>
      </Event>
    </root>
  return
    <Header>
      <XT>
        <xt:head version="1.1" templateVersion="1.0" label="Data">
          <xt:component name="Data">
            <xt:use types="Event" label="Event"/>
          </xt:component>
          { mesh:embedding(mesh:compact(mesh:transform($meta/Event))) }
        </xt:head>
      </XT>
    </Header>
};

(: ======================================================================
   Handes ?run=filename step of the import wizard workflow
   Generates pivot XML for filename, transform it to XML commands for 
   updating the database, updates the database
   ====================================================================== 
:)
declare function local:handle-RUN( $cmd as element(), $filename as xs:string ) {
  <Run>
    {
    let $meta := fn:doc(concat('/db/batch/event-', fn:substring-before($filename, '.xlsx'), '.xml'))
    let $name := lower-case(replace($meta//Name,' ', '-'))
    let $form :=
      <Event template='event'>
        <Template ProjectKeyTag="{$meta/Event/@ProjectKeyTag}">dyn/{$name}</Template>
        <Programme>{ $meta/Event/Programme/@*,  fn:collection($globals:global-info-uri)//Description[@Lang = 'en']//Selector[@Name eq 'EventsPrograms']//Option[Value eq $meta/Event/Programme/text()]/Name/text()  }</Programme>
        { $meta/Event/*[not(local-name(.) eq 'Programme')] }
      </Event>
    return (: event mesh and meta-data deployment 
              FIXME: actually its not possible to re-deploy mesh and meta-data w/o deleting them first :)
      (
      (: 1. rename and move the XTiger template to the mesh collection if this hasn't been done before :)
      if (not(fn:doc-available(concat('/db/www/', globals:app-collection(), '/mesh/', $name, '.xhtml')))) then
        (
        xdb:rename('/db/batch/', concat( $filename,'.xhtml'), concat( $name, '.xhtml')),
        system:as-user(account:get-secret-user(), account:get-secret-password(), xdb:move('/db/batch/', concat('/db/www/', globals:app-collection(), '/mesh/'), concat($name, '.xhtml')))
        )
      else
        (),
      (: 2. creates then event meta data file and stores it if this hasn't been done before :)
      let $event-def := fn:collection($globals:events-uri)//Event[Template eq concat('dyn/',$name)]
      return
        (
        if ($event-def) then
          <skipped key="{$event-def/Id}">{ $event-def/* }</skipped>
        else
          let $res := template:do-create-resource($form/@template, (), $local:events, $form, '-1')
          return
            if (local-name($res) eq 'success') then
              <created key="{string($res/@key)}">{ $form/* }</created>
            else
              <failed reason="{ string($res) }">{ $form/* }</failed>,
        (: 3. import the individual event registration forms :)
        let $import := local:gen-patch( $filename, true() )
        let $event-def := fn:collection($globals:events-uri)//Event[Template eq concat('dyn/',$name)]
        return
          for $item in $import/Event
          return
            local:import(local:gen-event-for-writing($item, 'import-application-event', $event-def))
        )
      )
    }
  </Run>
};

(: ======================================================================
   Handes ?dry=filename step of the import wizard workflow
   Quick & Dirty
   ====================================================================== 
:)
declare function local:handle-DRY( $cmd as element(), $filename as xs:string ) {
  <Run fn="{ $filename }">
    {
    let $meta := fn:doc(concat('/db/batch/event-', fn:substring-before($filename, '.xlsx'), '.xml'))
    let $name := lower-case(replace($meta//Name,' ', '-'))
    let $form :=
      <Event template='event'>
        <Id>XXX</Id>
        <Template ProjectKeyTag="{$meta/Event/@ProjectKeyTag}">dyn/{$name}</Template>
        <Programme>{ $meta/Event/Programme/@*,  fn:collection($globals:global-info-uri)//Description[@Lang = 'en']//Selector[@Name eq 'EventsPrograms']//Option[Value eq $meta/Event/Programme/text()]/Name/text()  }</Programme>
        { $meta/Event/*[not(local-name(.) eq 'Programme')] }
      </Event>
    let $event-def := fn:collection($globals:events-uri)//Event[Template eq concat('dyn/',$name)]
    return (
      <META>
        { 
        $form,
        if ($event-def) then
          <skipped key="{$event-def/Id}">{ $form }</skipped>
        else
          (:let $res := template:do-create-resource($form/@template, (), $local:events, $form, '-1')
          return
            if (local-name($res) eq 'success') then:)
              <created key="{$form/Id}">{ $form }</created>
            (:else
              <failed reason="{ string($res) }">{ $form/* }</failed>:)
         }
        </META>,
        <DATA>
        {
        (: event registration forms :)
        let $import := local:gen-patch( $filename, true() )
        return
          for $item in $import/Event
          return
            local:gen-event-for-writing($item, 'import-application-event', $form)
        }
        </DATA>
        )
    }
  </Run>
};

(: ======================================================================
   MAIN ENTRY POINT
   ======================================================================
:)
let $m := request:get-method()
let $delete := request:get-parameter('delete',())
let $next := request:get-parameter('next',())
let $fn := request:get-parameter('fn',())
let $validate := request:get-parameter('validate',())
let $assert := request:get-parameter('assert',())
let $run := request:get-parameter('run',())
let $patch := request:get-parameter('patch',()) (: debug :)
let $dry := request:get-parameter('dry',()) (: debug :)
let $cmd := request:get-attribute('oppidum.command')
let $target := $cmd/@action
return
  (: NOTE: to use a Navigation Model you MUST add explicit xhtml namespace in custom menu generation function :)
  <Page StartLevel="1" skin="fonts">
    <Window>SME Dashboard Events import Wizard</Window>
    { 
      if ($m eq 'GET' and not(empty($validate))) then
        local:handle-VALIDATE-component($cmd, $validate)
      else 
        ()
    }
    <Content>
      {
      if ($target eq 'POST') then
        if (not(empty($fn))) then
          local:POST-Key('/db/batch', $cmd, $fn) (: redirect => ASSERT :)
        else
          local:POST-Excel-file('/db/batch', $cmd) (: redirect => NEXT :)

      else if ($m eq 'GET' and not(empty($delete))) then (: button to => DELETE :)
        local:handle-DELETE($cmd, $delete)

      else if ($m eq 'GET' and not(empty($next))) then (: button to => VALIDATE :)
        local:handle-NEXT($cmd, $next)

      else if ($m eq 'GET' and not(empty($validate))) then (: button to => ASSERT :)
        local:handle-VALIDATE($cmd, $validate)

      else if ($m eq 'GET' and not(empty($assert))) then (: button to => RUN :)
        <Assert fn="{ $assert }" Set="events" Tag="Event">
        {
        local:gen-patch($assert, true())
        }
        </Assert>
        
      else if ($m eq 'GET' and not(empty($run))) then (: show results *END* :)
        local:handle-RUN($cmd, $run)

      else if ($m eq 'GET' and (exists($dry))) then (: for debugging :)
        local:handle-DRY($cmd, $dry)
        
      else (: ENTRY POINT :)
        (: Excel file import + legacy Excel files selection view :)
        <Choose Allow="delete">
          <List>{ local:get-unzipped-batches() }</List>
        </Choose>
      }
    </Content>
  </Page>


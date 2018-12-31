xquery version "1.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Utility to generate a list of KAM Coordinators person records 
   from Excel tables converted to XML, the result must be cut-and-pasted
   into persons/ for database initialization.

   Used once to initialize the list of KAM Coordinators
   Not required for normal operations

   LIMITATION
   - first version to be used with cut-and-paste and sandbox
   - some resource names are hard-coded and must be adjusted in consequence

   February 2015 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

declare option exist:serialize "method=xml media-type=text/xml";

declare variable $local:input := '/db/batch/coordinators-2014-02-02.xml';
declare variable $local:role := '3'; 
declare variable $local:first := 51;

declare function local:normalize( $name as xs:string* ) {
  replace(upper-case(normalize-space($name)), '[_\-\s\d\.]', '')
};

declare function local:gen-person-with-role( $row as element(), $id as xs:string, $role-ref as xs:string ) as element() {
  let $target := fn:collection('/db/sites/cctracker/regions')//Region[Acronym[local:normalize(.) eq local:normalize($row/Acronym/text())]]
  return
    if ($target) then
      <Person>
        <Id>{$id}</Id>
        <Name>
          <LastName>{$row/Surname/text()}</LastName>
          <FirstName>{$row/FirstName/text()}</FirstName>
        </Name>
        <Contacts>
          <Email>{$row/Email/text()}</Email>
        </Contacts>
        <UserProfile>
          <Roles>
            <Role>
              <FunctionRef>3</FunctionRef>
              <RegionalEntityRef>{$target/Id/text()}</RegionalEntityRef>
            </Role>
          </Roles>
        </UserProfile>
      </Person>
    else
      <MISSING>{$row/FirstName/text()} {$row/Surname/text()} ===> { $row/Acronym/text() }</MISSING>
};

declare function local:gen-persons( $rows as element()* ) {
  let $res := 
    for $row at $i in $rows
    return
      local:gen-person-with-role($row, string($local:first + $i - 1), $local:role)
  return
    $res[local-name(.) ne 'MISSING']
};

(: ======================================================================
   Generates coordinators who does not exist inside database 
   and who appear as new coordinators in the new batch
   ======================================================================
:)
declare function local:gen-new-persons() {
  let $mail := distinct-values(fn:doc('/db/batch/regions-2015-03-09.xml')//row/Email/text())
  return 
    for $m in $mail
    let $person := fn:doc('/db/batch/regions-2015-03-09.xml')//row[Email eq $m][1]
    let $acro := local:normalize($person/Acronym/text())
    let $region := fn:collection('/db/sites/cctracker/regions')//Region[local:normalize(Acronym) eq $acro]/Id/text()
    let $cur-coordinator := fn:collection('/db/sites/cctracker/persons')//Person[UserProfile/Roles/Role[(FunctionRef eq '3') and (RegionalEntityRef eq $region)]]
    let $existing := fn:collection('/db/sites/cctracker/persons')//Person[Contacts/Email eq $m]
    return 
       if ($cur-coordinator/Contacts/Email = $m) then
         ()
       else if (not($existing)) then
         <row>
         {(
         $person/Acronym,
         $person/Surname,
         $person/FirstName,
         $person/Email
         )}
         </row>
       else
         ()
};

(: ======================================================================
   Same as above for second Coordinator
   ======================================================================
:)
declare function local:gen-new-persons-bis() {
  let $mail := distinct-values(fn:doc('/db/batch/regions-2015-03-09.xml')//row/EmailBis/text())
  return 
    for $m in $mail
    let $person := fn:doc('/db/batch/regions-2015-03-09.xml')//row[EmailBis eq $m][1]
    let $acro := local:normalize($person/Acronym/text())
    let $region := fn:collection('/db/sites/cctracker/regions')//Region[local:normalize(Acronym) eq $acro]/Id/text()
    let $cur-coordinator := fn:collection('/db/sites/cctracker/persons')//Person[UserProfile/Roles/Role[(FunctionRef eq '3') and (RegionalEntityRef eq $region)]]
    let $existing := fn:collection('/db/sites/cctracker/persons')//Person[Contacts/Email eq $m]
    return 
       if ($cur-coordinator/Contacts/Email = $m) then
         ()
       else if (not($existing)) then
         <row>
         {(
         $person/Acronym,
         <Surname>{$person/SurnameBis/text()}</Surname>,
         <FirstName>{$person/FirstNameBis/text()}</FirstName>,
         <Email>{$person/EmailBis/text()}</Email>
         )}
         </row>
       else
         ()
};

(:let $rows := fn:doc($local:input)//row:)
let $rows := local:gen-new-persons()
return
  <Persons>
    {
    local:gen-persons($rows)
    }
  </Persons>


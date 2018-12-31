xquery version "1.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Utility to generate a list of KAM person records 
   from Excel tables converted to XML, the result must be cut-and-pasted
   into persons/persons.xml for database initialization.

   Used once to initialize the list of KAM Coordinators
   Not required for normal operations

   LIMITATION
   - first version to be used with cut-and-paste and sandbox

   February 2015 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

declare option exist:serialize "method=xml media-type=text/xml";

declare variable $local:input := '/db/batch/kams-2015-03-09.xml';
declare variable $local:role := '5'; 
declare variable $local:first := 281;

(: Simple code to check regions are known before importing KAM :)
(:
let $acro := distinct-values(fn:doc('/db/batch/kams-2015-03-09.xml')//row/Acronym/text())
return 
  <Check>
   {
  for $a in $acro
  return 
     if (fn:collection('/db/sites/cctracker/regions')//Region[Acronym eq normalize-space($a)]) then 
       ()
     else
       <Missing>{ $a }</Missing>
   }
  </Check>:)


declare function local:normalize( $name as xs:string* ) {
  replace(upper-case(normalize-space($name)), '[_\-\s\d\.]', '')
};

declare function local:gen-person-with-role( $row as element(), $id as xs:string, $role-ref as xs:string ) as element() {
  let $target := fn:collection('/db/sites/cctracker/regions')//Region[Acronym[local:normalize(.) eq local:normalize($row/Acronym/text())]]
  return
    if ($target) then
      let $conflict := fn:collection('/db/sites/cctracker/persons')//Person[Contacts/Email eq $row/Email/text()]
      
      return
        if ($conflict) then 
          <SKIP>{$row/FirstName/text()} {$row/Surname/text()} { $row/Acronym/text() } ===> { $row/Email/text() } already existing into DB</SKIP>
        else
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
                <FunctionRef>5</FunctionRef>
                <RegionalEntityRef>{$target/Id/text()}</RegionalEntityRef>
              </Role>
            </Roles>
          </UserProfile>
        </Person>
    else
      <MISSING>{$row/FirstName/text()} {$row/Surname/text()} ===> { $row/Acronym/text() }</MISSING>
};

<Persons>
  {
  let $res := 
    for $row at $i in fn:doc($local:input)//row
    return
      local:gen-person-with-role($row, string($local:first + $i - 1), $local:role)
  return
    $res[local-name(.) ne 'MISSING']
  }
</Persons>

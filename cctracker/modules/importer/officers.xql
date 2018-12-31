xquery version "1.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Utility to batch import project officers

   LIMITATION
   - first version to be used with cut-and-paste and sandbox

   February 2015 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

declare option exist:serialize "method=xml media-type=text/xml";

declare variable $local:input := '/db/batch/2014-06-18.xml';
declare variable $local:role := '12'; (: project officer :)
declare variable $local:first := 20;

declare function local:gen-person-with-role( $row as element(), $id as xs:string, $role-ref as xs:string ) as element() {
  <Person PersonId="{ $row/PO_ID/text() }">
    <Id>{ $id }</Id>
    <Sex>{ $row/PO_Gender/text() }</Sex>
    <Civility>{ normalize-space($row/PO_Title/text()) }</Civility>
    <Name>
      <LastName>{ $row/PO_Family_Name/text() }</LastName>
      <FirstName>{ $row/PO_First_Name/text() }</FirstName>
    </Name>
    <Contacts>
      <Phone>{ $row/PO_Telephone/text() }</Phone>
      <Email>{ $row/PO_Email/text() }</Email>
    </Contacts>
    <UserProfile>
      <Roles>
        <Role>
          <FunctionRef>{ $role-ref }</FunctionRef>
        </Role>
      </Roles>
    </UserProfile>
  </Person>
};

let $keys := distinct-values(fn:doc($local:input)//row/PO_Email/text())
return
  <Persons>
    {
    for $key at $i in $keys
    let $row := fn:doc($local:input)//row[PO_Email eq $key][1]
    return
      local:gen-person-with-role($row, string($local:first + $i - 1), $local:role)
    }
  </Persons>

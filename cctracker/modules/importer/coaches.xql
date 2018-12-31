xquery version "1.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Utility to batch import persons

   LIMITATION
   - first version to be used with cut-and-paste and sandbox

   February 2015 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

declare option exist:serialize "method=xml media-type=text/xml";

declare variable $local:input := '/db/batch/coaches-2015-02-02.xml';
declare variable $local:role := '4'; (: coach :)
declare variable $local:first := 181;

declare function local:gen-person-with-role( $row as element(), $id as xs:string, $role-ref as xs:string ) as element() {
  <Person>
    <Id>{ $id }</Id>
    <Name>
      <LastName>{ $row/Surname/text() }</LastName>
      <FirstName>{ $row/Name/text() }</FirstName>
    </Name>
    <Contacts>
      { $row/Email }
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

<Persons>
  {
  for $row at $i  in fn:doc($local:input)//row
  return
    local:gen-person-with-role($row, string($local:first + $i - 1), $local:role)
  }
</Persons>

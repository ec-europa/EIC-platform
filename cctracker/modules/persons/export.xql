xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Creation: Stéphane Sire <s.sire@oppidoc.fr>

   Exports coaches 
   To be called from third party applications like Coach Match

   XML protocol

   <Export [Format="profile"] [Letter="X"]><All/></Export> :
   - get all coaches, optional filter by last name first letter

   <Export [Format="profile"]><Email>xxx</Email></Export> :
   - get coach with given e-mail address

   in both requests the "profile" format attribute asks 
   for detailed coach record (Sex, Civility, Country, etc.)

   October 2015 - European Union Public Licence EUPL
   ----------------------------------------------- :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";
declare namespace request = "http://exist-db.org/xquery/request";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace services = "http://oppidoc.com/ns/services" at "../../lib/services.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../../lib/access.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Returns Coach sample information (Name, Email, Username)
   Useful to align user's login between platforms
   DEPRECATED: since EU login ?
   ======================================================================
:)
declare function local:gen-coach-sample( $p as element() ) as element() {
  <Coach> 
    {
    $p/Name,
    $p/Contacts/Email,
    $p//Username
    }
  </Coach>
};

(: ======================================================================
   Returns Coach profile information
   Useful to synchronize user's profile information between platforms
   ======================================================================
:)
declare function local:gen-coach-profile( $p as element() ) as element() {
  <Coach> 
    {
    $p/(Sex | Civility | Name | Country | Contacts),
    $p//Remote
    }
  </Coach>
};

(: ======================================================================
   Builds regular expression to filters names starting with letter
   or the empty sequence. If letter is not a single letter, then returns 
   a regexp that should match noting.
   ====================================================================== 
:)
declare function local:get-letter-re( $letter as xs:string ) as xs:string? {
  if ($letter ne '') then 
    if (matches($letter, "^[a-zA-Z]$")) then 
      let $l := concat('[', upper-case($letter), lower-case($letter), ']')
      return concat('^', $l, '|(.*\s', $l, ')')
    else
      "^$" (:no name should be empty:)
  else 
    ()
};

(: ======================================================================
   Returns function reference from submitted request
   Defaults to coach
   ====================================================================== 
:)
declare function local:get-function-ref( $submitted as element() ) as xs:string* {
  if ($submitted/Function) then
    access:get-function-ref-for-role($submitted/Function)
  else
    access:get-function-ref-for-role('coach')
};

(: *** MAIN ENTRY POINT *** :)
let $submitted := oppidum:get-data()
let $errors := services:validate('cctracker', 'cctracker.coaches', $submitted)
return
  if (empty($errors)) then
    let $search := services:unmarshall($submitted)
    let $email := $search/Email/text()
    let $re := if ($search/@Letter) then local:get-letter-re(string($search/@Letter)) else ()
    let $fref := local:get-function-ref($search)
    return
      <Coaches Re="{$re}" Function="{$fref}">
        {
        if ($search/@Format eq 'profile') then 
          for $p in fn:collection($globals:persons-uri)//Person[UserProfile//FunctionRef = $fref]
          where (empty($re) or matches($p//LastName, $re))
            and (empty($email) or (normalize-space($p/Contacts/Email) eq $email))
          return local:gen-coach-profile($p)
        else
          for $p in fn:collection($globals:persons-uri)//Person[UserProfile//FunctionRef = $fref]
          where (empty($re) or matches($p//LastName, $re))
            and (empty($email) or (normalize-space($p/Contacts/Email) eq $email))
          return local:gen-coach-sample($p)
        }
      </Coaches>
  else
    $errors

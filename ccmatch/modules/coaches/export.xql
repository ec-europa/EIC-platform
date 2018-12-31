xquery version "1.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

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
   
   October 2015 - (c) Copyright may be reserved
   ----------------------------------------------- :)

declare namespace xdb = "http://exist-db.org/xquery/xmldb";
declare namespace request = "http://exist-db.org/xquery/request";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace services = "http://oppidoc.com/ns/services" at "../../lib/services.xqm";

declare option exist:serialize "method=xml media-type=text/xml";

(: ======================================================================
   Returns Coach sample information (Name, Email, Username)
   Useful to align user's login between platforms
   ======================================================================
:)
declare function local:gen-coach-sample( $p as element() ) as element() {
  <Coach> 
    {
    $p/Information/Name,
    $p/Information/Contacts/Email,
    $p/UserProfile/Remote[string(@Name) eq 'ECAS']/Key,
    $p/Hosts/Host[@For eq '1']/AccreditationRef,
    $p/Hosts/Host[@For eq '1']/WorkingRankRef,
    $p/Preferences/Coaching[@For eq '1']/YesNoAvailRef
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
    $p/Information/(Sex | Civility | Name | Country | Contacts),
    $p/UserProfile/Remote,
    $p/UserProfile/Username,
    $p/Hosts/Host[@For eq '1']/AccreditationRef,
    $p/Hosts/Host[@For eq '1']/WorkingRankRef,
    $p/Preferences/Coaching[@For eq '1']/YesNoAvailRef
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

(: *** MAIN ENTRY POINT *** :)
let $submitted := oppidum:get-data()
let $errors := services:validate('ccmatch-public', 'ccmatch.export', $submitted)
return
  if (empty($errors)) then
    let $search := services:unmarshall($submitted)
    let $email := $search/Email/text()
    let $re := if ($search/@Letter) then local:get-letter-re(string($search/@Letter)) else ()
    return
      <Coaches Re="{$re}">
        {
        if ($search/@Format eq 'profile') then 
          for $p in fn:collection($globals:persons-uri)//Person[UserProfile/Roles/Role/FunctionRef eq '4'][Hosts/Host[@For eq '1']/AccreditationRef = ('1','2', '3','4')]
          (:for $p in fn:collection($globals:persons-uri)//Person[UserProfile/Roles/Role/FunctionRef eq '4'][Hosts/Host[@For eq '1']/WorkingRankRef eq '1'][not(Preferences/Coaching[@For eq '1']/YesNoAvailRef) or (Preferences/Coaching[@For eq '1']/YesNoAvailRef eq '1')]:)
          where (empty($re) or matches($p//LastName, $re))
            and (empty($email) or (normalize-space($p/Remote) eq $email) or (normalize-space($p/Information/Contacts/Email) eq $email))
          return local:gen-coach-profile($p)
        else
          for $p in fn:collection($globals:persons-uri)//Person[UserProfile/Roles/Role/FunctionRef eq '4'][Hosts/Host[@For eq '1']/AccreditationRef = ('1','2', '3','4')]
          (:for $p in fn:collection($globals:persons-uri)//Person[UserProfile/Roles/Role/FunctionRef eq '4'][Hosts/Host[@For eq '1']/WorkingRankRef eq '1'][not(Preferences/Coaching[@For eq '1']/YesNoAvailRef) or (Preferences/Coaching[@For eq '1']/YesNoAvailRef eq '1')]:)
          where (empty($re) or matches($p//LastName, $re))
            and (empty($email) or (normalize-space($p/Remote) eq $email) or (normalize-space($p/Information/Contacts/Email) eq $email))
          return local:gen-coach-sample($p)
        }
      </Coaches>
  else
    $errors

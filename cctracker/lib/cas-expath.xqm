xquery version "1.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC XQuery Content Management Framework

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   Interaction with services configured in services.xml

   July 2015 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

module namespace cas = "http://oppidoc.com/ns/cas";

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace httpclient = "http://exist-db.org/xquery/httpclient";
import module namespace http = "http://expath.org/ns/http-client";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "globals.xqm";
import module namespace misc = "http://oppidoc.com/ns/cctracker/misc" at "util.xqm";
import module namespace database = "http://oppidoc.com/ns/database" at "../../excm/lib/database.xqm";

declare namespace hc = "http://expath.org/ns/http-client";

(: ======================================================================
   Raise an error whenever any parameter is missing
   ======================================================================
:)
declare function local:validate-parameters($parameters as element(), $keys as xs:string*) as xs:string* {
  string-join($parameters/Mandatory[not(. = $keys)], ' ')
};

(: ======================================================================
   Build the GET parameters string
   ======================================================================
:)
declare function local:concat-keys-and-values($keys as xs:string*, $values as xs:string*) as xs:string {
  string-join(
    for $k at $i in $keys
    return
      concat(if($i > 1) then '&amp;' else '', $k, '=', $values[$i]),
    '')
};

(: ======================================================================
   Concat base url with parameters and check that mandatory ones are properly
   set else raise an error.
   ======================================================================
:)
declare function local:gen-get($end-point as element(), $keys as xs:string*, $values as xs:string*) as xs:string? {
  let $missing := local:validate-parameters($end-point/Parameters, $keys)
  return
    if (count($missing) lt 0) then
      oppidum:throw-error('CAS-INVALID-GET', (string($end-point/parent::Realm/@Name), $missing))
    else
      let $kv-s:= local:concat-keys-and-values($keys, $values)
      return
        concat($end-point/parent::Realm/Base, $end-point/Suffix, '?', $kv-s)
};

declare function local:get-rules-from-context($rules as element(), $result as element()) as element() {
  <Rules>
  {
    for $rule in $rules/(Failure | Success)
    where not($rule/@Context) or $result//*[local-name(.) = $rule/@Context]
    return $rule
  }
  </Rules>
};

declare function local:apply-failure($failure as element(), $result as element(), $end-point as element()) as element() {
  if ($failure/@Context) then
    let $Context := $result//*[local-name(.) = $failure/@Context]
    return
      let $trigger := $failure/Trigger
      return
        if (util:eval($failure/Trigger/@On)) then
          oppidum:throw-error($trigger, (string($end-point/parent::Realm/@Name), $Context))
        else
          oppidum:throw-error('CUSTOM', (string($end-point/parent::Realm/@Name), $Context))
  else (: no rules means ok to trigger :)
    oppidum:throw-error($failure/Trigger, string($end-point/parent::Realm/@Name))
};

declare function local:apply-success($success as element(), $result as element(), $end-point as element()) as element() {
  if ($success/@Context) then
    let $Context := $result//*[local-name(.) = $success/@Context]
    return
      if ($success/Combine) then
        element { string($success/Combine/@Root) }
        {
          for $m in $success/Combine/Mapping
          return
            element { $m/text() } { $Context//*[local-name(.) = $m/@Target]/text() }
        }
      else if (string-length($success/Return) eq 0) then
        $Context
      else
        let $ret := $Context//*[local-name(.) = $success/Return]
        return 
          if ($ret) then
            $ret
          else
            oppidum:throw-error('CAS-INVALID-NOTHING-TO-RETURN', (string($success/parent::Realm/@Name), $success/@Context))
  else if ($success/Combine) then
    element { string($success/Combine/@Root) }
    {
      for $m in $success/Combine/Mapping
      return
        element { $m/text() } { $result//*[local-name(.) = $m/@Target]/text() }
    }
  else if ($success/Return or string-length($success/Return) > 0) then
      let $ret := $result//*[local-name(.) = $success/Return]
      return 
        if ($ret) then
          $ret
        else
          oppidum:throw-error('CAS-INVALID-NOTHING-TO-RETURN', (string($success/parent::Realm/@Name), $success/Return))
  else
    $result
};

declare function local:process-result($end-point as element(), $header as element(), $result as element(), $start as xs:string) as element() {
  let $rules := $end-point/Result[@Http eq $header/@status]
  let $realm := string($end-point/parent::Realm/@Name)
  return
    if (empty($rules)) then
      oppidum:throw-error('CAS-INVALID-INIT-NO-RULES', ($realm, $header/@status))
    else
      let $to-apply := local:get-rules-from-context($rules, $result)
      return
        if (empty($to-apply/(Failure | Success | Combine))) then
          oppidum:throw-error('CAS-INVALID-INIT-NO-VALID-RULES', ($realm, $header/@status))
        else if (count($to-apply/Failure) > 0 and count($to-apply/Success) > 0) then
          oppidum:throw-error('CAS-INVALID-INIT-MISMATCHING-RULES', ($realm, $header/@status))
        else if (count($to-apply/Failure) > 0) then
          (
          oppidum:redirect($start),
          for $f in $to-apply/Failure
          return local:apply-failure($f, $result, $end-point)
          )[last()]
        else
          local:apply-success($to-apply/Success, $result, $end-point)
};

(: ======================================================================
   Returns a login initialization request to the CAS server. It must contain
   at least the URI to the protected ressource the user wanted to access.
   Can be ran even if already logged in the CAS. Whenever an error occured,
   returns to Start page.
   If successful, the response contains the encrypted version of the request
   to be submitted to the login page
   ======================================================================
:)
declare function cas:init-login($realm-name as xs:string, $end-point-name as xs:string, $keys as xs:string*, $values as xs:string*, $start as xs:string) as element() {
  let $ep:= fn:doc(oppidum:path-to-config('security.xml'))//Realm[@Name eq $realm-name]/EndPoint[Id eq $end-point-name]
  return
    let $uri := local:gen-get($ep, $keys, $values)
    let $to := if ($ep/../AllowedTimeOut) then $ep/../AllowedTimeOut else '20'
    return
      let $result := http:send-request(<http:request href="{$uri}" method="get" timeout="{$to}"/>)
      (:let $result := httpclient:get(xs:anyURI($uri), false(), ()) :)
      return
        local:process-result($ep, $result[1], <fake>{$result[2]}</fake>, $start)
        (:local:process-result($ep, $result, $start):)
};

(: ======================================================================
   Redirect to the login page using the encrypted request achieved above
   ======================================================================
:)
declare function cas:goto-login($realm-name as xs:string, $end-point-name as xs:string, $keys as xs:string*, $values as xs:string*) {
  let $ep:= fn:doc(oppidum:path-to-config('security.xml'))//Realm[@Name eq $realm-name]/EndPoint[Id eq $end-point-name]
  return
    let $uri := local:gen-get($ep, $keys, $values)
    return
      oppidum:redirect($uri)
};

(: ======================================================================
   Once logged on to the CAS, processes the ticket in order to assert
   the identity of the user
   ====================================================================== 
:)
declare function cas:validate($realm-name as xs:string, $end-point-name as xs:string, $keys as xs:string*, $values as xs:string*, $start as xs:string) as element() {
  let $ep:= fn:doc(oppidum:path-to-config('security.xml'))//Realm[@Name eq $realm-name]/EndPoint[Id eq $end-point-name]
  return
    let $uri := local:gen-get($ep, $keys, $values)
    let $to := if ($ep/../AllowedTimeOut) then $ep/../AllowedTimeOut else '20'
    return
      let $result := http:send-request(<http:request href="{$uri}" method="get" timeout="{$to}"/>)
      (:let $result := httpclient:get(xs:anyURI($uri), false(), ()):)
      return
        local:process-result($ep, $result[1], <fake>{$result[2]}</fake>, $start)
        (:local:process-result($ep, $result, $start):)
};

(: ======================================================================
   Returns the local profile associated to the remote user by joining them
   In ECAS 6 (EU Login), mail shall replace username
   Must be used NEXT TO login on to the application
   TODO: to be defined in security.xml
   ======================================================================
:)
declare function cas:get-user-profile-in-realm($realm-name as xs:string) as element()? {
  fn:collection($globals:persons-uri)//Person[lower-case(UserProfile/Remote/text()) eq lower-case(oppidum:get-current-user()) and UserProfile/Remote/@Name = $realm-name]
};

declare function cas:get-predefined-user-profile-in-realm($realm-name as xs:string) as element()? {
  fn:doc($globals:remotes-uri)//Remote[Realm = $realm-name][lower-case(Key/text()) eq lower-case(oppidum:get-current-user())]
};

(: ======================================================================
   Checks if the remote user has a profile in the application
   TODO: to be defined in security.xml
   ======================================================================
:)
declare function cas:has-user-profile-in-realm($realm-name as xs:string) as xs:boolean {
  exists(cas:get-user-profile-in-realm($realm-name))
};

(: ======================================================================
   Checks if the remote user has a predefined profile by an administrator
   TODO: to be defined in security.xml
   ======================================================================
:)
declare function cas:has-predefined-profile-in-realm($realm-name as xs:string) as xs:boolean {
  exists(cas:get-predefined-user-profile-in-realm($realm-name))
};

declare function cas:get-predefined-user-profile() as element()? {
  let $remote := session:get-attribute('cas-user')
  return
    if (exists($remote) and exists($remote/key) and exists($remote/@name)) then
      fn:doc($globals:remotes-uri)//Remote[Key = $remote/key and Realm = $remote/@name]
    else
      ()
};

(: ======================================================================
   Log on to eXist and store user identity picked from the CAS into the new session
   FIXME: sometimes stores ECAS result into session
   ====================================================================== 
:)
declare function cas:login-as-cas($realm-name as xs:string, $uid as xs:string, $all as element()?, $goto as xs:string?) as element()? {
  let $model := fn:doc(oppidum:path-to-config('security.xml'))//Realm[@Name eq $realm-name]
  let $session:= $model//Variable[Name eq 'Session']/Expression
  return
    if (xdb:login('/db', $model//Surrogate/User, $model//Surrogate/Password, true())) then
    (
      session:set-attribute('cas-user', util:eval($session)),
      session:set-attribute('cas-res', $all),
      if ($goto) then
        <Redirected>{ oppidum:redirect($goto) }</Redirected>
      else
        ()
    )
    else
      oppidum:add-error('CAS-LOGIN-FAILED', $model/Label/text(), true())
};

(: ======================================================================
   To use if the remote user have a preexisting user profile
   TODO: move $user-profile in security.xml
   ====================================================================== 
:)
declare function cas:merge($realm-name as xs:string, $remote as xs:string, $local as xs:string) {
  let $user-profile := fn:collection($globals:persons-uri)//Person/UserProfile[Username/text() eq $local] (: fn:doc in CT, fn:collection in CM :)
  let $model := fn:doc(oppidum:path-to-config('security.xml'))//Realm[@Name eq $realm-name]
  let $remote-user:= $model//Variable[Name eq 'RemoteUser']/Expression
  let $val := if (exists($remote-user)) then util:eval($remote-user) else ()
  return
    if ($user-profile and exists($val)) then
      let $legacy := $user-profile/Remote[@Name eq $val/@Name]
      return
        if (exists($legacy)) then
          update replace $legacy with $val
        else
          update insert $val following $user-profile/Username
    else (: should not be possible, since the credentials of the user have been already validated against the DB :)
      ()
};

(: ======================================================================
   To use if the remote user have a predefined user profile
   TODO: move $user-profile, $all and $person in security.xml
   See also modules/persons/person.xql
   ====================================================================== 
:)
declare function cas:create-profile($realm-name as xs:string, $remote as xs:string, $goto as xs:string?) {
  let $remote-profile := fn:doc($globals:remotes-uri)//Remote[lower-case(Key) = lower-case($remote) and Realm = $realm-name]
  let $model := fn:doc(oppidum:path-to-config('security.xml'))//Realm[@Name eq $realm-name]
  let $remote-user:= $model//Variable[Name eq 'RemoteUser']/Expression
  let $newkey :=
    max(for $key in fn:collection($globals:persons-uri)//Person/Id
    return if ($key castable as xs:integer) then number($key) else 0) + 1
  let $all := session:get-attribute('cas-res')
  return
    let $person :=
      <Person>
        { $remote-profile/@PersonId }
        <Id>{ $newkey }</Id>
        <UserProfile>{ $remote-profile/UserProfile/*, util:eval($remote-user) }</UserProfile>
        <Name>
          <LastName>{ $all/lastname/text() }</LastName>
          <FirstName>{ $all/firstname/text() }</FirstName>
        </Name>
        <Contacts>
          <Email>{ $all/email/text() }</Email>
        </Contacts>
      </Person>
    return
    (
      let $col := misc:gen-collection-name-for($newkey)
      let $fn := concat($newkey, '.xml')
      let $col-uri := database:create-collection-lazy-for($globals:persons-uri, $col, 'person')
      let $stored-path := xdb:store($col-uri, $fn, $person)
      return 
      (
        if (not($stored-path eq ())) then
          database:apply-policy-for($col-uri, $fn, 'Person')
        else
          (),
        $stored-path
      )[last()],
      update delete $remote-profile,
      if ($goto) then
        oppidum:redirect($goto)
      else
        ()
      )
};

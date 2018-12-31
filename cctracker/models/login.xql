xquery version "1.0";
(: --------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Author: Stéphane Sire <s.sire@oppidoc.fr>

   Either generates the login page model to ask the user to login or tries to login
   the user if credentials are supplied and redirects on success.

   The optional request parameter 'url' contains the full path of a site page
   to redirect the user after a successful login.

   March 2014 - European Union Public Licence EUPL
   -------------------------------------- :)

import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace request = "http://exist-db.org/xquery/request";
import module namespace session = "http://exist-db.org/xquery/session";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../lib/globals.xqm";
(:import module namespace cas = "http://oppidoc.com/ns/cas" at "../lib/cas.xqm";:)
import module namespace cas = "http://oppidoc.com/ns/cas" at "../lib/cas-expath.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../lib/access.xqm";

(: ======================================================================
   Throw any message tagged at "login" in messages.xml
   ====================================================================== 
:)
declare function local:throw-announcement ( $sticky as xs:boolean ) {
  for $info in fn:doc(oppidum:path-to-config('messages.xml'))//info[@at eq 'login']
  return oppidum:add-message($info/@type, (), $sticky)
};

(: ======================================================================
   Generates success response
   ======================================================================
:)
declare function local:gen-success( $user as xs:string ) as element() {
  let $profile := access:get-current-person-profile()
  let $is-kam := exists($profile//Role[FunctionRef = '5'])
  let $is-kamco := exists($profile//Role[FunctionRef = '3'])
  let $is-admin := exists($profile//Role[FunctionRef = '1'])
  return
    (
    local:throw-announcement(true()),
    oppidum:add-message('ACTION-LOGIN-SUCCESS', $user, true()),
    if ($is-admin or $is-kam or $is-kamco) then
      oppidum:add-message('OTF-ADVERT', (), true())
    else
      (),
    if ($profile//Role/FunctionRef  = ('11', '13', '8', '7', '9', '2', '10', '1')) then
      (: only for omnisight users ~ EASME :)
      let $hours := string(sum(fn:collection($globals:projects-uri)//Case//TotalNbOfHours[. castable as xs:integer]))
      return 
        oppidum:add-message('ACTION-LOGIN-INFO', $hours, true())
    else
      ()
    )[last()]
};

(: ======================================================================
   Pre-production stats
   /db/debug/login.xml rwu-wu-wu with root Logs
   Some browsers (Safari) does not validate required attribute hence filters out empty user
   ======================================================================
:)
declare function local:log-action( $outcome as xs:string, $user as xs:string, $ua as xs:string? ) {
  if ($user ne '') then
    let $ts := substring(string(current-dateTime()), 1, 19)
    return
      if (fn:doc-available('/db/debug/login.xml')) then
        update insert <Login User="{$user}" TS="{$ts}" UA="{$ua}">{$outcome}</Login> into fn:doc('/db/debug/login.xml')/Logs
      else
        ()
  else
    ()
};

(: ======================================================================
   Adds a warning message in dev or test mode using either an error
   or a message (note: use a message if you need AXEL to be loaded see skin.xml)
   ====================================================================== 
:)
declare function local:warn( $cmd as element(), $err as xs:boolean ) {
  let $warn := 
    if ($cmd/@mode eq 'test') then
      'MODE-WARNING-TEST'
    else if ($cmd/@mode eq 'dev') then
      'MODE-WARNING-DEV'
    else
      ()
  return
    if ($warn) then
      if ($err) then
        oppidum:add-error($warn, (), true())
      else
        oppidum:add-message($warn, (), true())
    else
      ()
};

(: ======================================================================
   Returns true() in case current time is within [$sd, $sd + $duration]
   temporal window as defined on the Logs element of the optional login.xml
   resource as [@Shutdown, @Shutdown + @Duration]
   ====================================================================== 
:)
declare function local:shutdown( $sd as xs:string, $duration as xs:string ) as xs:boolean {
  let $date-time := string(current-dateTime())
  let $date := current-date()
  let $shutdown-ts := concat(substring-before(string($date), '+'),'T', $sd, ':00.000+', substring-after(string($date), '+'))
  let $after-ts := string(xs:dateTime($shutdown-ts) + xs:dayTimeDuration(concat("PT",substring-before($duration,':'),"H",substring-after($duration,':'),"M")))
  return $date-time gt $shutdown-ts and $date-time lt $after-ts
};

(: ======================================================================
   Rewrites the Goto URL to absolute path using command's base URL
   This way the redirection is independent from the reverse proxy in prod or test
   ======================================================================
:)
declare function local:rewrite-goto-url ( $cmd as element(), $url as xs:string? ) as xs:string {
  let $startref := fn:doc(oppidum:path-to-config('mapping.xml'))/site/@startref
  return
    if ($url and (substring-after($url, $cmd/@base-url) ne $startref)) then
      if (not(starts-with($url, '/'))) then
        concat($cmd/@base-url, $url)
      else 
        $url
    else (: overwrites startref redirection or no explicit redirection parameter :)
      let $goto := fn:doc(oppidum:path-to-config('settings.xml'))/Settings/Module[Name eq 'login']/Property[Key eq 'startref']
      return
        if ($goto) then
          concat($cmd/@base-url, $goto/Value)
        else
          concat($cmd/@base-url, $startref)
};

(: ======================================================================
   Generates the URL to send to third party CAS system to return back
   after authentification
   TODO: configure in settings.xml or in security.xml ?
   ====================================================================== 
:)
declare function local:gen-service-url( $cmd as element(), $goto-url as xs:string ) {
  let $addr :=
    if ($cmd/@mode eq 'prod') then
      'https://casetracker-smei.easme-web.eu'
    else if ($cmd/@mode eq 'test') then
      'https://casetracker-accp-smei.easme-web.eu'
    else
      'http://localhost:8080'
  return
    encode-for-uri(
      concat($addr, $cmd/@base-url, 'login?ecas=request&amp;url=', $goto-url)
    )
};

(: ======================================================================
   Generates login page model for rendering
   ====================================================================== 
:)
declare function local:gen-login-model( $user as xs:string, $ecas-on as xs:boolean, $goto-url as xs:string, $more as element()* ) as element()* {
  let $cmd := request:get-attribute('oppidum.command')
  return
    <Login ECAS="{$ecas-on}">
      <User>{ $user }</User>
      <To>{ $goto-url }</To>
      {
      if ($ecas-on) then <ECAS/> else (),
      if ($cmd/@mode = ('prod','test')) then <Production/> else (),
      $more,
      local:throw-announcement(false())
      }
    </Login>
};

(: ======================================================================
   Filters access. Returns either a page model to explain access is blocked
   or the empty sequence
   ====================================================================== 
:)
declare function local:block-access ( $user as xs:string, $ua as xs:string, $ecas-on as xs:boolean, $goto-url as xs:string ) as element()? {
  let $uua := upper-case($ua)
  let $ie := contains($uua, 'MSIE') or contains($uua, "TRIDENT") (: since IE 11:) or contains($uua, "EDGE") (: since Windows 10 :)
  return
   (: 1. Check Internet Explorer limitation :)
    if ($ie) then (
      local:log-action('ie', $user, $ua),
      local:gen-login-model( 
        $user, $ecas-on, $goto-url,
        oppidum:add-error('BROWSER-WARNING', ($ua), true())
        )
      )
    else
      let $shutdown := fn:doc('/db/debug/login.xml')/Logs/@Shutdown
      let $duration := fn:doc('/db/debug/login.xml')/Logs/@Duration
      let $hold := fn:doc('/db/debug/login.xml')/Logs/@Hold
      return
        (: 2. Check application on Hold :)
        if (not(empty($hold)) and ($user ne string($hold))) then
          local:gen-login-model( 
            $user, $ecas-on, $goto-url,
            (oppidum:add-error('HOLD', (), true()), <Hold/>)
          )
        (: 3. Check application on Shutdown :)
        else if (not(empty($shutdown) or empty($duration)) and local:shutdown($shutdown, $duration)) then
          let $sd := concat( $shutdown, ':00')
          let $readable-end := string(xs:time($sd) + xs:dayTimeDuration(concat("PT",substring-before($duration,':'),"H",substring-after($duration,':'),"M")))
          return 
            local:gen-login-model( 
              $user, $ecas-on, $goto-url,
              oppidum:add-error('SHUTDOWN', ($sd, $readable-end), true())
            )
        else 
          () 
};

declare function local:assert-property( $name as xs:string, $value as xs:string ) as xs:boolean {
  let $prop := 
fn:doc(oppidum:path-to-config('settings.xml'))/Settings/Module[Name eq 'login']/Property[Key eq $name]/Value
  return 
    exists($prop) and ($prop eq $value)
};

(: ======================================================================
   Simulate a CAS login (should be called only in dev mode)
   Does not care about password
   Use this in dev to login with any user account
   ====================================================================== 
:)
declare function local:POST-simulate-login( $cmd as element(), $username as xs:string, $realm as xs:string, $goto-url as xs:string, $ua as xs:string? ) {
  let $res := cas:login-as-cas($realm, $username, (), ())
  return
    if (not(exists($res)) or local-name($res) ne 'error') then (: check account existence :)
      let $account := fn:collection($globals:persons-uri)//Person[UserProfile/Remote eq $username and UserProfile/Remote/@Name = $realm]
      return
        if (exists($account)) then (
          local:log-action('ecas success (dev mode)', $username, $ua),
          local:gen-success($username),
          oppidum:redirect($goto-url),
          <Redirected>{$goto-url}</Redirected>
          )[last()]
        else (
          (: cancel login :)
          xdb:login("/db", "guest", "guest"),
          local:log-action('failure (dev mode)', $username, $ua),
          local:warn($cmd, true()),
          oppidum:add-error('ACTION-LOGIN-FAILED', (), true())
          )[last()]
    else
      $res
};
  
let $cmd := request:get-attribute('oppidum.command')
let $ua := request:get-header('user-agent')
let $user := request:get-parameter('user', '')
let $goto-url := local:rewrite-goto-url($cmd, request:get-parameter('url', ()))
let $ecas-on := local:assert-property('ecas', 'on')
let $blocked := local:block-access($user, $ua, $ecas-on, $goto-url)
return
  if ($blocked) then
    $blocked
  else 
    let $m := request:get-method()
    let $realm-name := 'ECAS'
    let $this := local:rewrite-goto-url($cmd, 'login')
    let $ecas := request:get-parameter(lower-case($realm-name), '')  
    return
      (: user click on ECAS button => redirection :)
      if ($ecas-on and ($ecas eq 'init')) then 
        let $res := cas:init-login($realm-name, 'ecas.init', ('service', 'acceptStrengths'), (local:gen-service-url($cmd, $goto-url), 'PASSWORD'), $this)
        return
          if (local-name($res) = 'error') then
            $res
          else
          (
            cas:goto-login($realm-name, 'ecas.login', 'loginRequestId', normalize-space($res)),
            <GoToECAS/>
          )[last()]
      (: if logging on has been successful :)
      else if ($ecas-on and ($ecas eq 'request')) then
        let $ticket := request:get-parameter('ticket', '')
        let $followup := request:get-parameter('followup', '')
        let $service-url :=
          if ($followup ne '') then
            encode-for-uri(
              concat('https://casetracker-accp-smei.easme-web.eu/login?ecas=request&amp;url=', $goto-url, '&amp;followup=', $followup)
            )
          else
            local:gen-service-url($cmd, request:get-parameter('url', $goto-url))
        let $res := cas:validate($realm-name, 'ecas.validation', ('service', 'ticket', 'userDetails'), ($service-url, $ticket, 'true'), $this)
        return 
          if (local-name($res) = 'error') then (
            local:log-action('ecas failure', $res/message/@type, $ua),
            $res
            )
          else
            if ($followup ne '') then
              <Redirected>
                {
                oppidum:redirect(concat($followup, '/login?ecas=followup&amp;url=', request:get-parameter('url','') ,'&amp;username=', $res/username,'&amp;email=', $res/email))
                }
              </Redirected>
            else
              let $done := cas:login-as-cas($realm-name, $res/username, $res, ())
              (: last param empty implies login w/o redirecting :)
              return
                if (local-name($done) ne 'error') then (
                  local:log-action('ecas success', $res/username, $ua),
                  local:gen-success($res/username),
                  if (cas:has-user-profile-in-realm($realm-name)) then
                    <Redirected>
                      {
                      oppidum:redirect(local:rewrite-goto-url($cmd, request:get-parameter('url', $goto-url))) 
                      }
                    </Redirected>
                  else
                    <Redirected>
                      { 
                      session:set-attribute('cas-merge', 'pending'),
                      oppidum:redirect(local:rewrite-goto-url($cmd, 'login?ecas=check'))
                      }
                    </Redirected>
                  )[last()]
                else (
                  local:log-action('ecas failure', $res/username, $ua),
                  $done
                  )
      else
        let $cas-user := session:get-attribute('cas-user')
        let $more := 
          (: user logged by cas module for first time, tries to complete pre-registered account or to ask for a merge :)
          if ($m = 'GET' and $ecas eq 'check' and exists($cas-user)) then
            if (cas:has-predefined-profile-in-realm($realm-name)) then (
              cas:create-profile($realm-name, $cas-user//key, $goto-url),
              local:log-action('complete success', $cas-user//key, $ua),
              <SuccessfulMerge>{ $goto-url }</SuccessfulMerge>
              )[last()]
            else (
              local:log-action('check', $cas-user//key, $ua),
              <Check/>
              )
          (: login credentials submission using internal realm :)
          else if ($m = 'POST') then
            (: follow-up to a Check for merging accounts :)
            if ((session:get-attribute('cas-merge') eq 'pending') and exists($cas-user)) then (
              let $password := request:get-parameter('password', '')
              return
                (: user is what s/he claims, merges accounts :)
                if (xdb:login('/db', $user, $password, true())) then
                  let $goto := local:rewrite-goto-url($cmd, $goto-url)
                  return
                    (
                    cas:merge('ECAS', $cas-user//key, $user),
                    local:log-action('merge success', concat($user, ' with ', $cas-user//key), $ua),
                    cas:login-as-cas('ECAS', $cas-user//key, (), $goto),
                    oppidum:add-message('ACTION-LOGIN-SUCCESS-MERGE', (), true()),
                    <SuccessfulMerge>{ $goto }</SuccessfulMerge>
                    )[last()]
                (: force ECAS exist-db user logout as merging can't be processed  :)
                else 
                  (
                  local:log-action('merge failure', concat($user, ' with ', $cas-user//key), $ua),
                  xdb:login("/db", "guest", "guest"),
                  oppidum:redirect(local:rewrite-goto-url($cmd, $cmd/@base-url)),
                  oppidum:add-error('ACTION-LOGIN-FAILED', (), true())
                  )[last()],
                session:set-attribute('cas-merge', 'over')
                )
            else if ($cmd/@mode eq 'dev') then
              local:POST-simulate-login($cmd, $user, 'ECAS', $goto-url, $ua)
            else
              (: DEPRECATED: tries to login, ask oppidum to redirect on success :)
              let $password := request:get-parameter('password', '')
              return
                if (xdb:login('/db', $user, $password, true())) then
                  let $realm-name := 'EXIST' (: replaces 'ECAS' :)
                  let $model := fn:doc(oppidum:path-to-config('security.xml'))//Realm[@Name eq 'EXIST']
                  let $session:= $model//Variable[Name eq 'Session']/Expression
                  return (
                    if ($session) then session:set-attribute('cas-user', util:eval($session)) else (),
                    local:log-action('success', $user, $ua),
                    local:warn($cmd, false()),
                    local:gen-success($user),
                    oppidum:redirect($goto-url),
                    <Redirected>{$goto-url}</Redirected>
                    )[last()]
                else (: login page model, asks again, keeps user because wrong password in most cases :)
                  (
                  local:log-action('failure', $user, $ua),
                  local:warn($cmd, true()),
                  oppidum:add-error('ACTION-LOGIN-FAILED', (), true())
                  )[last()]
          else
            local:warn($cmd, true())
        return
          local:gen-login-model($user, $ecas-on, $goto-url, $more)

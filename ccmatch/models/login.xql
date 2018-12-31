xquery version "1.0";
(: --------------------------------------
   CCMATCH - EIC Coach Match Application

   Authors: 
   - Stéphane Sire <s.sire@oppidoc.fr>
   - Frédéric Dumonceau <Frederic.DUMONCEAUX@ext.ec.europa.eu>

   Either generates the login page model to ask the user to login or tries to login
   the user if credentials are supplied and redirects on success.

   The optional request parameter 'url' contains the full path of a site page
   to redirect the user after a successful login.

   Also manages remote login using CAS (centralized access control) service
   such as EU Login (could be adapted for OAuth2)

   TODO: share code in lib/login.xqm

   September 2015 - European Union Public Licence EUPL
   -------------------------------------- :)
   
import module namespace xdb = "http://exist-db.org/xquery/xmldb";
import module namespace session = "http://exist-db.org/xquery/session";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../lib/globals.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "../lib/access.xqm";
import module namespace request = "http://exist-db.org/xquery/request";
import module namespace cas = "http://oppidoc.com/ns/cas" at "../lib/cas.xqm";

declare option exist:serialize "method=xml media-type=application/xml";

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
  let $is-coach := some $f in $profile//FunctionRef satisfies $f eq '4'
  let $is-other := some $f in $profile//FunctionRef satisfies $f ne '4'
  return (
    local:throw-announcement(true()),
    if ($is-coach and not($is-other)) then
      oppidum:add-message('ACTION-LOGIN-SUCCESS', $user, true())
    else (: adds coach summary message :)
      let $avail := string(count(fn:collection('/db/sites/ccmatch/persons')//Person[not(Preferences/NoCoaching)][.//FunctionRef = '4']))
      let $cv := string(count(fn:collection('/db/sites/ccmatch/persons')//Person[not(Preferences/NoCoaching)][.//FunctionRef = '4'][Resources/CV-File]))
      return
        oppidum:add-message('ACTION-LOGIN-SUCCESS-INFO', ($user, $avail, $cv), true()),
    oppidum:add-message('ACTION-LOGIN-HINT', (), true())
    )[1]
};

(: ======================================================================
   Pre-production stats
   /db/debug/login.xml rwu-wu-wu with root Logs
   Some browsers (Safari) does not validate required attribute hence filters out empty user
   ======================================================================
:)
declare function local:log-action( $outcome as xs:string, $user as xs:string ) {
  if ($user ne '') then
    let $ua := request:get-header('user-agent')
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
declare function local:rewrite-goto-url ( $cmd as element(), $url as xs:string ) as xs:string {
  if (not(starts-with($url, '/'))) then
    concat($cmd/@base-url, $url)
  else 
    $url
};

(: ======================================================================
   Generates the URL to send to third party CAS system to return back
   after authentification

   FIXME: localhost:7070 ?
   ====================================================================== 
:)
declare function local:gen-service-url( $cmd as element(), $goto-url as xs:string ) {
  let $addr :=
    if ($cmd/@mode eq 'prod') then
      'https://coachmatch-smei.easme-web.eu'
    else if ($cmd/@mode eq 'test') then
      'https://coachmatch-accp-smei.easme-web.eu'
    else
      'http://localhost:7070'
  return
    encode-for-uri(
      concat($addr, $cmd/@base-url, 'login?ecas=request&amp;url=', $goto-url)
    )
};

(: ======================================================================
   Generates login page model for rendering
   Note that the User element is useful only if you can login using
   the internal EXIST realm (it persists user name in case of wrong password)
   ====================================================================== 
:)
declare function local:gen-login-model( $user as xs:string, $cas-enabled as xs:boolean, $goto-url as xs:string, $more as element()* ) as element()* {
  let $cmd := request:get-attribute('oppidum.command')
  return
    <Login ECAS="{$cas-enabled}">
      <User>{ if (($user != '') and xdb:exists-user($user)) then $user else () }</User>
      <To>{ $goto-url }</To>
      {
      if ($cas-enabled) then <ECAS/> else (),
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
declare function local:block-access ( $user as xs:string, $cas-enabled as xs:boolean, $goto-url as xs:string ) as element()? {
  let $ua := request:get-header('user-agent')
  let $uua := upper-case($ua)
  let $ie := contains($uua, 'MSIE') or contains($uua, "TRIDENT") (: since IE 11:) or contains($uua, "EDGE") (: since Windows 10 :)
  return
   (: 1. Check Internet Explorer limitation :)
    if ($ie) then (
      local:log-action('ie', $user),
      local:gen-login-model( 
        $user, $cas-enabled, $goto-url,
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
            $user, $cas-enabled, $goto-url,
            (oppidum:add-error('HOLD', (), true()), <Hold/>)
          )
        (: 3. Check application on Shutdown :)
        else if (not(empty($shutdown) or empty($duration)) and local:shutdown($shutdown, $duration)) then
          let $sd := concat( $shutdown, ':00')
          let $readable-end := string(xs:time($sd) + xs:dayTimeDuration(concat("PT",substring-before($duration,':'),"H",substring-after($duration,':'),"M")))
          return 
            local:gen-login-model( 
              $user, $cas-enabled, $goto-url,
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
   Launches remote login interaction by redirecting to remote login page 
   ====================================================================== 
:)
declare function local:GET-init-cas-login ( $cmd as element(), $realm-name as xs:string, $goto-url as xs:string ) {
  let $res := cas:init-login(
                $realm-name, 
                'ecas.init', 
                ('service', 'acceptStrengths'),
                (local:gen-service-url($cmd, $goto-url), 'PASSWORD'), 
                local:rewrite-goto-url($cmd, 'login')
                )
  return
    if (local-name($res) = 'error') then
      $res
    else
    (
      cas:goto-login($realm-name, 'ecas.login', 'loginRequestId', normalize-space($res)),
      <GoToECAS/>
    )[last()]
};

(: ======================================================================
   Validates the remote login ticket received in response
   Redirects either to user home page or starts dialog to merge accounts 
   when first remote login
   ====================================================================== 
:)
declare function local:GET-validate-cas-login( $cmd as element(), $realm-name as xs:string, $goto-url as xs:string ) {
  let $ticket := request:get-parameter('ticket', '')
  let $res := cas:validate(
              $realm-name, 
              'ecas.validation', 
              ('service', 'ticket', 'userDetails'), 
              (local:gen-service-url($cmd, $goto-url), $ticket, 'true'), 
              local:rewrite-goto-url($cmd, 'login')
              )
  return 
    if (local-name($res) eq 'error') then (
      local:log-action('ecas failure', $res/message/@type),
      $res
      )
    else (
      cas:login-as-cas($realm-name, $res/username, $res, ()),
      local:log-action('ecas success', $res/username),
      if (cas:has-user-profile-in-realm($realm-name)) then (: known user :)
        <Redirected>
          { 
          local:gen-success($res/username),
          oppidum:redirect(
            local:rewrite-goto-url($cmd, access:mapping-from-username($res/username))
            )
          }
        </Redirected>
      else  (: first time remote login :)
        <Redirected>
          {
          session:set-attribute('cas-merge', 'pending'),
          oppidum:redirect(local:rewrite-goto-url($cmd, 'login?ecas=check'))
          }
        </Redirected>
    )[last()]
};

(: ======================================================================
   Handles GET request to implement remote login success landing hook
   or to display the login page
   ====================================================================== 
:)
declare function local:GET-login-page ( $cmd as element(), $realm-name as xs:string, $goto-url as xs:string ) {
  let $cas-user := session:get-attribute('cas-user')
  let $ecas := request:get-parameter(lower-case($realm-name), '')
  return
    if (($ecas eq 'check') and exists($cas-user)) then (: 1st time external login :)
      if (cas:has-predefined-profile-in-realm($realm-name)) then (: completes pre-registered account :)
        (
        (: NOTE: should not be called, not applicable to Coach Match (no pre-registration) :)
        cas:create-profile($realm-name, $cas-user//key, $goto-url),
        local:log-action('complete success', $cas-user//key),
        <SuccessfulMerge>{ $goto-url }</SuccessfulMerge>
        )[last()]
      else (: asks to merge :)
        (
        local:log-action('check', $cas-user//key),
        <Check Email="notfound"/>,
        <Register/>
        )
    else (: plain login page model with optional mode information and login failed error message :)
      local:warn($cmd, true())
};

(: ======================================================================
   Implements internal login using eXist-DB user accounts
   Asks oppidum to redirect on success
   ====================================================================== 
:)
declare function local:POST-internal-login( $cmd as element(), $user as xs:string, $goto-url as xs:string ) {
  let $password := request:get-parameter('password', '')
  return
    (: successuful login on internal realm, setup virtual EXIST realm :)
    if (xdb:login('/db', $user, $password, true())) then
      let $realm-name := 'EXIST' (: virtual realm for oppidum:get-user-groups :)
      let $model := fn:doc(oppidum:path-to-config('security.xml'))//Realm[@Name eq 'EXIST']
      let $session:= $model//Variable[Name eq 'Session']/Expression
      return (
        if ($session) then session:set-attribute('cas-user', util:eval($session)) else (),
        local:log-action('success', $user),
        local:warn($cmd, false()),
        local:gen-success($user),
        <Redirected>
          {
          oppidum:redirect(
            local:rewrite-goto-url($cmd, access:mapping-from-username($user))
            )
          }
        </Redirected>
        )[last()]
    (: failed to log using internal realm, asks again :)
    else
      (
      local:log-action('failure', $user),
      local:warn($cmd, true()),
      oppidum:add-error('ACTION-LOGIN-FAILED', (), true())
      )[last()]
};

(: ======================================================================
   Implements second login to follow-up a Check for merging with CAS account
   ====================================================================== 
:)
declare function local:POST-merge-accounts( $cmd as element(), $user as xs:string, $realm-name as xs:string, $goto-url as xs:string ) {
  let $cas-user := session:get-attribute('cas-user')
  let $password := request:get-parameter('password', '')
  return
    (: merges accounts when user is what s/he claims :)
    if (xdb:login('/db', $user, $password, true())) then 
      let $username := $cas-user//key
      return
        (
        cas:merge($realm-name, $username, $user),
        local:log-action('merge success', concat($user, ' with ', $username)), (: FIXME: assess success :)
        let $done := cas:login-as-cas($realm-name, $username, (), (: FIXME: preserve 'ecas-res' in third parameter ? :)
                      local:rewrite-goto-url($cmd, access:mapping-from-username($username)))
        return
          if (local-name($done) ne 'error') then (
            oppidum:add-message('ACTION-LOGIN-SUCCESS-MERGE', (), true()),
            <SuccessfulMerge>{ $username }</SuccessfulMerge>
            )
          else
            $done
        )[last()]
    (: forces cas eXist-db user logout as merging can't be processed  :)
    else 
      (
      local:log-action('merge failure', concat($user, ' with ', $cas-user//key)),
      xdb:login("/db", "guest", "guest"),
      oppidum:redirect(local:rewrite-goto-url($cmd, $cmd/@base-url)),
      oppidum:add-error('ACTION-LOGIN-FAILED', (), true())
      )[last()]
};

(: ======================================================================
   Simulate a CAS login (should be called only in dev mode)
   Does not care about password
   Use this in dev to login with any user account
   ====================================================================== 
:)
declare function local:POST-simulate-login( $cmd as element(), $username as xs:string, $realm as xs:string, $goto-url as xs:string ) {
  let $res := cas:login-as-cas($realm, $username, (), ())
  return
    if (not(exists($res)) or local-name($res) ne 'error') then (: check account existence :)
      let $account := fn:collection($globals:persons-uri)//Person[UserProfile/Remote eq $username and UserProfile/Remote/@Name = $realm]
      return
        if (exists($account)) then (
          local:log-action('ecas success (dev mode)', $username),
          local:gen-success($username),
          oppidum:redirect($goto-url),
          <Redirected>{$goto-url}</Redirected>
          )[last()]
        else (
          (: cancel login :)
          xdb:login("/db", "guest", "guest"),
          local:log-action('failure (dev mode)', $username),
          local:warn($cmd, true()),
          oppidum:add-error('ACTION-LOGIN-FAILED', (), true())
          )[last()]
    else
      $res
};

(: *** MAIN ENTRY POINT *** :)
let $cmd := request:get-attribute('oppidum.command')
let $user := request:get-parameter('user', '')
let $cas-enabled := local:assert-property('ecas', 'on')
let $goto-url := local:rewrite-goto-url($cmd,request:get-parameter('url', $user))
let $blocked := local:block-access($user, $cas-enabled, $goto-url)
return
  if ($blocked) then
    $blocked
  else 
    let $realm-name := 'ECAS'
    let $ecas := request:get-parameter(lower-case($realm-name), '')
    return
      if ($cas-enabled and ($ecas eq 'init')) then (: EU Login button => redirection :)
        local:GET-init-cas-login($cmd, $realm-name, $goto-url)
      else if ($cas-enabled and ($ecas eq 'request')) then (: EU Login response processing :)
        local:GET-validate-cas-login($cmd, $realm-name, $goto-url)
      else
        let $m := request:get-method()
        let $cas-user := session:get-attribute('cas-user')
        return
          local:gen-login-model(
            $user,
            $cas-enabled,
            $goto-url,
            if ($m = 'GET') then
              local:GET-login-page($cmd, $realm-name, $goto-url)
            else if ($m = 'POST') then (: internal login form submission :)
              if (session:get-attribute('cas-merge') eq 'pending') then (
                local:POST-merge-accounts($cmd, $user, $realm-name, $goto-url),
                session:set-attribute('cas-merge', 'over')
                )
              else if ($cmd/@mode eq 'dev') then
                local:POST-simulate-login($cmd, $user, 'ECAS', $goto-url)
              else (: DEPRECATED: not used any more since EU Login :)
                local:POST-internal-login($cmd, $user, $goto-url)
            else (: unkown :)
              ()
            )

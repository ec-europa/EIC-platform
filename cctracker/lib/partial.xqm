xquery version "1.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC XQuery Content Management Framework

   Creation: Stéphane Sire <s.sire@opppidoc.fr>

   This modules contains functions using XPath expressions with no namespace
   to be called from epilogue.xql which is in the default XHTML namespace.

   April 2015 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

module namespace partial = "http://oppidoc.com/oppidum/partial";

declare namespace xdb = "http://exist-db.org/xquery/xmldb";
declare namespace session = "http://exist-db.org/xquery/session";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "globals.xqm";
import module namespace access = "http://oppidoc.com/oppidum/access" at "access.xqm";

(: Sets time in minute before kick out in maintenance mode :)
declare variable $partial:kick-out-delay := 5;

(: ======================================================================
   Checks if the application is in maintenance mode with kick out option
   to ask users to logout and kick them out after a minimum notification time.
   Note that Oppidum messages will be rendered immediately after leaving the function
   ======================================================================
:)
declare function partial:filter-for-maintenance ( $cmd as element(), $isa_tpl as xs:boolean ) {
  if ( not($isa_tpl)
       and (fn:doc($globals:log-file-uri)/Logs/@KickOut eq 'on')
       and not($cmd/@action = ('logout', 'login')) ) then (: kick out users for maintenance :)

    let $user := oppidum:get-current-user()
    return
      if ((fn:doc($globals:log-file-uri)/Logs/@Hold ne $user) and session:exists()) then
        let $warned := session:get-attribute('kick-out')
        return
          if (empty($warned)) then (
            session:set-attribute('kick-out', current-dateTime()),
            oppidum:add-message('ASK-LOGOUT', concat($partial:kick-out-delay, ' minutes'), false())
            )
          else (: tester le temps et delogger de force... :)
            let $ellapsed := current-dateTime() - $warned
            return
              if ($ellapsed > xs:dayTimeDuration(concat('PT', $partial:kick-out-delay, 'M'))) then (
                oppidum:add-error('LOGOUT-FOR-MAINTENANCE', (), true()),
                oppidum:add-message('ACTION-LOGOUT-SUCCESS', (), true()),
                xdb:login("/db", "guest", "guest"),
                let $ts := substring(string(current-dateTime()), 1, 19)
                return
                  update insert <Logout User="{$user}" TS="{$ts}">forced</Logout> into fn:doc($globals:log-file-uri)/Logs
                )
              else
                let $minutes := $partial:kick-out-delay - minutes-from-duration($ellapsed)
                return
                  oppidum:add-message('ASK-LOGOUT', if ($minutes > 0) then concat($minutes, ' minutes') else 'less than 1 minute', false())
    else
      ()
  else
    ()
};


(: ======================================================================
   Generates the content of a menu, one item per Call
   ======================================================================
:)
declare function partial:gen-call-menu ( $base as xs:string, $action as xs:string, $lang as xs:string, $threemthago as xs:string, $today as xs:string) as element()* {
      (:for $cut at $i in fn:collection($globals:global-info-uri)//Description[@Lang = $lang]//Selector[@Name eq 'CallRollOuts']/Option:)
      for $opt in fn:collection($globals:global-info-uri)//Selector[@Name = ('SMEiCalls', 'FETCalls')]//Selector/Option
      let $date := concat(substring($opt/Name, 7,4),'-',substring($opt/Name, 4,2),'-',substring($opt/Name, 1,2))
      let $master := $opt/../../../@Name
      where not($today le $date) and (not($action eq 'assign' and $master eq 'SMEiCalls') or ($threemthago le $date))
      return
        <li><a target="_blank" href="{$base}calls/{$opt/Code}/{$action}">{ concat($master, ' ', $opt/Name ) }</a></li>
};

(: ======================================================================
   Generates a menu, one item per Call
   ======================================================================
:)
declare function partial:gen-call-menu ( $base as xs:string, $action as xs:string, $lang as xs:string ) as element() {
  let $threemthago := substring(string(current-date() - xs:dayTimeDuration('P90D')), 1, 10)
  let $today := substring(string(current-date()), 1, 10)
  return
  <ul class="dropdown-menu" xmlns="http://www.w3.org/1999/xhtml">
    {
      partial:gen-call-menu ($base ,$action ,$lang ,$threemthago ,$today)
    }
  </ul>
};

(: ======================================================================
   Generates the content of the todo menu
   ======================================================================
:)
declare function partial:gen-todos-menu ( $checks as element()*, $base as xs:string, $user as xs:string, $groups as xs:string* ) as element()* {
  for $c in $checks
    let $cached := fn:collection($globals:checks-uri)//Check[@No eq $c/@No]
    let $anchor := concat("#", $c/@No, " ", $c/Title/text())
    return
      <li xmlns="http://www.w3.org/1999/xhtml">
        <a target="_blank" href="{$base}alerts/{$c/@No}">
          {
          if (empty($cached)) then
            concat($anchor, " (?)")
          else if ($cached/@Total eq '0') then
            concat($anchor, " (0)")
          else (
            concat($anchor, " ("),
            <span class="over">{string($cached/@Total)}</span>,
            ")"
            )
          }
        </a>
      </li>
};

(: ======================================================================
   Generates the todo menu
   ======================================================================
:)
declare function partial:gen-todos-menu ( $base as xs:string, $user as xs:string, $groups as xs:string* ) as element()? {
  let $checks := fn:doc('/db/www/cctracker/config/checks.xml')//Check[@No]
  return
    if (empty($checks)) then
      ()
    else if ($groups = ('admin-system', 'coaching-assistant', 'coaching-manager')) then
      (: groups with holistic view :)
      <li class="dropdown" xmlns="http://www.w3.org/1999/xhtml">
        <a class="dropdown-toggle" data-toggle="dropdown" href="#">To do</a>
        <ul class="dropdown-menu">
          {
            partial:gen-todos-menu ( $checks, $base, $user, $groups )
          }
          <li class="divider"></li>
          <li><a target="_blank" href="{$base}reminders">Show latest Reminders</a></li>
        </ul>
      </li>
    else (: alerts for semantic roles :)
      let $user-ref := access:get-current-person-id()
      let $todos := fn:collection('/db/sites/cctracker/checks/')//Case[ReRef eq $user-ref]
      let $count := count($todos)
      return
        if ($count > 0) then
          <li xmlns="http://www.w3.org/1999/xhtml"><a href="{$base}alerts" class="over">To do (<span class="over">{ $count }</span>)</a></li>
        else
          <li xmlns="http://www.w3.org/1999/xhtml"><a href="{$base}alerts">To do</a></li>
};

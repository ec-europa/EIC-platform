xquery version "1.0";
(: ------------------------------------------------------------------
   CCMATCH - EIC Coach Match Application

   Creation: Stéphane Sire <s.sire@opppidoc.fr>

   This modules contains functions using XPath expressions with no namespace
   to be called from epilogue.xql which is in the default XHTML namespace.

   September 2015 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

module namespace partial = "http://oppidoc.com/oppidum/partial";

declare namespace xdb = "http://exist-db.org/xquery/xmldb";
declare namespace session = "http://exist-db.org/xquery/session";

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../oppidum/lib/util.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "globals.xqm";

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


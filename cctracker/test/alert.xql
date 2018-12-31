xquery version "1.0";
(: ------------------------------------------------------------------
   CCTRACKER - EIC Case Tracker Application

   Author: Stéphane Sire <s.sire@opppidoc.fr>

   This script should allow to test all possible notification messages
   using data from a sample Case/Activity from the database

   Note that after running that script you should restore the sample 
   Case/Activity since the script will save generated messages into alerts

   DO NOT run this script on production server since that would results 
   in sending real e-mail to end users !!!

   TEST PLAN
   - alerts on Transition elements in application.xml for Case and Activity
   - Email reminders sent at elapsed time on Check elements in alerts/checks.xml 
   - other notification e-mail sent on other end-user actions :
     * e-mail to ask SME confirmation of coaching plan
     * e-mail automatically sent EASME 

   January 2016 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

import module namespace request="http://exist-db.org/xquery/request";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../lib/globals.xqm";
import module namespace workflow = "http://platinn.ch/coaching/workflow" at "../modules/workflow/workflow.xqm";
import module namespace alert = "http://oppidoc.com/ns/cctracker/alert" at "../modules/workflow/alert.xqm";
import module namespace media = "http://oppidoc.com/ns/cctracker/media" at "../lib/media.xqm";
import module namespace email = "http://oppidoc.com/ns/cctracker/mail" at "../lib/mail.xqm";

declare function local:gen-transitions-for( $workflow as xs:string, $case as element(), $activity as element()? ) as element()* {
  for $t in fn:doc('/db/www/cctracker/config/application.xml')//Workflow[@Id = $workflow]//Transition
  return 
    <Transition From="{ $t/@From }" To="{ $t/@To }">
    {
    for $mail in $t/Email
    return 
      <Automatic Template="{ $mail/@Template }">
        {
        alert:notify-transition($t, $workflow, $case, $activity, $mail/@Template, $mail/Recipients)
        }
      </Automatic>,
    if ($t/@Template) then
      element { if ($t/@Mail eq 'direct') then 'Direct' else 'Manual' }
      { 
        attribute { 'Template' } { $t/@Template },
        alert:notify-transition($t, $workflow, $case, $activity, $t/@Template, $t/Recipients)
      }
    else if ($t/Recipients) then
      element { if ($t/@Mail eq 'direct') then 'Direct' else 'Manual' }
      { 
        attribute { 'Template' } { concat(lower-case($workflow), '-workflow-alert') },
        alert:notify-transition($t, $workflow, $case, $activity, $t/@Template, $t/Recipients)
      }
    else
      ()
    }
    </Transition>
};

declare function local:gen-all-transitions ( $case as element(), $activity as element()? ) {
  <Workflow>
    <Cases>
      {
      local:gen-transitions-for('Case', $case, ())
      }
    </Cases>
    <Activities>
      {
      local:gen-transitions-for('Activity', $case, $activity)
      }
    </Activities>
  </Workflow>
};


(: You MUST enter a Case / Activity at a late status to get all data in variables :)
let $case-no := '274'
let $case := fn:collection($globals:cases-uri)/Case[No = $case-no]
let $activity-no := '1'
let $activity := $case/Activities/Activity[No = $activity-no]
let $transition := workflow:get-transition-for('Case', '2', '3')
(: Fake pipeline to allow calls to functions such as oppidum:throw-message :)
let $pipeline := request:set-attribute('oppidum.pipeline', <pipeline/>)
let $command := request:set-attribute('oppidum.command', <command confbase="/db/www/cctracker" lang="en"/>)
return
  <Test>
    { local:gen-all-transitions($case, $activity) }
  </Test>

(:
  
CUT-AND-PASTE for manual testing of ...

{ $transition }
{ $pipeline }
{ email:render-alert('kam-notification', 'en', $case, $activity) }
{ email:gen-variables-for('kam-notification', 'en', (), (), ()) }
{ alert:notify-transition($transition, 'Case', $case, $activity, $transition/Email/@Template, $transition/Email/Recipients) }
  
:)

import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../lib/globals.xqm";
import module namespace check = "http://oppidoc.com/ns/cctracker/alert/check" at "../modules/alerts/check.xqm";
import module namespace email = "http://oppidoc.com/ns/cctracker/mail" at "../lib/mail.xqm";

declare option exist:serialize "method=html media-type=text/html";

declare variable $local:checks-config-uri := '/db/www/cctracker/config/checks.xml';

<Test>
  {
    for $r in 
      for $check in fn:doc($local:checks-config-uri)//Check
      return check:reminders-for-check($check)
    return
      <p>Case <a target="_blank" href="../cases/{ $r/@CaseNo }">{ string($r/@CaseNo) }</a> { if ($r/@ActivityNo) then (<span>Activity </span>, <a target="_blank" href="../cases/{ $r/@CaseNo }/activities/{ $r/@ActivityNo }">{ string($r/@ActivityNo) }</a>) else () } : { $r/Template/text() } at { string($r/@Elapsed) } days</p> 
  }
  {
  (: You MUST enter a Case / Activity at a late status to get all data in variables :)
  let $project-no := '815904'
  let $project := fn:collection($globals:projects-uri)/Project[Id eq $project-no]
  let $case-no := '1'
  let $case := $project//Case[No = $case-no]
  let $activity-no := '1'
  let $activity := $case/Activities/Activity[No = $activity-no]
  (: Fake pipeline to allow calls to functions such as oppidum:throw-message :)
  let $pipeline := request:set-attribute('oppidum.pipeline', <pipeline/>)
  let $command := request:set-attribute('oppidum.command', <command confbase="/db/www/cctracker" lang="en"/>)
  return
  <Test>
      { 
      for $email in fn:doc($local:checks-config-uri)//Email
      return
        <Render Template="{ $email/Template }">
          { email:render-alert($email/Template, 'en', $project, $case, $activity) }
        </Render>
      ,
      check:archive-reminders(
          check:apply-reminders(
            for $check in fn:doc($globals:checks-config-uri)//Check
            return check:reminders-for-check($check)
          ),
          current-dateTime()
        )
      }
    </Test>

    
        
  }
</Test>

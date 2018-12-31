xquery version "3.0";
(: --------------------------------------
   Tasks Console
   -------------------------------------- :)

import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace tasks = "http://oppidoc.com/ns/application/tasks" at "tasks.xqm";
import module namespace tasks-interpretor = "http://oppidoc.com/ns/application/tasks-interpretor" at "tasks-interpretor.xqm";
import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace template = "http://oppidoc.com/ns/cctracker/template" at "../../lib/template.xqm";
import module namespace drupal = "http://oppidoc.com/ns/application/drupal" at "../community/drupal.xqm";
import module namespace system = "http://exist-db.org/xquery/system";
import module namespace account = "http://oppidoc.com/ns/account" at "../users/account.xqm";


(: ======================================================================
    Description:
     Generate the header of the console's table JOB
   ====================================================================== 
:)
declare function local:gen-job-table-header() as element() { 
    <tr>
      <th style="border: 1px solid #cdd0d4" scope="col"><code>Name</code></th>
      <th style="border: 1px solid #cdd0d4" scope="col"><code>Expression</code></th>
      <th style="border: 1px solid #cdd0d4" scope="col"><code>State</code></th>
      <th style="border: 1px solid #cdd0d4" scope="col"><code>Previous execution</code></th>
      <th style="border: 1px solid #cdd0d4" scope="col"><code>Next execution</code></th>      
    </tr>
};

(: =====================================================================================================================
    Description:
      Generate a row (for a task) of the listing table
      
      Parameter:
        $t: task to display 
   =====================================================================================================================
:)
declare function local:gen-job-sample($j as element()) as element() {
  <tr>
    <td style="border: 1px solid #cdd0d4"><code>{ concat(" ", $j/@name) }</code></td>
    <td style="border: 1px solid #cdd0d4"><code>{ concat(" ", $j//expression/text()) }</code></td>
    <td style="border: 1px solid #cdd0d4"><code>{ concat(" ", $j//state/text()) }</code></td>
    <td style="border: 1px solid #cdd0d4"><code>{ concat(" ", $j//previous/text()) }</code></td>
    <td style="border: 1px solid #cdd0d4"><code>{ concat(" ", $j//next/text()) }</code></td>
  </tr>
};

(: ======================================================================
    Description:
     Generate the header of the console's table
   ====================================================================== 
:)
declare function local:gen-table-header() as element() { 
    <tr>
      <th style="border: 1px solid #cdd0d4" scope="col"><code>Context</code></th>
      <th style="border: 1px solid #cdd0d4" scope="col"><code>Action name</code></th>
      <th style="border: 1px solid #cdd0d4" scope="col"><code>Coach Id</code></th>
      <th style="border: 1px solid #cdd0d4" scope="col"><code>Priority id</code></th>
      <th style="border: 1px solid #cdd0d4" scope="col"><code>Submission date</code></th>      
    </tr>
};
(: ======================================================================
    Description:
     Generate the header of the console's table
   ====================================================================== 
:)
declare function local:gen-table-header-currentTask() as element() { 
    <tr>
      <th style="border: 1px solid #cdd0d4" scope="col"><code>Context</code></th>
      <th style="border: 1px solid #cdd0d4" scope="col"><code>Action name</code></th>
      <th style="border: 1px solid #cdd0d4" scope="col"><code>Coach Id</code></th>
      <th style="border: 1px solid #cdd0d4" scope="col"><code>Priority id</code></th>
      <th style="border: 1px solid #cdd0d4" scope="col"><code>Send date</code></th>      
    </tr>
};

(: =====================================================================================================================
    Description:
      Generate a row (for a task) of the listing table
      
      Parameter:
        $t: task to display 
   =====================================================================================================================
:)
declare function local:gen-task-sample($t as element()) as element() {
  <tr>
    <td style="border: 1px solid #cdd0d4"><code>{ concat(" ", $t/@context) }</code></td>
    <td style="border: 1px solid #cdd0d4"><code>{ concat(" ", $t/@name) }</code></td>
    <td style="border: 1px solid #cdd0d4"><code>{ concat(" ", $t/@coach) }</code></td>
    <td style="border: 1px solid #cdd0d4"><code>{ concat(" ", $t/@priority) }</code></td>
    <td style="border: 1px solid #cdd0d4"><code>{
      if(exists($t/parent::CurrentTask)) then 
        concat(" ", $t/@send-date)
      else
        concat(" ", $t/@submission-date)
    }</code></td>
  </tr>
};

declare function local:timeFromDate
  ( $sentdate as xs:time? )  as xs:decimal? {
  let $duration := current-time() - $sentdate
  return
  $duration div xs:dayTimeDuration('PT1S')
 } ;


(: ======================================================================
    Description:
     Generate a listing table for tasks
   ====================================================================== 
:)
declare function local:fetch-task() {
   for $t in fn:doc($globals:tasks-uri)/Tasks/Task
   return
    local:gen-task-sample($t)   
};

(: ======================================================================
            <scheduler:job name="Tasks-chron">
                <scheduler:trigger name="Tasks-chron Trigger">
                    <expression>* * * ? * *</expression>
                    <state>NORMAL</state>
                    <start>2018-07-25T13:39:34+02:00</start>
                    <end/>
                    <previous>2018-07-25T15:22:01+02:00</previous>
                    <next>2018-07-25T15:22:01.521+02:00</next>
                    <final/>
                </scheduler:trigger>
            </scheduler:job>
      create / pause / resume / del      
   ====================================================================== 
:)           
declare function local:display-job() {
  let $job-property := globals:doc('settings-uri')/Settings/Module[Name eq "tasks"]/Property[Key/text() eq "job"]
  let $expression := $job-property/Expression
  let $name := $job-property/Name
  let $jobs := scheduler:get-scheduled-jobs()
  let $job :=  $jobs/scheduler:jobs/scheduler:group[@name eq 'eXist.User']/scheduler:job[@name eq $name]
  return
    if (exists($job)) then
      <div>
        <table>
          { local:gen-job-table-header() }
          <tbody>
          { if (exists($job)) then local:gen-job-sample($job) else () }
          </tbody>
          <tfooter>
          <tr><td style="border: 1px solid #cdd0d4"><p><a href="?service=pause">pause</a></p></td>
              <td style="border: 1px solid #cdd0d4"><p><a href="?service=resume">resume</a></p></td>
              <td style="border: 1px solid #cdd0d4"><p><a href="?service=delete">delete</a></p></td></tr></tfooter>
        </table>   
      </div>
    else
     <div><p><a href="?service=create">create</a></p></div>
};

(: =====================================================================================================================
    Description:
      Display the console html page using parameters get in url parameters
    Parameters:
     todo
   =====================================================================================================================
:)
declare function local:display-console() as element() {
  let $lt := "&#60;"
  return
    <div>
      <h2>Tasks Console - <a href="?reload">Reload</a></h2>
      <div>
         <h3>Scheduled JOB</h3>
         { local:display-job() }
      </div>
      <div>
         <h3>Tasks</h3>
      </div>
      <div>  
         <table>
          <caption>Current task</caption>
          { local:gen-table-header-currentTask() }
          <tbody>
          { if (exists(tasks:get-current-task()/Task)) then local:gen-task-sample(tasks:get-current-task()/Task) else () }
          </tbody>
          <tfooter>
          <tr><td style="border: 1px solid #cdd0d4"><p><a href="?action=emptied">emptied current task</a></p></td>
              <td style="border: 1px solid #cdd0d4"><p><a href="?action=launchnexttask">launch next task</a></p></td>
              <td style="border: 1px solid #cdd0d4"><p><a href="?action=removebootstrap">remove all bootstrap tasks</a></p></td></tr></tfooter>
         </table>         
        
      </div>
      <div>
        <table>
          <caption>List of pending tasks:</caption>
          { local:gen-table-header() }
          <tbody>
          { local:fetch-task() }
          </tbody>
         </table> 
      </div>
    </div>
};

(: 
  ===================================================================================================================== 
   *** ENTRY POINT ***
  =====================================================================================================================
:)   
let $m := request:get-method()
let $cmd := oppidum:get-command()
let $service := (request:get-parameter('service', ()), '-1')[1] (: scheduled job commands: create / pause / resume / del :)
let $job-property := globals:doc('settings-uri')/Settings/Module[Name eq "tasks"]/Property[Key/text() eq "job"]
let $xquery-resource := $job-property/Resource
let $cron-expression := $job-property/Expression
let $job-name := $job-property/Name
let $action := (request:get-parameter('action', ()), '-1')[1] 
let $reload := request:get-parameter('reload', ()) 
let $lang := string($cmd/@lang)
let $scheduled-parameters :=
    element { 'parameters' } {
    }
return
 <html>
    <head>
      <title>Tasks Console</title>
    </head>
    <body>
    {
    if ($service eq 'create') then
    <div>
      <table><tbody><tr><td style="border: 1px solid #cdd0d4"><p>LAST ACTION RESULT [Job creation]: {
      
        system:as-user(account:get-secret-user(), account:get-secret-password(), scheduler:schedule-xquery-cron-job($xquery-resource, $cron-expression, $job-name,$scheduled-parameters,boolean('false')))
        
       }</p></td></tr></tbody></table>
      { local:display-console() }
    </div>
    else if ($service eq 'pause') then
    <div>
      <table><tbody><tr>
        <td style="border: 1px solid #cdd0d4">
          <p>LAST ACTION RESULT [Job pause]: 
          { 
            
              system:as-user(account:get-secret-user(), account:get-secret-password(), scheduler:pause-scheduled-job($job-name)) 
            
          }
          </p></td></tr></tbody></table>
      { local:display-console() }
    </div>    
    else if ($service eq 'resume') then
    <div>
      <table><tbody><tr><td style="border: 1px solid #cdd0d4">
      <p>LAST ACTION RESULT [Job resume]: 
      {
       
          system:as-user(account:get-secret-user(), account:get-secret-password(), scheduler:resume-scheduled-job($job-name)) 
        
      }
      </p></td></tr></tbody></table>
      { local:display-console() }
    </div>    
    else if ($service eq 'delete') then
    <div>
      <table><tbody><tr><td style="border: 1px solid #cdd0d4">
        <p>LAST ACTION RESULT [Job deletion]: 
        {
          
            system:as-user(account:get-secret-user(), account:get-secret-password(), scheduler:delete-scheduled-job($job-name))
           
        }
        </p></td></tr></tbody></table>
      { local:display-console() }
    </div>       
    else if ($action eq 'emptied') then
    <div>
      <table><tbody><tr><td style="border: 1px solid #cdd0d4">
      <p>LAST ACTION RESULT [Emptied current task]: 
      {
        
          system:as-user(account:get-secret-user(), account:get-secret-password(), tasks:emptied-current-task()) 
        
      }
      </p></td></tr></tbody></table>
      { local:display-console() }
    </div>       
    else if ($action eq 'launchnexttask') then
    <div>
      <table><tbody><tr><td style="border: 1px solid #cdd0d4">
      <p>LAST ACTION RESULT [Launch next task]: 
      { 
        
          system:as-user(account:get-secret-user(), account:get-secret-password(), tasks:task-trigger())
                 
      }
      </p></td></tr></tbody></table>
      { local:display-console() }
    </div>
    else if ($action eq 'removebootstrap') then
    <div>
      <table><tbody><tr><td style="border: 1px solid #cdd0d4">
      <p>LAST ACTION RESULT [Remove all bootstrap]: 
      { 
       
          system:as-user(account:get-secret-user(), account:get-secret-password(), tasks:remove-all-bootstrap())
                 
      }
      </p></td></tr></tbody></table>
      { local:display-console() }
    </div>
    else if ($reload) then
      local:display-console()
    else
      local:display-console()
    }
    </body>
 </html>
 
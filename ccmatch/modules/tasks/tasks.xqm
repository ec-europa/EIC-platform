xquery version "3.0";
(: ------------------------------------------------------------------
   SMEi ccmatch

   Authors: Franck Leplé <franck.leple@amplexor.com>

   Tasks library
   - Used to manipulated tasks collection (db/tasks/ccmatch/<context>.xml 
      - <context> = community for instance
   - Access to tasks
   - Consume tasks
   - Add tasks

   July 2018 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

module namespace tasks = "http://oppidoc.com/ns/application/tasks";

import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace template = "http://oppidoc.com/ns/cctracker/template" at "../../lib/template.xqm";
import module namespace tasks-interpretor = "http://oppidoc.com/ns/application/tasks-interpretor" at "tasks-interpretor.xqm";

(: =====================================================================================================================
  Description:
   - Get Current Task and used for generate a Web Service Call
   - Use $globals:tasks-uri as a FIFO data structure
  
  Parameter:
    - none
  
  Return: Result of the call <CurrentTask><Task.../></CurrentTask> or <CurrentTask/>
  =====================================================================================================================
:)
declare function tasks:get-current-task() as element() {
  let $fifo := fn:doc($globals:tasks-uri)
  return
    $fifo/Tasks/CurrentTask
};

 
(:  =====================================================================================================================
  Description:
   - Set Current Task with the first Task in FIFO
   - Remove the first task
   - Use $globals:tasks-uri as a FIFO data structure
  
  Parameter:
    - none
  
  Return: Result of the call <CurrentTask><Task.../></CurrentTask> or <CurrentTask/> updated
   =====================================================================================================================
:)
declare function tasks:set-current-task() as element() {
  let $tasks := fn:doc($globals:tasks-uri)/Tasks
  let $first-task-in-standby := $tasks/Task[1]
  let $date := string(current-time())
  return
    try 
    {
      if (exists($first-task-in-standby)) then
        let $res := template:do-update-resource-no-uid("tasks-move-task-current", "", $tasks, <Task send-date="{$date}">{$first-task-in-standby/(@*, *)}</Task>, <Form/>)
        return
          if (local-name($res) eq 'success') then
            tasks:get-current-task()
          else
            <Error>{ "Error [ set-current-task ]: Can't set change the current task in the Task Manager " }</Error>
      else
        tasks:get-current-task()
    }
    catch * 
    {
      <Error>{ 'Error [' || $err:code || ']: ' || $err:description || ' - ' || $err:value }</Error>
    }
};

(:  =====================================================================================================================
  Description:
   - emptied Current Task 
   - Use $globals:tasks-uri as a FIFO data structure
  
  Parameter:
    - none
  
  Return: Result of the call <CurrentTask><Task.../></CurrentTask> or <CurrentTask/> updated
   =====================================================================================================================
:)
declare function tasks:emptied-current-task() as element() {
  let $tasks := fn:doc($globals:tasks-uri)/Tasks
  return
    try 
    {
        let $res := template:do-update-resource-no-uid("tasks-emptied-current-task", "", $tasks, (), <Form/>)
        return
          if (local-name($res) eq 'success') then
            tasks:get-current-task()
          else
            <Error>{ "Error [ set-current-task ]: Can't emptied the current task in the Task Manager " }</Error>
    }
    catch * 
    {
      <Error>{ 'Error [' || $err:code || ']: ' || $err:description || ' - ' || $err:value }</Error>
    }
};


(:  =====================================================================================================================
  Description:
   - Add Task to FIFO
   - Use $globals:tasks-uri as a FIFO data structure
  
  Parameter:
    - Context
    - 
    - Task type (bootstrap / update / block, etc.)
    - Coach Id
  
  Return: The Task Generater
   =====================================================================================================================
:)
declare function tasks:add-task($context as xs:string, $name as xs:string, $eid  as xs:string, $priority as xs:integer) as element() {
  let $tasks := fn:doc($globals:tasks-uri)/Tasks  
  let $date := string(current-time())
  let $task :=  <Task context="{ $context }" name="{ $name }" coach="{ $eid }" priority="{ $priority }" submission-date="{ $date }"/>
  return
    if (not(exists($tasks/Task[@coach eq $eid][@context eq "EICCommunity"][@name eq $name]))) then
     let $res := template:do-update-resource-no-uid("tasks-add-task", "", $tasks, $task, <Form/>)
     return
       if (local-name($res) eq 'success') then
         $task
       else
         <Error>{ "Error [ add-task ]: Can't add task in the Task Manager " }</Error>
    else
      <Warning>{ "Warning [ add-task ]: Task already exists in the Task Manager " }</Warning>
};

(:  =====================================================================================================================
  Description:
   - Function get time duration in second from current time
 
  Parameter:
    - initial date 
  
  Return: time duration in second from current time
   =====================================================================================================================
:)
declare function local:secondFromCurrentTime
  ( $sentdate as xs:time? )  as xs:decimal? {
  let $duration := current-time() - $sentdate
  return
  $duration div xs:dayTimeDuration('PT1S')
 } ;

declare function local:log-event($task-msg as element()) {
    let $debug := globals:doc('settings-uri')/Settings/Module[Name eq "tasks"]/Property[Key/text() eq "debug"]
    return
    if (exists($debug)) then 
      let $level := $debug/Value/text()
      let $log-collection := $debug/Collection/text()
      let $log := $debug/Filename/text()
      let $log-uri := concat($log-collection, "/", $log)
      return
          (
          (: create the log file if it does not exist :)
          if (not(doc-available($log-uri))) then
              xmldb:store($log-collection, $log, <Tasks/>)
          else ()
          ,
          (: log messages to the log file :)
          if ($level eq "INFO") then         
            update insert $task-msg into doc($log-uri)/Tasks
          else if (($level eq "WARNING") and (exists($task-msg//Warning) or exists($task-msg//Error))) then         
            update insert $task-msg into doc($log-uri)/Tasks
          else if (($level eq "ERROR") and (exists($task-msg//Error))) then         
            update insert $task-msg into doc($log-uri)/Tasks
          else ()
          )
    else ()
};

(:  =====================================================================================================================
  Description:
   - Function called by the scheduled JOB 
   - Use $globals:tasks-uri as a FIFO data structure
  
  Parameter:
    - none
  
  Return: Result of the call
   =====================================================================================================================
:)
declare function tasks:task-trigger() {
  try 
  {
    (: Control the FIFO lock
       If CurrentTask is empty there is no task in task-interpretor
       Else A task is already in traitment
    :)
    let $current-task := tasks:get-current-task()
    let $date := current-dateTime()
    return 
      if (exists($current-task/Task)) then
        let $sentDate := xs:time($current-task/Task/@send-date)
        let $service := fn:doc($globals:services-uri)//Consumers/Service[Id eq 'community']
        let $timeout := xs:integer($service/Timeout/text())
        return
        if(local:secondFromCurrentTime($sentDate) > $timeout) then
          tasks:emptied-current-task()
        else
        let $task-msg := <Info><Skip><Date>{ $date }</Date><TaskInProgress>{ $current-task/Task }</TaskInProgress></Skip></Info>
        return
          local:log-event($task-msg)
      else
        let $new-current-task := tasks:set-current-task()
        return
          let $res := tasks-interpretor:decode-task("en")
          return 
            local:log-event($res)
  }
  catch * 
  {
    let $task-msg := <Error>{ 'Error [' || $err:code || ']: ' || $err:description || ' - ' || $err:value }</Error>
    return
      local:log-event($task-msg)
  }
};
declare function tasks:remove-all-bootstrap() {
 let $tasks := fn:doc($globals:tasks-uri)/Tasks  
  return
    let $res := template:do-update-resource-no-uid("tasks-remove-all-bootstrap", "", $tasks, (), <Form/>)
    return
     if (local-name($res) eq 'success') then
       <sucess/>
     else
       <Error>{ "Error [ remove-all-bootstrap ]: Can't remove all bootstrap in the Task Manager " }</Error>
    
};


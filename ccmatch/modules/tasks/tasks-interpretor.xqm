xquery version "3.0";
(: ------------------------------------------------------------------
   SMEi ccmatch

   Authors: Franck Leplé <franck.leple@amplexor.com>

   Tasks interpretor library
   - Used to manipulated tasks collection (db/tasks/ccmatch/<context>.xml 
      - <context> = community for instance
   - Used to transform a task into an action (a web service call for instance)

   July 2018 - European Union Public Licence EUPL
   ------------------------------------------------------------------ :)

module namespace tasks-interpretor = "http://oppidoc.com/ns/application/tasks-interpretor";

import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../lib/globals.xqm";
import module namespace oppidum = "http://oppidoc.com/oppidum/util" at "../../../oppidum/lib/util.xqm";
import module namespace template = "http://oppidoc.com/ns/cctracker/template" at "../../lib/template.xqm";
import module namespace drupal = "http://oppidoc.com/ns/application/drupal" at "../community/drupal.xqm";
import module namespace community = "http://oppidoc.com/ns/application/community" at "../community/community.xqm";
import module namespace tasks = "http://oppidoc.com/ns/application/tasks" at "tasks.xqm";

(: =====================================================================================================================
    Description:
      launch the boostrap of one more coaches
    Parameters:
      $bootstrap: Coach id 
   =====================================================================================================================
:)
declare function local:boostrap-coaches($bootstrap as xs:string, $lang as xs:string) as element() {
  let $coach := fn:collection('/db/sites/ccmatch/persons')//Person[Id eq $bootstrap]
  return
    community:decode-service-response($coach, 'bootstrap', community:do-bootstrap-coach($coach, $lang), $lang)
};


(: =====================================================================================================================
    Description:
      launch the update of one more coaches
    Parameters:
      $update: Coach id 
   =====================================================================================================================
:)
declare function local:update-coaches($bootstrap as xs:string, $lang as xs:string) as element() {
  let $coach := fn:collection('/db/sites/ccmatch/persons')//Person[Id eq $bootstrap]
  return
    community:decode-service-response($coach, 'update', community:do-update-coach($coach, $lang), $lang)
};


(: =====================================================================================================================
    Description:
      launch the update for reseting the dummy organisation
    Parameters:
      
   =====================================================================================================================
:)
declare function local:reset-dummy-organisation($bootstrap as xs:string, $lang as xs:string) as element() {
  let $coach := fn:collection('/db/sites/ccmatch/persons')//Person[Id eq $bootstrap]
  return
    community:decode-service-response($coach, 'reset', community:do-reset-dummy-organisation($coach, $lang), $lang)
};

(: =====================================================================================================================
    Description:
      Decode the task and launch the traitment
    Parameters:
      $task: The task 
   =====================================================================================================================
:)
declare function tasks-interpretor:decode-task($task as element(), $lang as xs:string) as element() {
  let $context := $task/@context/string()
  let $name := $task/@name/string()
  let $coach := $task/@coach/string()
  let $priority := $task/@priority/string()
  let $submission-date := $task/@submission-date/string()
  return
    if ($context eq "EICCommunity") then
      if ($name eq "bootstrap") then
        <task-result><Info>{ local:boostrap-coaches($coach, $lang) }</Info></task-result>
      else if ($name eq "update") then
        <task-result><Info>{ local:update-coaches($coach, $lang) }</Info></task-result>
       else if ($name eq "reset") then
        <task-result><Info>{ local:reset-dummy-organisation($coach, $lang) }</Info></task-result>  
      else 
        <task-result><Error>Unknow task type { $name }</Error></task-result>
    else
      <task-result><Error>Unknow task context { $context }</Error></task-result>
};

(: =====================================================================================================================
    Description:
      Decode the task and launch the traitment
    Parameters:
      none
   =====================================================================================================================
:)
declare function tasks-interpretor:decode-task($lang as xs:string) as element() {
  let $CurrentTask := tasks:get-current-task()
  return 
    if (exists($CurrentTask/Task)) then
      let $res := tasks-interpretor:decode-task($CurrentTask/Task, $lang)
      return
        if (exists($res//service-response)) then
           (:Success put a succeed message in logs:)
          (tasks:emptied-current-task(), $res)[last()]
        else
          (:Error put an error message in logs:)
          $res
    else
      <task-result><Info>No pending task</Info></task-result>
};






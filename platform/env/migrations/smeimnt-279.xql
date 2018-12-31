xquery version "1.0";
(: --------------------------------------
   SMEIMKT Migration script

   Move "Closed" cases that received an SME feedback to "Evaluated" status

   Run it from you EXIST_HOME with:

   ./bin/client.sh -s -F webapp/projets/platform/migrations/smeimnt-279.xql -u admin -P password

   or from the platform/env/migrations folder with :

   ../../../../../bin/client.sh -s -F smeimnt-279.xql -u admin -P password
   -------------------------------------- :)

import module namespace globals = "http://oppidoc.com/oppidum/globals" at "../../../webapp/projets/cctracker/lib/globals.xqm";

declare variable $local:migration := 'smeimnt-279'; (: use this to tag migration if u want :)
declare variable $local:mode := 'run'; (: set to 'dry' for experimenting first on dev :)
declare variable $local:limit := (); (: use () or an integer to limit the number of cases migrated for testing :)

<Batch Mode="{ $local:mode }">
{
for $activity at $i in fn:collection($globals:cases-uri)//Activity[StatusHistory/CurrentStatusRef eq '10'][Evaluation/Order[Answers][Questionnaire eq 'cctracker-sme-feedback']]
let $case := $activity/ancestor::Case
where empty($local:limit) or $i <= $local:limit
return
  <Migration CaseNo="{$case/No}" ActivityNo="{$activity/No}">
    { 
    attribute { 'LasModification'} 
      {
      substring($activity/Evaluation/Order[Answers][Questionnaire eq 'cctracker-sme-feedback']/Answers/@LastModification, 1, 10) 
      },
    if ($activity/StatusHistory[@_Migration eq 'smeimnt-279']) then (: useless - not reachable :)
      'already done'
    else if ($local:mode eq 'run') then
      let $history := $activity/StatusHistory
      let $status := $history/Status[ValueRef eq '10']
      return (
        update value $history/CurrentStatusRef with '11',
        update value $status/ValueRef with '11',
        update insert attribute { '_Migration' } { 'smeimnt-279' } into $history,
        'done'
        )
    else
      'dry'
    }
  </Migration>
}
</Batch>

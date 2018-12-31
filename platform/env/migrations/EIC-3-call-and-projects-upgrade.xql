xquery version "1.0";
(: ======================================================================
   All in one migration script for UI-upgrade-581

   This solution replcaes EIC-1 and EIC-2 migration scripts,
   it avoids XQuery update from EIC-1 which is quite costly

   Pre-requisite: <Selector Name="SMEiCalls" Value="Code" Label="Name">
   with cached dates as in <Name Date="2014-06-18">18/06/2014</Name>

   Note: it seems to be more efficient 
   - to discard the /Project[Id eq $c/@ProjectId] pre-migration test
   - to run this script in several btach executions using only a subset 
     of the calls each time such as in 
     for $c in $cases//Case[Information/Call/Date = ("2014-06-18")]
   ====================================================================== 
:)
declare variable $local:selector := collection('/db/sites/cctracker/global-information')//Selector[@Name eq 'SMEiCalls'];

declare function local:migrate-call( $call as element() ) as element() {
  let $type :=  if ($call/PhaseRef/text() eq '1') then '1-1' else '1-2'
  return
    <Call>
       <FundingProgramRef>1</FundingProgramRef>
       <SMEiFundingRef>{ $type }</SMEiFundingRef>
       <SMEiCallRef>
       { 
       $local:selector/Group[Type eq $type]//Option[starts-with(Name/@Date, $call/Date)]/Code/text()
       }
       </SMEiCallRef>
       { $call/(CallTopics | EICPanels) }
    </Call>
};

(: ======================================================================
   pass $date as YYYY-MM-DD
   ====================================================================== 
:)
declare function local:create-project-collection( $date as xs:string, $id as xs:string ) as xs:string* {
  (: FIXME: use a @LastIndex scheme :)
    let $year := substring($date, 1, 4)
    let $month := substring($date, 6, 2)
    let $bootstrap := xmldb:create-collection('/db/sites/cctracker', 'projects')
    let $home-year-col-uri := concat('/db/sites/cctracker/projects', '/', $year)
    let $ts-year-col-uri := concat('/db/sites/cctracker/timesheets', '/', $year)
    let $home-col-uri := concat($home-year-col-uri , '/', $month)
    let $ts-col-uri := concat($ts-year-col-uri , '/', $month)
    return (
      (: Lazy creation of home collection with YEAR :)
      if (not(xmldb:collection-available($home-year-col-uri))) then
        if (xmldb:create-collection('/db/sites/cctracker/projects', $year)) then
          xmldb:set-collection-permissions($home-year-col-uri, 'admin', 'users', util:base-to-integer(0774, 8))
        else
         ()
      else
        (),
      (: Lazy creation of home collection with YEAR :)
      if (not(xmldb:collection-available($ts-year-col-uri))) then
        if (xmldb:create-collection('/db/sites/cctracker/timesheets', $year)) then
          xmldb:set-collection-permissions($ts-year-col-uri, 'admin', 'users', util:base-to-integer(0774, 8))
        else
         ()
      else
        (),
      (: Lazy creation of home collection with MONTH :)
      if (not(xmldb:collection-available($home-col-uri))) then
        if (xmldb:create-collection($home-year-col-uri, $month)) then
          xmldb:set-collection-permissions($home-col-uri, 'admin', 'users', util:base-to-integer(0774, 8))
        else
         ()
      else
        (),
      (: Lazy creation of home collection with MONTH :)
      if (not(xmldb:collection-available($ts-col-uri))) then
        if (xmldb:create-collection($ts-year-col-uri, $month)) then
          xmldb:set-collection-permissions($ts-col-uri, 'admin', 'users', util:base-to-integer(0774, 8))
        else
         ()
      else
        (),
      (: Case collection creation :)
      let $ts-uri := concat($ts-col-uri, '/', $id)
      return
        if (not(xmldb:collection-available($ts-uri))) then
          if (xmldb:create-collection($ts-col-uri, string($id))) then
            let $perms := xmldb:set-collection-permissions($ts-uri, 'admin', 'users', util:base-to-integer(0774, 8))
            return
              ()
          else
            ()
        else
          (),
      let $col-uri := concat($home-col-uri, '/', $id)
      return
        if (not(xmldb:collection-available($col-uri))) then
          if (xmldb:create-collection($home-col-uri, string($id))) then
            let $perms := xmldb:set-collection-permissions($col-uri, 'admin', 'users', util:base-to-integer(0774, 8))
            return
              ($col-uri, string($id))
          else
            ()
        else
          ($col-uri, string($id))
      )
};

(:TODO : string-join(for $i in distinct-values(fn:collection('/db/sites/cctracker/cases')//Case/Information/Call/Date) order by $i return concat('"', $i, '"'), ', '):)
(: TODO = :)
(: DONE = 2014-06-18, 2014-09-24, 2014-10-09, 2014-12-17, 2015-02-03, 2015-03-18, "2015-06-17", "2015-09-17", "2015-11-25", "2016-02-03", "2016-02-24", "2016-04-14", "2015-06-17", "2015-09-17", "2015-11-25", "2016-02-03", "2016-02-24", "2016-04-14", "2016-05-03", "2016-06-15", "2016-09-07", "2016-10-13", "2016-11-08", "2016-11-09", "2017-01-18", "2017-02-15", "2017-04-06", "2017-05-03", "2017-06-01", "2017-09-06", "2017-10-18", "2017-11-09", "2018-01-10", "2018-02-08" :)
<Res>
{
let $cases := collection('/db/sites/cctracker/cases')
return
  for $c in $cases//Case (:[Information/Call/Date = ("2014-06-18")]:)
  let $ts := $c//Activity//TimesheetFile
  let $new :=
    <Project>
      <Id>{ string($c/@ProjectId) }</Id>
      { $c/CreationDate }
      <FormerCaseNo>{ $c/No/text() }</FormerCaseNo>
      <StatusHistory>
        <CurrentStatusRef>1</CurrentStatusRef>
        <Status>
          <Date>{ $c/CreationDate }</Date>
          <ValueRef>1</ValueRef>
        </Status>
      </StatusHistory>
      <Information>
        { 
        (:$c/Information/*[not(local-name(.) = ('ClientEnterprise','ContactPerson', 'ManagingEntity'))]:)
        $c/Information/Title,
        $c/Information/Acronym,
        $c/Information/Summary,
        local:migrate-call($c/Information/Call),
        $c/Information/*[not(local-name(.) = ('Title', 'Acronym', 'Summary', 'Call', 'ClientEnterprise','ContactPerson', 'ManagingEntity'))]
        }
        <Beneficiaries>
          <Coordinator>
            <PIC>{ string($c/Information/ClientEnterprise/@EnterpriseId) }</PIC>
            { $c/Information/ClientEnterprise/* }
            { $c/Information/ContactPerson }
          </Coordinator>
        </Beneficiaries>
      </Information>
      <Cases LastIndex="1">
        <Case>
          <No>1</No>
          <PIC>{ string($c/Information/ClientEnterprise/@EnterpriseId) }</PIC>
          { $c/Information/ManagingEntity }
          { $c/*[not(local-name(.) = ('No', 'Information', 'CreationDate'))] }
        </Case>
      </Cases>
    </Project>
  let $datecall := $c/Information/Call/Date (: YYYY-MM-DD :)
  let $year := substring($datecall, 1, 4)
  let $month := substring($datecall, 6, 2)
  let $path := concat('/db/sites/cctracker/projects/', $year, '/', $month, '/', $c/@ProjectId)
  return
    (:if (not(collection('/db/sites/cctracker/projects')//Project[Id eq $c/@ProjectId])) then:)
    if (fn:doc-available(concat($path, '/project.xml'))) then (: quick existence test :)
      <Skip CaseNo="{$c/No}" Project="{$c/@ProjectId}">
        {
        for $t in $ts
        let $ts-path := replace($path,'projects','timesheets')
        return
          if (util:binary-doc-available(concat($ts-path, '/', $t))) then
            <Skip>{ $t/(@*|text()) }</Skip>
          else
            <Missing>{ $t/(@*|text()) }</Missing>
          }
      </Skip>
    else
      let $res := local:create-project-collection($datecall, $new/Id )
      return
        <Done CaseNo="{$c/No}" Project="{$c/@ProjectId}" CallDate="{$c/Information/Call/Date}">
        {
        for $t in $ts
        let $ts-path := replace($path,'projects','timesheets')
        let $src-uri := replace(util:collection-name($c),'cases','timesheets')
        let $target-uri := replace($res[1],'projects','timesheets')
        return 
          if (util:binary-doc-available(concat($src-uri, '/', $t))) then (
            xmldb:move($src-uri, $target-uri, $t),
            <Timesheet>{$res[1], $new/Id}</Timesheet>
            )
          else
            <Missing>{ $t/(@*|text()) }</Missing>,
        let $store := xmldb:store($res[1], "project.xml", $new)
        return
          xmldb:set-resource-permissions($res[1], "project.xml", 'admin', 'users', util:base-to-integer(0774, 8))
        }
        </Done>
    (:else
        <AlreadyDone CaseNo="{$c/No}" Project="{$c/@ProjectId}" SMEiCallRef="{collection('/db/sites/cctracker/projects')//Project[Id eq $c/@ProjectId]/Information/Call/SMEiCallRef}"/>:)
}
</Res>


